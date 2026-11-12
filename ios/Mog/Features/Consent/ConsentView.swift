import SwiftUI

/// BIPA-grade consent: plain-English points, an explicit affirmative control separate from the
/// Terms and from any purchase, never pre-selected; the policy version and time are recorded.
struct ConsentView: View {
    @Environment(AppModel.self) private var app
    let onDone: () -> Void
    @State private var affirmed = false
    @State private var declined = false
    @State private var state: String = ""

    private let points = ["consent.point_captured", "consent.point_processed", "consent.point_retained", "consent.point_cloud", "consent.point_delete", "consent.point_policy"]

    var body: some View {
        VStack(spacing: 0) {
            Screen(title: Copy.s("consent.title")) {
                Text(Copy.s("consent.body_1")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                Card(padding: Tokens.Space.s5, ground: Tokens.Colors.surface50) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                        ForEach(points, id: \.self) { k in
                            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                                Circle().fill(Tokens.Colors.accent).frame(width: 6, height: 6).padding(.top, 8)
                                Text(Copy.s(k)).style(TypeStyle.body)
                            }
                        }
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous).strokeBorder(Tokens.Colors.ink900, lineWidth: Tokens.Border.emphasis))

                // State attestation gate (IL/TX/WA excluded at launch — legal/README.md)
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    SectionLabel(text: "US state of residence")
                    TextField("e.g. CA — leave blank outside the US", text: $state)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .padding(Tokens.Space.s4)
                        .background(RoundedRectangle(cornerRadius: Tokens.Radius.lg).fill(Tokens.Colors.surface50)
                            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg).strokeBorder(Tokens.Colors.line200, lineWidth: Tokens.Border.hairline)))
                    if blocked {
                        Text(Copy.s("consent.state_block_body")).style(TypeStyle.detail, color: Tokens.Colors.caution)
                    }
                }

                Toggle(isOn: $affirmed) { Text(Copy.s("consent.affirm_label")).style(TypeStyle.rowTitle) }
                    .tint(Tokens.Colors.accent).disabled(blocked)

                HStack {
                    Link(Copy.s("common.biometric_policy"), destination: URL(string: "https://example.invalid/biometric-policy")!)
                    Text("·").foregroundStyle(Tokens.Colors.ink300)
                    Link(Copy.s("common.privacy"), destination: URL(string: "https://example.invalid/privacy")!)
                }.font(TypeStyle.detail.font).foregroundStyle(Tokens.Colors.ink500)
                // TODO(week 7): replace with the hosted policy URLs.

                if declined {
                    Text(Copy.s("consent.decline_body")).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                }
            }
            footer {
                Button(Copy.s("consent.affirm_cta")) { grant() }.buttonStyle(.chunky).disabled(!affirmed || blocked).opacity(affirmed && !blocked ? 1 : 0.5)
                Button(Copy.s("consent.decline_cta")) { decline() }.buttonStyle(.quiet)
            }
        }
    }

    private var blocked: Bool { UserProfile.blockedStates.contains(state.trimmingCharacters(in: .whitespaces).uppercased()) }

    private func grant() {
        var p = app.profile
        p.consentGranted = true; p.consentAt = Date(); p.consentPolicyVersion = Policy.biometricPolicyVersion
        p.stateAttestation = state.isEmpty ? nil : state.uppercased()
        p.save(); app.profile = p
        app.analytics.track(.consentGranted)
        onDone()
    }
    private func decline() {
        declined = true
        app.analytics.track(.consentDeclined)
        var p = app.profile; p.stateAttestation = state.isEmpty ? nil : state.uppercased(); p.save(); app.profile = p
        onDone()   // the app still opens; TodayEmpty explains that nothing can be measured
    }
}
