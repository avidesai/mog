import SwiftUI
import ARKit
import SceneKit
import MogCore

/// The capture flow: dark viewport (the one dark surface in the product), gate chips, a hint
/// line, and a shutter ring that fills as frames are collected. There is no shutter button —
/// capture starts on its own when every gate has passed for half a second.
struct CaptureView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cap = CaptureSession()
    @State private var result: ScoreResult?
    @State private var processing = false
    var onScored: ((ScoreResult) -> Void)? = nil

    private let viewport = Color(light: 0x221F1A, dark: 0x221F1A)

    var body: some View {
        ZStack {
            Tokens.Colors.paper.ignoresSafeArea()
            VStack(spacing: Tokens.Space.s4) {
                HStack {
                    Text(Copy.s("capture.front_title")).style(TypeStyle.title3)
                    Spacer()
                    Button(Copy.s("common.close")) { cap.stop(); dismiss() }.foregroundStyle(Tokens.Colors.ink500)
                }
                .padding(.horizontal, Tokens.Space.s5).padding(.top, Tokens.Space.s2)

                ZStack {
                    ARPreview(session: cap.session)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
                    RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous).fill(viewport.opacity(processing ? 0.92 : 0.0))
                    VStack {
                        chips.padding(Tokens.Space.s4)
                        Spacer()
                        // face guide
                        RoundedRectangle(cornerRadius: 70, style: .continuous).strokeBorder(Color.white.opacity(0.35), lineWidth: 1).frame(width: 190, height: 260)
                        Spacer()
                        Text(hintText).style(TypeStyle.detail, color: Color(light: 0xF4F4F2, dark: 0xF4F4F2)).multilineTextAlignment(.center).padding(.bottom, Tokens.Space.s3)
                        shutter.padding(.bottom, Tokens.Space.s5)
                    }
                    if processing { ProcessingOverlay() }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fit)
                .padding(.horizontal, Tokens.Space.s5)

                Text(Copy.s("capture.shutter_disabled_note")).style(TypeStyle.caption, color: Tokens.Colors.ink500)
                Spacer()
            }
        }
        .onAppear { start() }
        .onDisappear { cap.stop() }
        .onChange(of: cap.phase) { _, p in
            if case .aborted(let gate) = p, !gate.isEmpty { app.analytics.track(.captureAborted(gate: gate)) }
        }
        .fullScreenCover(item: $result) { r in RevealView(result: r) { dismiss() } }
    }

    private var hintText: String {
        switch cap.phase {
        case .aborted(let g): return Copy.f("capture.aborted_body", ["gate": g])
        case .capturing: return Copy.s("capture.hint_ready")
        default: return cap.hint
        }
    }

    private var chips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(Array(cap.gates.chips.enumerated()), id: \.offset) { _, c in GateChip(label: c.label, passing: c.pass) }
        }
    }

    private var shutter: some View {
        let progress: Double = { if case .capturing(let n) = cap.phase { return Double(n) / Double(cap.framesRequired) } else { return 0 } }()
        return ZStack {
            Circle().stroke(Color(light: 0x3A3A3D, dark: 0x3A3A3D), lineWidth: 3)
            Circle().trim(from: 0, to: progress).stroke(Tokens.Colors.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.05), value: progress)
            Circle().fill(cap.gates.allPass ? Color.white : Color(light: 0x3A3A3D, dark: 0x3A3A3D)).padding(9)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)   // the one permitted shadow
        }
        .frame(width: 64, height: 64)
        .onTapGesture { if case .aborted = cap.phase { start() } }
    }

    private func start() {
        guard CaptureSession.isSupported else { return }
        cap.start { frames in
            // Runs on the AR session's thread. Compute here, then hop to main for state + persistence.
            let readings = GeometryPipeline.readings(from: frames, beardPresence: 0, hairlineStage: 1)
            // `frames` is released when this closure returns; nothing was written anywhere.
            DispatchQueue.main.async {
                processing = true
                app.analytics.track(.captureCompleted(pose: "frontal"))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {   // let the processing steps read
                    do {
                        let r = try app.commit(readings: readings, profileCaptured: false)
                        result = r
                        onScored?(r)
                    } catch {
                        cap.stop()
                        processing = false
                    }
                }
            }
        }
    }
}

extension ScoreResult: Identifiable { public var id: String { "\(modelVersion)-\(compositeStd)" } }

/// Camera feed via an ARSCNView with no scene content.
struct ARPreview: UIViewRepresentable {
    let session: ARSession
    func makeUIView(context: Context) -> ARSCNView {
        let v = ARSCNView(frame: .zero)
        v.session = session
        v.automaticallyUpdatesLighting = false
        v.scene = SCNScene()
        return v
    }
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

struct ProcessingOverlay: View {
    @State private var step = 0
    private let keys = ["processing.step_landmarks", "processing.step_normalise", "processing.step_metrics", "processing.step_reference"]
    var body: some View {
        VStack(spacing: Tokens.Space.s3) {
            Text(Copy.s("processing.title")).style(TypeStyle.title2, color: .white)
            ForEach(Array(keys.enumerated()), id: \.offset) { i, k in
                HStack(spacing: 8) {
                    Circle().fill(i <= step ? Tokens.Colors.accent : Color.white.opacity(0.2)).frame(width: 6, height: 6)
                    Text(Copy.s(k)).style(TypeStyle.detail, color: i <= step ? .white : Color.white.opacity(0.5))
                }
            }
            Text(Copy.s("processing.footnote")).style(TypeStyle.caption, color: Color.white.opacity(0.6)).padding(.top, Tokens.Space.s2)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { t in
                if step < keys.count - 1 { step += 1 } else { t.invalidate() }
            }
        }
    }
}
