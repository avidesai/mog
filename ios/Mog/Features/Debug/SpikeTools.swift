#if DEBUG
import SwiftUI
import ARKit
import SceneKit
import MogCore

// Spike-1 tooling. Debug builds only. Both views exist to answer week 1's go/no-go question:
// "can ARKit's mesh give us ≥6 metrics at tier A/B reliability on real faces?"

// MARK: - Vertex picker: tap your own mesh, read the vertex index, fill landmark_map.json

struct VertexPickerView: View {
    @State private var picked: [(String, Int)] = []
    @State private var lastIndex: Int?
    @State private var label = ""

    var body: some View {
        VStack(spacing: Tokens.Space.s3) {
            MeshPickerARView(onPick: { lastIndex = $0 })
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl))
                .aspectRatio(3 / 4, contentMode: .fit)
            HStack {
                Text(lastIndex.map { "vertex \($0)" } ?? "tap a point on the mesh").style(TypeStyle.value)
                Spacer()
                TextField("landmark key", text: $label).textInputAutocapitalization(.never).autocorrectionDisabled().frame(width: 160)
                Button("Save") { if let i = lastIndex, !label.isEmpty { picked.append((label, i)); label = "" } }.disabled(lastIndex == nil)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(picked.enumerated()), id: \.offset) { _, p in Text("\"\(p.0)\": \(p.1),").font(.system(.footnote, design: .monospaced)) }
                }
            }
            Button("Copy as JSON") { UIPasteboard.general.string = picked.map { "\"\($0.0)\": \($0.1)" }.joined(separator: ",\n") }.buttonStyle(.chunky(.secondary))
            Text("Paste into ios/Mog/Geometry/landmark_map.json. Indices are stable across devices.").style(TypeStyle.caption, color: Tokens.Colors.ink500)
        }
        .padding(Tokens.Space.s5).background(Tokens.Colors.paper)
        .navigationTitle("Vertex picker")
    }
}

/// Renders the tracked face mesh as a point cloud and resolves taps to the nearest projected vertex.
struct MeshPickerARView: UIViewRepresentable {
    let onPick: (Int) -> Void
    func makeUIView(context: Context) -> ARSCNView {
        let v = ARSCNView(frame: .zero)
        v.delegate = context.coordinator
        v.session.delegate = context.coordinator
        v.automaticallyUpdatesLighting = true
        let cfg = ARFaceTrackingConfiguration(); cfg.maximumNumberOfTrackedFaces = 1
        v.session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        v.addGestureRecognizer(tap)
        context.coordinator.view = v
        return v
    }
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        let onPick: (Int) -> Void
        weak var view: ARSCNView?
        var latest: ARFaceAnchor?
        var highlight: SCNNode?
        init(onPick: @escaping (Int) -> Void) { self.onPick = onPick }

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let fa = anchor as? ARFaceAnchor, let dev = (renderer as? ARSCNView)?.device else { return nil }
            let geom = ARSCNFaceGeometry(device: dev, fillMesh: false)!
            geom.update(from: fa.geometry)
            geom.firstMaterial?.fillMode = .lines
            geom.firstMaterial?.diffuse.contents = UIColor(red: 0.18, green: 0.36, blue: 1, alpha: 0.8)
            geom.firstMaterial?.lightingModel = .constant
            return SCNNode(geometry: geom)
        }
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let fa = anchor as? ARFaceAnchor, let g = node.geometry as? ARSCNFaceGeometry else { return }
            g.update(from: fa.geometry); latest = fa
        }
        @objc func tap(_ g: UITapGestureRecognizer) {
            guard let view, let fa = latest else { return }
            let p = g.location(in: view)
            var best = -1; var bestD = CGFloat.greatestFiniteMagnitude
            for (i, v) in fa.geometry.vertices.enumerated() {
                let w = fa.transform * SIMD4<Float>(v, 1)
                let s = view.projectPoint(SCNVector3(w.x, w.y, w.z))
                let d = hypot(CGFloat(s.x) - p.x, CGFloat(s.y) - p.y)
                if d < bestD { bestD = d; best = i }
            }
            guard best >= 0 else { return }
            onPick(best)
            highlight?.removeFromParentNode()
            let dot = SCNNode(geometry: SCNSphere(radius: 0.0015))
            dot.geometry?.firstMaterial?.diffuse.contents = UIColor.systemOrange
            let v = fa.geometry.vertices[best]
            dot.simdPosition = v
            if let faceNode = view.node(for: fa) { faceNode.addChildNode(dot); highlight = dot }
        }
    }
}

