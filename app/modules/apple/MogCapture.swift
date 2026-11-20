// `<mog-capture>`: guided front capture on ARKit face tracking. Port of ios/Mog/Capture.
//
// Privacy invariant (AGENTS.md, biometric data policy §3): frames, depth, the face mesh and every
// landmark live in memory for the length of one capture and are dropped the moment the readings
// are computed. Nothing here writes a file or touches the network. The only thing that crosses to
// the Contract is `readings <json>`: named measurements (value, confidence, iqr per metric id).
//
//   props   beard     "1" or "0" when the person answered; unset means no beard reading
//           hairline  the Norwood stage the person picked, "1"…"7"; unset means no hairline reading
//   events  message   "gates <angle><lighting><distance><expression><clear><sharp> <hint key>", each 0/1,
//                     whenever a check or the hint changes; "aborted <gate index>" when a check drifts
//                     mid-burst (nothing kept); "readings <json>" once; "unsupported" without TrueDepth;
//                     "denied" when camera access is refused.
import Foundation
#if os(iOS) && canImport(ARKit)
import ARKit
import AVFoundation
import SceneKit
import UIKit

final class MogCaptureModule: ExactModule {
    override class var views: [String: ExactNativeFactory] {
        ["mog-capture": ExactNativeFactory(for: MogCaptureModule.self) { _, props, events in MogCapture(props, events) }]
    }
}
let exactModule: ExactModule.Type = MogCaptureModule.self

/// One frame's worth of what the gates and the geometry need. In memory only, for one capture.
struct FaceFrame {
    /// Face mesh vertices in the face anchor's own coordinate space (metres): pose-invariant.
    let vertices: [SIMD3<Float>]
    let pose: Pose
    let blendShapes: [ARFaceAnchor.BlendShapeLocation: Float]
    let luma: LumaStats
    /// Computed only on frames being collected: the costliest per-frame step.
    let skin: SkinEvenness.Stats?

    struct Pose { let yaw: Double; let pitch: Double; let roll: Double; let distance: Double }
}

/// ARKit's delegate must be an NSObject and ExactNativeInstance is not, so frames come through this.
/// ARSession holds its delegate weakly; MogCapture holds the sink.
private final class FrameSink: NSObject, ARSessionDelegate {
    weak var owner: MogCapture?
    func session(_ session: ARSession, didUpdate frame: ARFrame) { owner?.update(session, frame) }
    func session(_ session: ARSession, didFailWithError error: Error) { owner?.failed(error) }
}

final class MogCapture: ExactNativeInstance {
    private let scene = ARSCNView(frame: .zero)
    private let sink = FrameSink()
    private let gates = GateEvaluator()
    private var collected: [FaceFrame] = []
    private var stableStreak = 0
    private var capturing = false
    private var finished = false
    private var lastSent = ""
    private var beard: Int?, hairline: Int?
    private let framesRequired = 10
    /// Checks must pass this many frames in a row before the burst. Face tracking may run at 60 fps,
    /// which halves the hold; spike 1 records the rate and tunes both counts.
    private let stableFramesRequired = 15

