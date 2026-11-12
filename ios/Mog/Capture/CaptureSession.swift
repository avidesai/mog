import Foundation
import ARKit
import Combine
import simd

/// One frame's worth of what the gates and the geometry layer need. Everything here lives in
/// memory for the duration of a capture and is dropped the moment measurements are computed.
struct FaceFrame {
    let timestamp: TimeInterval
    /// Face mesh vertices in the FACE anchor's own coordinate space (metres). Pose-invariant by
    /// construction — this is why the ARKit mesh is the primary geometry source (see Geometry/).
    let vertices: [SIMD3<Float>]
    /// Face pose relative to the camera: yaw/pitch/roll in degrees, distance in metres.
    let pose: Pose
    let blendShapes: [ARFaceAnchor.BlendShapeLocation: Float]
    let luma: LumaStats
    /// Skin evenness statistics, computed only on frames that are being collected (it is the costliest per-frame step).
    let skin: SkinEvenness.Stats?

    struct Pose { let yaw: Double; let pitch: Double; let roll: Double; let distance: Double }
}

/// Drives ARKit face tracking and publishes gate status + frames. UI-agnostic.
final class CaptureSession: NSObject, ObservableObject, ARSessionDelegate {
    enum Phase: Equatable { case idle, aligning, capturing(Int), done, aborted(String) }

    @Published private(set) var gates: GateReport = .allFailing
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var hint: String = ""

    let session = ARSession()
    private let gateEvaluator = GateEvaluator()
    private var collected: [FaceFrame] = []
    private var stablePassStreak = 0
    private var onComplete: (([FaceFrame]) -> Void)?
    var framesRequired = 10
    /// Gates must pass for this many consecutive frames before capture begins (≈0.5 s at 30 fps).
    var stableFramesRequired = 15
    var dumpFrames: ((FaceFrame) -> Void)?   // spike-1 landmark dump hook, nil in production

    static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    func start(onComplete: @escaping ([FaceFrame]) -> Void) {
        guard Self.isSupported else { phase = .aborted("TrueDepth camera required"); return }
        self.onComplete = onComplete
        collected = []; stablePassStreak = 0
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.maximumNumberOfTrackedFaces = 1
        session.delegate = self
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        phase = .aligning
    }

    func stop() {
        session.pause()
        collected = []
        phase = .idle
    }

    // MARK: ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked else {
            gates = .allFailing; hint = Copy.s("capture.hint_yaw"); stablePassStreak = 0
            return
        }
        let pose = Self.pose(of: face, camera: frame.camera)
        let luma = LumaStats.compute(from: frame.capturedImage, face: face, camera: frame.camera)
        var collecting = false
        if case .capturing = phase { collecting = true }
        let skin = collecting ? SkinEvenness.compute(pixelBuffer: frame.capturedImage, face: face, camera: frame.camera) : nil
        let ff = FaceFrame(timestamp: frame.timestamp, vertices: face.geometry.vertices, pose: pose,
                           blendShapes: face.blendShapes.reduce(into: [:]) { $0[$1.key] = $1.value.floatValue }, luma: luma, skin: skin)
        let report = gateEvaluator.evaluate(ff)
        gates = report
        hint = report.hint

        switch phase {
        case .aligning:
            if report.allPass { stablePassStreak += 1 } else { stablePassStreak = 0 }
            if stablePassStreak >= stableFramesRequired { phase = .capturing(0); hint = Copy.s("capture.hint_ready") }
        case .capturing:
            guard report.allPass else {
                // a gate drifted mid-capture: abort, discard everything, say which gate
                collected = []; stablePassStreak = 0
                phase = .aborted(report.firstFailing ?? "")
                return
            }
            collected.append(ff)
            dumpFrames?(ff)
            phase = .capturing(collected.count)
            if collected.count >= framesRequired {
                session.pause()
                phase = .done
                let frames = collected
                collected = []            // drop our reference immediately
                onComplete?(frames)
                onComplete = nil
            }
        default: break
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) { phase = .aborted(error.localizedDescription) }

    /// Yaw/pitch/roll of the face relative to the camera, in degrees, and the distance in metres.
    static func pose(of face: ARFaceAnchor, camera: ARCamera) -> FaceFrame.Pose {
        let faceInCamera = camera.transform.inverse * face.transform
        let r = simd_float3x3(SIMD3(faceInCamera.columns.0.x, faceInCamera.columns.0.y, faceInCamera.columns.0.z),
                              SIMD3(faceInCamera.columns.1.x, faceInCamera.columns.1.y, faceInCamera.columns.1.z),
                              SIMD3(faceInCamera.columns.2.x, faceInCamera.columns.2.y, faceInCamera.columns.2.z))
        // ZYX Euler decomposition; ARKit face +Z points out of the face toward the camera.
        let pitch = asin(max(-1, min(1, -r[2][1])))
        let yaw = atan2(r[2][0], r[2][2])
        let roll = atan2(r[0][1], r[1][1])
        let t = faceInCamera.columns.3
        let dist = sqrt(Double(t.x * t.x + t.y * t.y + t.z * t.z))
        return .init(yaw: Double(yaw) * 180 / .pi, pitch: Double(pitch) * 180 / .pi, roll: Double(roll) * 180 / .pi, distance: dist)
    }
}
