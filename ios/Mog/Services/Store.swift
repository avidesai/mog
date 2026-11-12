import Foundation
import SwiftData
import MogCore

// Local persistence. Only named measurements and habit state are ever stored — never frames,
// depth, landmarks or anything a face could be reconstructed from. The container uses
// `completeFileProtection` so the store is unreadable while the device is locked.

@Model
final class ScanRecord {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var localDate: String                 // yyyy-MM-dd in the device zone at capture time
    var profileCaptured: Bool
    var modelVersion: String
    var score: Double
    var scoreLow: Double
    var scoreHigh: Double
    var tier: String
    var readingsJSON: Data                // [String: MetricReading]

    init(id: String, createdAt: Date, localDate: String, profileCaptured: Bool, modelVersion: String,
         score: Double, scoreLow: Double, scoreHigh: Double, tier: String, readingsJSON: Data) {
        self.id = id; self.createdAt = createdAt; self.localDate = localDate; self.profileCaptured = profileCaptured
        self.modelVersion = modelVersion; self.score = score; self.scoreLow = scoreLow; self.scoreHigh = scoreHigh
        self.tier = tier; self.readingsJSON = readingsJSON
    }

    var readings: [String: MetricReading] { (try? JSONDecoder().decode([String: MetricReading].self, from: readingsJSON)) ?? [:] }
    func toScoreInput(sex: Sex, ageBand: String) -> ScoreInput {
        ScoreInput(sex: sex, ageBand: ageBand, readings: readings, profileCaptured: profileCaptured)
    }
}

@Model
final class HabitRecord {
    @Attribute(.unique) var id: String = "singleton"
    var stateJSON: Data
    init(stateJSON: Data) { self.stateJSON = stateJSON }
}

@Model
final class UsageCounters {
    @Attribute(.unique) var localDate: String
    var resultsOpens: Int = 0
    var rescanAttempts: Int = 0
    init(localDate: String) { self.localDate = localDate }
}

enum Store {
    static let container: ModelContainer = {
        let schema = Schema([ScanRecord.self, HabitRecord.self, UsageCounters.self])
        let url = URL.applicationSupportDirectory.appending(path: "mog.store")
        let config = ModelConfiguration(schema: schema, url: url, allowsSave: true)
        do {
            let c = try ModelContainer(for: schema, configurations: [config])
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
            return c
        } catch { fatalError("store: \(error)") }
    }()

    @MainActor private static var ctx: ModelContext { container.mainContext }

    @MainActor static func latestScan() -> ScanRecord? {
        var d = FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        d.fetchLimit = 1
        return try? ctx.fetch(d).first
    }

    @MainActor static func allScans() -> [ScanRecord] {
        (try? ctx.fetch(FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    @MainActor @discardableResult
    static func saveScan(readings: [String: MetricReading], profileCaptured: Bool, result: ScoreResult) -> ScanRecord {
        let rec = ScanRecord(id: UUID().uuidString, createdAt: Date(), localDate: LocalDay.today(), profileCaptured: profileCaptured,
                             modelVersion: result.modelVersion, score: result.score, scoreLow: result.scoreLow, scoreHigh: result.scoreHigh,
                             tier: result.tier, readingsJSON: (try? JSONEncoder().encode(readings)) ?? Data())
        ctx.insert(rec); try? ctx.save()
        return rec
    }

    /// Existing habit state if there is one, else a fresh state built from the plan's tasks.
    @MainActor static func habitState(for plan: PlanResult, planStart: String) -> HabitState {
        let tasks = plan.tasks.map { TaskDef(taskId: $0.id, cadence: $0.cadence, opensWeek: $0.opensWeek, weeklyTarget: $0.weeklyTarget) }
        if let rec = try? ctx.fetch(FetchDescriptor<HabitRecord>()).first, var s = try? JSONDecoder().decode(HabitState.self, from: rec.stateJSON) {
            s.tasks = tasks   // the plan is rebuilt on each scan; completions and streak carry over
            return s
        }
        return HabitState(planStart: planStart, tasks: tasks)
    }

    @MainActor static func save(habit: HabitState) {
        guard let data = try? JSONEncoder().encode(habit) else { return }
        if let rec = try? ctx.fetch(FetchDescriptor<HabitRecord>()).first { rec.stateJSON = data } else { ctx.insert(HabitRecord(stateJSON: data)) }
        try? ctx.save()
    }

    @MainActor static func counters(_ day: String = LocalDay.today()) -> UsageCounters {
        let d = FetchDescriptor<UsageCounters>(predicate: #Predicate { $0.localDate == day })
        if let c = try? ctx.fetch(d).first { return c }
        let c = UsageCounters(localDate: day); ctx.insert(c); return c
    }

    /// "Delete everything": wipe the local store now. Server-side deletion (if sync was on) is queued separately.
    @MainActor static func wipeAll() {
        try? ctx.delete(model: ScanRecord.self)
        try? ctx.delete(model: HabitRecord.self)
        try? ctx.delete(model: UsageCounters.self)
        try? ctx.save()
        UserProfile.wipe()
    }
}