    init(_ props: [String: String], _ events: ExactNativeEvents) {
        super.init(events: events)
        try? setProps(props)
        scene.automaticallyUpdatesLighting = false
        events.intrinsicSize(CGSize(width: 320, height: 420))
        guard ARFaceTrackingConfiguration.isSupported else { events.message("unsupported"); return }
        let access = AVCaptureDevice.authorizationStatus(for: .video)
        guard access != .denied && access != .restricted else { events.message("denied"); return }
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.maximumNumberOfTrackedFaces = 1
        sink.owner = self
        scene.session.delegate = sink
        scene.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    override var view: ExactNativeView { scene }

    override func setProps(_ props: [String: String]) throws {
        beard = props["beard"].flatMap { Int($0) }
        hairline = props["hairline"].flatMap { Int($0) }
    }

    // A frame already queued on main may arrive after this: `finished` and the cleared owner drop it.
    override func destroy() {
        finished = true
        sink.owner = nil
        scene.session.delegate = nil
        scene.session.pause()
        collected = []
    }

    private func send(_ message: String) {
        guard message != lastSent else { return }
        lastSent = message
        events.message(message)
    }

    fileprivate func update(_ session: ARSession, _ frame: ARFrame) {
        guard !finished else { return }
        guard let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked else {
            stableStreak = 0
            // A face lost mid-burst is most often something in front of it: name the clear-view check.
            if capturing { abort(4) } else { send("gates 000000 capture.hint_yaw") }
            return
        }
        let luma = LumaStats.compute(from: frame.capturedImage, face: face, camera: frame.camera)
        let skin = capturing ? SkinEvenness.compute(pixelBuffer: frame.capturedImage, face: face, camera: frame.camera) : nil
        let f = FaceFrame(vertices: face.geometry.vertices, pose: Self.pose(of: face, camera: frame.camera),
                          blendShapes: face.blendShapes.reduce(into: [:]) { $0[$1.key] = $1.value.floatValue }, luma: luma, skin: skin)
        let report = gates.evaluate(f)
        send("gates \(report.mask) \(report.hintKey)")

        if !capturing {
            stableStreak = report.allPass ? stableStreak + 1 : 0
            if stableStreak >= stableFramesRequired { capturing = true }
            return
        }
        guard report.allPass else { abort(report.firstFailing ?? 0); return }
        collected.append(f)
        guard collected.count >= framesRequired else { return }
        finished = true
        session.pause()
        let frames = collected
        collected = []
        let readings = GeometryPipeline.readings(from: frames, beardPresence: beard, hairlineStage: hairline)
        events.message("readings \(GeometryPipeline.json(readings))")
    }

    /// A check drifted mid-burst: everything collected is discarded, and alignment starts again.
    private func abort(_ gate: Int) {
        collected = []
        capturing = false
        stableStreak = 0
        lastSent = ""
        events.message("aborted \(gate)")
    }

    fileprivate func failed(_ error: Error) {
        events.message((error as? ARError)?.code == .cameraUnauthorized ? "denied" : "unsupported")
    }

    /// Yaw and pitch: where the camera sits as seen from the face, which does not depend on how the
    /// phone is held. Roll: the face's up against the phone's portrait up, in the image plane.
    /// ARCamera.transform is fixed to the sensor's landscape axes; on a portrait phone its -x is "up".
    /// Signs are confirmed on a device in spike 1 (HANDOFF §3.2).
    static func pose(of face: ARFaceAnchor, camera: ARCamera) -> FaceFrame.Pose {
        let inFace = face.transform.inverse * camera.transform
        let d = SIMD3<Float>(inFace.columns.3.x, inFace.columns.3.y, inFace.columns.3.z)
        let yaw = atan2(d.x, d.z)
        let pitch = atan2(d.y, hypot(d.x, d.z))
        let c = camera.transform
        let forward = simd_normalize(SIMD3<Float>(c.columns.2.x, c.columns.2.y, c.columns.2.z))
        func onImage(_ v: SIMD3<Float>) -> SIMD3<Float> { simd_normalize(v - simd_dot(v, forward) * forward) }
        let phoneUp = onImage(-SIMD3<Float>(c.columns.0.x, c.columns.0.y, c.columns.0.z))
        let faceUp = onImage(SIMD3<Float>(face.transform.columns.1.x, face.transform.columns.1.y, face.transform.columns.1.z))
        let roll = atan2(simd_dot(simd_cross(phoneUp, faceUp), forward), simd_dot(phoneUp, faceUp))
        let deg = 180 / Double.pi
        return .init(yaw: Double(yaw) * deg, pitch: Double(pitch) * deg, roll: Double(roll) * deg, distance: Double(simd_length(d)))
    }
}

/// Capture gates (eng doc, "Capture and quality gates"). Thresholds are spike-1 tunables.
struct GateEvaluator {
    var yawDeg = 3.0, pitchDeg = 3.0, rollDeg = 2.0
    var distanceMin = 0.45, distanceMax = 0.75
    var lumaMin = 0.30, lumaMax = 0.85, lumaAsymmetryMax = 0.12, clippingMax = 0.02
    var sharpnessMin = 0.0015
    var expressionMax: Float = 0.25, eyeOpenMin: Float = 0.6

