import SwiftUI
import MogCore

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var confirmDelete = false
    @State private var showPaywall = false
    @State private var showCapture = false

    var body: some View {
        NavigationStack {
            Screen {
                SectionLabel(text: Copy.s("settings.section_account"))
                Card {
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        row(Copy.f("settings.reference_table", ["sex": app.profile.sex.rawValue, "age_band": app.profile.ageBand]))
                        row(Copy.s("settings.goals") + ": " + app.profile.goals.compactMap { app.registry.goals[$0] }.joined(separator: ", "))
                        row(Copy.s("settings.time_budget") + ": \(app.profile.timeBudgetMin) min")
                    }
                }

                SectionLabel(text: Copy.s("settings.section_plan"))
                Card {
                    if app.isPro { row("Pro") ; Button(Copy.s("settings.manage_subscription")) { UIApplication.shared.open(URL(string: "https://apps.apple.com/account/subscriptions")!) } }
                    else { Button(Copy.s("paywall.title")) { showPaywall = true } }
                }

                SectionLabel(text: Copy.s("settings.section_data"))
                Card {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        if let at = app.profile.consentAt {
                            row(Copy.f("settings.consent_status", ["date": at.formatted(date: .abbreviated, time: .omitted)]))
                            Button(Copy.s("settings.consent_revoke")) { var p = app.profile; p.consentGranted = false; p.save(); app.profile = p }
                                .foregroundStyle(Tokens.Colors.ink700)
                            Text(Copy.s("settings.consent_revoke_body")).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                        }
                        Toggle(isOn: Binding(get: { app.profile.syncEnabled }, set: { var p = app.profile; p.syncEnabled = $0; p.save(); app.profile = p })) {
                            Text(Copy.s("settings.cloud_sync")).style(TypeStyle.body)
                        }.tint(Tokens.Colors.accent).disabled(true)   // TODO(week 7): Supabase sync
                        Button(Copy.s("settings.add_profile")) { showCapture = true }.disabled(true)   // TODO: profile capture (spike 2)
                        Button(Copy.s("settings.delete_everything")) { confirmDelete = true }.buttonStyle(.chunky(.critical))
                        Text(Copy.s("settings.delete_body")).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                    }
                }

                SectionLabel(text: Copy.s("settings.section_about"))
                Card {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        NavigationLink(Copy.s("settings.methodology")) { MethodologyView() }
                        Link(Copy.s("common.biometric_policy"), destination: URL(string: "https://example.invalid/biometric-policy")!)
                        Link(Copy.s("common.privacy"), destination: URL(string: "https://example.invalid/privacy")!)
                        Link(Copy.s("common.terms"), destination: URL(string: "https://example.invalid/terms")!)
                        Text(Copy.f("settings.version", ["app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0", "model_version": ScoringConstants.modelVersion]))
                            .style(TypeStyle.caption, color: Tokens.Colors.ink500)
                    }
                }

                #if DEBUG
                SectionLabel(text: "Debug")
                Card(ground: Tokens.Colors.raised) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        Toggle("Pretend Pro", isOn: Binding(get: { PurchasesStub.debugPro }, set: { PurchasesStub.debugPro = $0; app.isPro = $0 })).tint(Tokens.Colors.accent)
                        NavigationLink("Vertex picker (spike 1)") { VertexPickerView() }
                        NavigationLink("Landmark dump (spike 1)") { LandmarkDumpView() }
                        Text("Picked landmark indices: \(GeometryPipeline.landmarker.pickedCount) / 38").style(TypeStyle.detail, color: Tokens.Colors.ink500)
                    }
                }
                #endif
            }
            .navigationTitle(Copy.s("settings.title")).navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Tokens.Colors.paper, for: .navigationBar)
        }
        .sheet(isPresented: $showPaywall) { PaywallView(placement: "settings") }
        .fullScreenCover(isPresented: $showCapture) { CaptureView() }
        .confirmationDialog(Copy.s("settings.delete_everything"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(Copy.s("settings.delete_confirm"), role: .destructive) { deleteEverything() }
            Button(Copy.s("common.not_now"), role: .cancel) {}
        } message: { Text(Copy.s("settings.delete_body")) }
    }

    private func row(_ s: String) -> some View { Text(s).style(TypeStyle.body) }

    private func deleteEverything() {
        app.analytics.track(.deleteEverything)
        Store.wipeAll()
        // TODO(week 7): queue server-side deletion if sync was ever on; tombstone the account.
        app.profile = UserProfile()
        app.latestScore = nil; app.latestPlan = nil; app.habit = nil
        app.route = .onboarding
    }
}

struct MethodologyView: View {
    private let sections: [(String, String)] = [
        ("methodology.section_capture", "methodology.capture_body"), ("methodology.section_metrics", "methodology.metrics_body"),
        ("methodology.section_score", "methodology.score_body"), ("methodology.section_band", "methodology.band_body"),
        ("methodology.section_tiers", "methodology.tiers_body"), ("methodology.section_reference", "methodology.reference_body"),
        ("methodology.section_privacy", "methodology.privacy_body"), ("methodology.section_reliability_target", "methodology.reliability_target_body"),
    ]
    var body: some View {
        Screen(title: Copy.s("methodology.title")) {
            Text(Copy.s("methodology.what_the_score_is")).style(TypeStyle.body)
            Text(Copy.s("methodology.what_it_is_not")).style(TypeStyle.body, color: Tokens.Colors.ink700)
            ForEach(sections, id: \.0) { h, b in
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text(Copy.s(h)).style(TypeStyle.title3)
                    Text(Copy.s(b)).style(TypeStyle.body, color: Tokens.Colors.ink700)
                }
            }
            Text(Copy.f("methodology.versions_body", ["version": ScoringConstants.modelVersion])).style(TypeStyle.detail, color: Tokens.Colors.ink500)
        }
        .toolbarBackground(Tokens.Colors.paper, for: .navigationBar)
    }
}
