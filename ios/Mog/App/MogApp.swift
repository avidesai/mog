import SwiftUI
import SwiftData
import MogCore

@main
struct MogApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(.light)   // one light register; only the capture viewport is dark
                .tint(Tokens.Colors.accent)
                .onAppear { app.onForeground() }
        }
        .modelContainer(Store.container)
    }
}

/// Top-level navigation state. Everything the app needs to decide what to show on launch
/// is here; feature views read/write through this object.
@MainActor @Observable
final class AppModel {
    enum Route { case onboarding, consent, home }

    // Loaded once; MogCore.Registry validates the tables and refuses to load if they're inconsistent.
    let registry: Registry = {
        do { return try Registry.load() } catch { fatalError("MogCore registry failed to load: \(error)") }
    }()

    var profile: UserProfile = UserProfile.load()
    var route: Route = .onboarding
    var latestScore: ScoreResult?
    var latestPlan: PlanResult?
    var habit: HabitEngine?
    var isPro: Bool = false

    let purchases: Purchases = PurchasesStub()
    let analytics = Analytics()

    init() {
        route = profile.onboardingComplete ? (profile.consentGranted ? .home : .consent) : .onboarding
        rehydrate()
    }

    func onForeground() {
        if let habit { habit.reconcile(today: LocalDay.today()) }
        Task { isPro = await purchases.isPro() }
    }

    /// Rebuild score / plan / habit from the persisted latest scan, if any.
    func rehydrate() {
        guard let scan = Store.latestScan() else { return }
        if let result = try? score(scan.toScoreInput(sex: profile.sex, ageBand: profile.ageBand), registry) {
            latestScore = result
            if let plan = try? buildPlan(PlanInput(goals: profile.goals, timeBudgetMin: profile.timeBudgetMin, score: result), registry) {
                latestPlan = plan
                habit = HabitEngine(Store.habitState(for: plan, planStart: scan.localDate))
            }
        }
    }

    /// Called by the capture flow with the aggregated readings.
    func commit(readings: [String: MetricReading], profileCaptured: Bool) throws -> ScoreResult {
        let input = ScoreInput(sex: profile.sex, ageBand: profile.ageBand, readings: readings, profileCaptured: profileCaptured)
        let result = try MogCore.score(input, registry)
        let scan = Store.saveScan(readings: readings, profileCaptured: profileCaptured, result: result)
        let plan = try buildPlan(PlanInput(goals: profile.goals, timeBudgetMin: profile.timeBudgetMin, score: result), registry)
        latestScore = result
        latestPlan = plan
        if habit == nil {
            habit = HabitEngine(Store.habitState(for: plan, planStart: scan.localDate))
        } else if let h = habit, let week = h.scanWindowOpen(today: LocalDay.today()) {
            _ = try? h.recordScan(today: LocalDay.today(), scanId: scan.id)
            Store.save(habit: h.s)
            analytics.track(.scanRecorded(week: week))
        }
        analytics.track(.scoreComputed(nScored: result.nScored))
        return result
    }
}

/// Device-local calendar date as "yyyy-MM-dd", computed at the moment of the event. The habit
/// engine never reads the clock itself.
enum LocalDay {
    private static let fmt: DateFormatter = { let f = DateFormatter(); f.calendar = .current; f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"; return f }()
    static func today() -> String { fmt.string(from: Date()) }
}
