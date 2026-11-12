import SwiftUI
import MogCore

/// The reveal: one number, its band, its tier, the one-line definition. 600 ms deliberate
/// fade-in — the only place the "deliberate" motion token is used besides the day-complete ring.
struct RevealView: View {
    @Environment(AppModel.self) private var app
    let result: ScoreResult
    let onContinue: () -> Void
    @State private var shown = false
    @State private var showResults = false

    var body: some View {
        ZStack {
            Tokens.Colors.paper.ignoresSafeArea()
            VStack(spacing: Tokens.Space.s6) {
                Spacer()
                SectionLabel(text: Copy.s("reveal.eyebrow"))
                ScoreBand(result: result).opacity(shown ? 1 : 0).offset(y: shown ? 0 : 8)
                Text(Copy.s("reveal.what_it_is")).style(TypeStyle.body, color: Tokens.Colors.ink700).multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.s5).opacity(shown ? 1 : 0)
                Spacer()
                VStack(spacing: Tokens.Space.s3) {
                    Button(Copy.s("reveal.cta_results")) { showResults = true }.buttonStyle(.chunky)
                    Text(Copy.f("reveal.model_version", ["version": result.modelVersion])).style(TypeStyle.caption, color: Tokens.Colors.ink500)
                }
                .padding(.horizontal, Tokens.Space.s5).padding(.bottom, Tokens.Space.s6)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: Tokens.Motion.deliberate)) { shown = true } }
        .fullScreenCover(isPresented: $showResults, onDismiss: onContinue) { ResultsView(result: result) }
    }
}