    struct Report {
        var angle = false, lighting = false, distance = false, expression = false, clear = false, sharp = false
        var hintKey = "capture.hint_yaw"
        var allPass: Bool { angle && lighting && distance && expression && clear && sharp }
        var mask: String { [angle, lighting, distance, expression, clear, sharp].map { $0 ? "1" : "0" }.joined() }
        /// The check an abort names: Contract indexes, ranked as the reference ranks them (distance before lighting).
        var firstFailing: Int? {
            let checks = [angle, lighting, distance, expression, clear, sharp]
            return [0, 2, 1, 3, 4, 5].first { !checks[$0] }
        }
    }

    private static let expressionShapes: [ARFaceAnchor.BlendShapeLocation] = [
        .jawOpen, .mouthSmileLeft, .mouthSmileRight, .mouthPucker, .mouthFunnel, .browInnerUp, .browDownLeft, .browDownRight,
        .cheekPuff, .mouthFrownLeft, .mouthFrownRight, .eyeSquintLeft, .eyeSquintRight, .jawLeft, .jawRight,
    ]

    func evaluate(_ f: FaceFrame) -> Report {
        var r = Report()
        var hint: String?
        // The biggest offender names the hint.
        let yawOK = abs(f.pose.yaw) <= yawDeg, pitchOK = abs(f.pose.pitch) <= pitchDeg, rollOK = abs(f.pose.roll) <= rollDeg
        r.angle = yawOK && pitchOK && rollOK
        if !yawOK { hint = hint ?? "capture.hint_yaw" }
        if !pitchOK { hint = hint ?? (f.pose.pitch > 0 ? "capture.hint_pitch_down" : "capture.hint_pitch_up") }
        if !rollOK { hint = hint ?? "capture.hint_roll" }

        r.distance = f.pose.distance >= distanceMin && f.pose.distance <= distanceMax
        if !r.distance { hint = hint ?? (f.pose.distance < distanceMin ? "capture.hint_further" : "capture.hint_closer") }

        let L = f.luma
        let levelOK = L.mean >= lumaMin && L.mean <= lumaMax
        let asymOK = abs(L.leftMean - L.rightMean) <= lumaAsymmetryMax
        let clipOK = L.clippedFraction <= clippingMax
        r.lighting = levelOK && asymOK && clipOK
        if !clipOK { hint = hint ?? "capture.hint_clipping" }
        else if !levelOK { hint = hint ?? "capture.hint_lighting_dark" }
        else if !asymOK { hint = hint ?? "capture.hint_lighting_uneven" }

        let maxExpr = Self.expressionShapes.map { f.blendShapes[$0] ?? 0 }.max() ?? 0
        let eyesOpen = (1 - (f.blendShapes[.eyeBlinkLeft] ?? 0)) >= eyeOpenMin && (1 - (f.blendShapes[.eyeBlinkRight] ?? 0)) >= eyeOpenMin
        r.expression = maxExpr <= expressionMax && eyesOpen
        if !r.expression { hint = hint ?? "capture.hint_expression" }

        // ARKit reports no occlusion; tracking (checked upstream) stands in until spike 1 decides on a Vision check.
        r.clear = true

        r.sharp = L.sharpness >= sharpnessMin
        if !r.sharp { hint = hint ?? "capture.hint_sharp" }

        r.hintKey = hint ?? "capture.hint_ready"
        return r
    }
}

/// Lighting and sharpness over the face region. Reads the luma plane on a coarse stride; keeps no pixels.
struct LumaStats {
    var mean = 0.0, leftMean = 0.0, rightMean = 0.0, clippedFraction = 0.0
    /// Variance of a 4-neighbour Laplacian, normalised.
    var sharpness = 0.0

