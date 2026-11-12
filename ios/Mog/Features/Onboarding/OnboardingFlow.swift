import SwiftUI
import MogCore

struct OnboardingFlow: View {
    @Environment(AppModel.self) private var app
    @State private var step = 0
    @State private var draft = UserProfile()

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 0: StartView(onStart: { advance() })
                case 1: GoalsView(goals: $draft.goals, onContinue: { advance() })
                case 2: AboutView(sex: $draft.sex, ageBand: $draft.ageBand, attested: $draft.ageAttestedAt, onContinue: { advance() })
                default: TimeView(minutes: $draft.timeBudgetMin, onContinue: { finish() })
                }
            }
            .toolbar {
                if step > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(Copy.s("common.back")) { step -= 1 }.foregroundStyle(Tokens.Colors.ink500)
                    }
                }
            }
            .toolbarBackground(Tokens.Colors.paper, for: .navigationBar)
        }
        .animation(.easeInOut(duration: Tokens.Motion.standard), value: step)
    }

    private func advance() { app.analytics.track(.onboardingStep("\(step)")); step += 1 }
    private func finish() {
        var p = draft
        p.onboardingComplete = true
        p.save()
        app.profile = p
        app.route = .consent
    }
}

struct StartView: View {
    let onStart: () -> Void
    var body: some View {
        ZStack {
            Tokens.Colors.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                Spacer()
                HStack(spacing: 6) {
                    Text(Copy.appName.lowercased()).style(TypeStyle.title2)
                    Circle().fill(Tokens.Colors.bronze).frame(width: 8, height: 8).offset(y: 4)   // the wordmark tick
                }
                Text(Copy.s("onboarding.start_title")).style(TypeStyle.displayTitle)
                Text(Copy.s("onboarding.start_body")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                Spacer()
                Button(Copy.s("onboarding.start_cta"), action: onStart).buttonStyle(.chunky)
                Text(Copy.s("onboarding.start_age_note")).style(TypeStyle.caption, color: Tokens.Colors.ink500).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Tokens.Space.s5).padding(.bottom, Tokens.Space.s6)
        }
    }
}

struct GoalsView: View {
    @Binding var goals: [String]
    let onContinue: () -> Void
    private let all: [(String, String)] = [
        ("sharper_jawline", "onboarding.goal_sharper_jawline"), ("better_skin", "onboarding.goal_better_skin"),
        ("look_leaner", "onboarding.goal_look_leaner"), ("hair", "onboarding.goal_hair"), ("eye_area", "onboarding.goal_eye_area"),
        ("better_photos", "onboarding.goal_better_photos"), ("general", "onboarding.goal_general"),
    ]
    var body: some View {
        VStack(spacing: 0) {
            Screen(title: Copy.s("onboarding.goals_title")) {
                Text(Copy.s("onboarding.goals_body")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                VStack(spacing: Tokens.Space.s3) {
                    ForEach(all, id: \.0) { id, key in
                        OptionRow(title: Copy.s(key), rank: goals.firstIndex(of: id).map { $0 + 1 }, selected: goals.contains(id)) { toggle(id) }
                    }
                }
            }
            footer { Button(Copy.s("common.continue"), action: onContinue).buttonStyle(.chunky).disabled(goals.isEmpty).opacity(goals.isEmpty ? 0.5 : 1) }
        }
    }
    private func toggle(_ id: String) {
        if let i = goals.firstIndex(of: id) { goals.remove(at: i) }
        else if id == "general" { goals = ["general"] }
        else { goals.removeAll { $0 == "general" }; if goals.count < 3 { goals.append(id) } }
    }
}

struct AboutView: View {
    @Binding var sex: Sex
    @Binding var ageBand: String
    @Binding var attested: Date?
    let onContinue: () -> Void
    private let bands = [("18-24", "onboarding.about_age_18_24"), ("25-34", "onboarding.about_age_25_34"), ("35-44", "onboarding.about_age_35_44"), ("45+", "onboarding.about_age_45")]
    var body: some View {
        VStack(spacing: 0) {
            Screen(title: Copy.s("onboarding.about_title")) {
                Text(Copy.s("onboarding.about_body")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                SectionLabel(text: Copy.s("onboarding.about_sex_label"))
                HStack(spacing: Tokens.Space.s3) {
                    OptionRow(title: Copy.s("onboarding.about_sex_male"), selected: sex == .male) { sex = .male }
                    OptionRow(title: Copy.s("onboarding.about_sex_female"), selected: sex == .female) { sex = .female }
                }
                SectionLabel(text: Copy.s("onboarding.about_age_label"))
                VStack(spacing: Tokens.Space.s3) {
                    ForEach(bands, id: \.0) { id, key in OptionRow(title: Copy.s(key), selected: ageBand == id) { ageBand = id } }
                }
                Toggle(isOn: Binding(get: { attested != nil }, set: { attested = $0 ? Date() : nil })) {
                    Text(Copy.s("onboarding.about_age_attest")).style(TypeStyle.body)
                }
                .tint(Tokens.Colors.accent)
            }
            footer { Button(Copy.s("common.continue"), action: onContinue).buttonStyle(.chunky).disabled(attested == nil).opacity(attested == nil ? 0.5 : 1) }
        }
    }
}

struct TimeView: View {
    @Binding var minutes: Int
    let onContinue: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            Screen(title: Copy.s("onboarding.time_title")) {
                Text(Copy.s("onboarding.time_body")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                VStack(spacing: Tokens.Space.s3) {
                    OptionRow(title: Copy.s("onboarding.time_5"), selected: minutes == 5) { minutes = 5 }
                    OptionRow(title: Copy.s("onboarding.time_15"), selected: minutes == 15) { minutes = 15 }
                    OptionRow(title: Copy.s("onboarding.time_30"), selected: minutes == 30) { minutes = 30 }
                }
                Text(Copy.s("onboarding.time_footnote")).style(TypeStyle.detail, color: Tokens.Colors.ink500)
            }
            footer { Button(Copy.s("common.continue"), action: onContinue).buttonStyle(.chunky) }
        }
    }
}

/// Sticky bottom action area on paper.
@ViewBuilder func footer<V: View>(@ViewBuilder _ content: () -> V) -> some View {
    VStack { content() }
        .padding(.horizontal, Tokens.Space.s5).padding(.top, Tokens.Space.s3).padding(.bottom, Tokens.Space.s2)
        .background(Tokens.Colors.paper)
}