// MARK: - Landmark dump: run gated captures and write per-frame metrics + vertices to Documents

struct LandmarkDumpView: View {
    @StateObject private var cap = CaptureSession()
    @State private var sessionName = "s\(Int(Date().timeIntervalSince1970) % 100000)"
    @State private var captures = 0
    @State private var lastReadings: [String: MetricReading] = [:]
    @State private var frames: [FaceFrame] = []

    private var dir: URL { URL.documentsDirectory.appending(path: "captures/\(sessionName)") }

    var body: some View {
        VStack(spacing: Tokens.Space.s3) {
            ARPreview(session: cap.session).clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl)).aspectRatio(3 / 4, contentMode: .fit)
                .overlay(alignment: .top) {
                    HStack { ForEach(Array(cap.gates.chips.enumerated()), id: \.offset) { _, c in GateChip(label: c.label, passing: c.pass) } }.padding(8)
                }
            Text(cap.hint).style(TypeStyle.detail, color: Tokens.Colors.ink700)
            HStack {
                TextField("session", text: $sessionName).frame(width: 120)
                Spacer()
                Text("captures: \(captures)").style(TypeStyle.value)
                Button("Capture") { start() }.buttonStyle(.chunky).frame(width: 140)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(lastReadings.keys.sorted(), id: \.self) { k in
                        let r = lastReadings[k]!
                        Text(String(format: "%-32@ %9.4f  iqr %.4f", k as NSString, r.value, r.iqr)).font(.system(.caption2, design: .monospaced))
                    }
                }
            }
            Text("Files land in Documents/captures/\(sessionName)/. Pull with Finder/Xcode Devices and run core/tools/cv_analysis.py on the folder. 10 captures × 3 sessions is the week-1 target.")
                .style(TypeStyle.caption, color: Tokens.Colors.ink500)
        }
        .padding(Tokens.Space.s5).background(Tokens.Colors.paper)
        .navigationTitle("Landmark dump")
        .onDisappear { cap.stop() }
    }

    private func start() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        frames = []
        cap.dumpFrames = { frames.append($0) }
        cap.start { collected in
            let perFrame = collected.map { MetricFunctions.compute(GeometryPipeline.landmarker.points(from: $0.vertices)) }
            let readings = FrameAggregator.aggregate(perFrame)
            lastReadings = readings
            captures += 1
            let idx = captures
            // one JSON per capture: pose per frame, per-frame metrics, aggregated readings, raw vertices
            struct Dump: Encodable {
                struct F: Encodable { let yaw: Double, pitch: Double, roll: Double, distance: Double; let metrics: [String: Double]; let vertices: [[Float]] }
                let session: String; let capture: Int; let timestamp: Double; let frames: [F]; let readings: [String: MetricReading]
            }
            let d = Dump(session: sessionName, capture: idx, timestamp: Date().timeIntervalSince1970,
                         frames: zip(collected, perFrame).map { f, m in .init(yaw: f.pose.yaw, pitch: f.pose.pitch, roll: f.pose.roll, distance: f.pose.distance, metrics: m.metrics, vertices: f.vertices.map { [$0.x, $0.y, $0.z] }) },
                         readings: readings)
            if let data = try? JSONEncoder().encode(d) { try? data.write(to: dir.appending(path: "capture_\(idx).json")) }
            frames = []
        }
    }
}
#endif
