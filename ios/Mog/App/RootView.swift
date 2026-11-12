import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        switch app.route {
        case .onboarding: OnboardingFlow()
        case .consent: ConsentView(onDone: { app.route = .home })
        case .home: HomeTabs()
        }
    }
}

/// Four tabs. Today is the home; everything else is one tap away. No badge counts anywhere.
struct HomeTabs: View {
    @Environment(AppModel.self) private var app
    @State private var tab: Tab = .today
    enum Tab: Hashable { case today, plan, path, you }

    var body: some View {
        TabView(selection: $tab) {
            TodayView().tabItem { Label(Copy.s("today.title"), systemImage: "sun.max") }.tag(Tab.today)
            PlanView().tabItem { Label(Copy.s("plan.title"), systemImage: "list.bullet.rectangle") }.tag(Tab.plan)
            PathView().tabItem { Label(Copy.s("journey.title"), systemImage: "point.topleft.down.to.point.bottomright.curvepath") }.tag(Tab.path)
            SettingsView().tabItem { Label(Copy.s("settings.title"), systemImage: "person") }.tag(Tab.you)
        }
    }
}