    static func compute(from buffer: CVPixelBuffer, face: ARFaceAnchor, camera: ARCamera) -> LumaStats {
        guard CVPixelBufferGetPlaneCount(buffer) >= 1 else { return LumaStats() }
        let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
        // capturedImage is in the sensor's landscape-right orientation, so projecting with .landscapeRight and the
        // buffer's own size gives pixel coordinates directly. Verifying this on a device is a spike-1 check.
        let size = CGSize(width: w, height: h)
        func project(_ p: SIMD3<Float>) -> CGPoint {
            let world = face.transform * SIMD4<Float>(p, 1)
            return camera.projectPoint(SIMD3(world.x, world.y, world.z), orientation: .landscapeRight, viewportSize: size)
        }
        let verts = face.geometry.vertices
        guard !verts.isEmpty else { return LumaStats() }
        var minX = CGFloat.greatestFiniteMagnitude, minY = minX, maxX = -minX, maxY = -minX
        for i in stride(from: 0, to: verts.count, by: 40) {
            let q = project(verts[i])
            minX = min(minX, q.x); maxX = max(maxX, q.x); minY = min(minY, q.y); maxY = max(maxY, q.y)
        }
        let x0 = max(0, Int(minX)), x1 = min(w - 1, Int(maxX)), y0 = max(0, Int(minY)), y1 = min(h - 1, Int(maxY))
        guard x1 > x0 + 8, y1 > y0 + 8 else { return LumaStats() }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return LumaStats() }
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let px = base.assumingMemoryBound(to: UInt8.self)
        func at(_ x: Int, _ y: Int) -> Double { Double(px[y * rowBytes + x]) / 255 }

        let step = max(1, (x1 - x0) / 64)
        var sum = 0.0, sumL = 0.0, sumR = 0.0, n = 0.0, nL = 0.0, nR = 0.0, clipped = 0.0
        var lapSum = 0.0, lapSq = 0.0
        // Held upright, the buffer's x runs along the face's vertical axis, so left and right split on y.
        let midY = (y0 + y1) / 2
        var y = y0 + step
        while y < y1 - step {
            var x = x0 + step
            while x < x1 - step {
                let v = at(x, y)
                sum += v; n += 1
                if v >= 0.98 { clipped += 1 }
                if y < midY { sumL += v; nL += 1 } else { sumR += v; nR += 1 }
                let lap = 4 * v - at(x - step, y) - at(x + step, y) - at(x, y - step) - at(x, y + step)
                lapSum += lap; lapSq += lap * lap
                x += step
            }
            y += step
        }
        guard n > 0 else { return LumaStats() }
        let lapMean = lapSum / n
        return LumaStats(mean: sum / n, leftMean: nL > 0 ? sumL / nL : 0, rightMean: nR > 0 ? sumR / nR : 0,
                         clippedFraction: clipped / n, sharpness: lapSq / n - lapMean * lapMean)
    }
}

#else
// No ARKit (macOS, the simulator's other platforms): the tag says so and the app explains.
#if os(macOS)
import AppKit
#else
import UIKit
#endif

final class MogCaptureModule: ExactModule {
    override class var views: [String: ExactNativeFactory] {
        ["mog-capture": ExactNativeFactory(for: MogCaptureModule.self) { _, _, events in Unsupported(events) }]
    }
}
let exactModule: ExactModule.Type = MogCaptureModule.self

final class Unsupported: ExactNativeInstance {
    #if os(macOS)
    private let box = NSView(frame: .zero)
    #else
    private let box = UIView(frame: .zero)
    #endif
    init(_ events: ExactNativeEvents) {
        super.init(events: events)
        events.message("unsupported")
    }
    override var view: ExactNativeView { box }
}
#endif
