import Foundation

// Mirrors mogcore/habit.py. Local dates are "YYYY-MM-DD" strings computed by the
// caller in the device time zone at the moment of the event. This file never
// touches the clock or the time zone. Persist `HabitState` as-is (Codable).

public enum HabitConstants {
    public static let pathWeeks = 8
    public static let bankThreshold = 5
    public static let scanWeeks = [4, 8]
    public static let distressResultsOpens = 10
    public static let distressRescanAttempts = 3
    public static let distressCooldownDays = 14
}

public struct TaskDef: Codable, Hashable {
    public let taskId: String
    public let cadence: Cadence
    public let opensWeek: Int
    public let weeklyTarget: Int?
    public init(taskId: String, cadence: Cadence, opensWeek: Int, weeklyTarget: Int? = nil) {
        self.taskId = taskId; self.cadence = cadence; self.opensWeek = opensWeek; self.weeklyTarget = weeklyTarget
    }
}

public struct HabitState: Codable {
    public var planStart: String
    public var tasks: [TaskDef]
    public var completions: [String: Set<String>] = [:]      // localDate → taskIds
    public var currentDays = 0
    public var longestDays = 0
    public var lastCompleteDate: String? = nil
    public var repairUsedMonth: String? = nil                // "YYYY-MM"
    public var bankedWeeks: Set<Int> = []
    public var scans: [Int: String] = [:]                     // weekIndex → scanId
    public var distressLastShown: String? = nil
    public init(planStart: String, tasks: [TaskDef]) { self.planStart = planStart; self.tasks = tasks }
}

public struct DistressSignals { public var resultsOpensToday: Int; public var rescanAttemptsInWindow: Int
    public init(resultsOpensToday: Int, rescanAttemptsInWindow: Int) { self.resultsOpensToday = resultsOpensToday; self.rescanAttemptsInWindow = rescanAttemptsInWindow }
}

public struct DayStatus { public let localDate: String; public let weekIndex: Int; public let dailyDue: [String]; public let dailyDone: [String]; public let complete: Bool }

public enum HabitError: Error { case unknownTask(String), taskNotOpen(String, Int), noScanWindow }

/// Date arithmetic on "YYYY-MM-DD" strings. Uses a proleptic Gregorian day number so it is
/// independent of Calendar/TimeZone and matches Python's `date` arithmetic exactly.
enum LocalDate {
    static func parse(_ s: String) -> (Int, Int, Int) {
        let p = s.split(separator: "-").map { Int($0)! }
        return (p[0], p[1], p[2])
    }
    static func format(_ y: Int, _ m: Int, _ d: Int) -> String { String(format: "%04d-%02d-%02d", y, m, d) }
    /// Days since 1970-01-01 (civil-from-days algorithm, Howard Hinnant).
    static func ordinal(_ s: String) -> Int {
        var (y, m, d) = parse(s)
        if m <= 2 { y -= 1 }
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }
    static func fromOrdinal(_ z0: Int) -> String {
        let z = z0 + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp + (mp < 10 ? 3 : -9)
        return format(m <= 2 ? y + 1 : y, m, d)
    }
    static func add(_ s: String, days: Int) -> String { fromOrdinal(ordinal(s) + days) }
    static func diff(_ a: String, _ b: String) -> Int { ordinal(a) - ordinal(b) }   // a - b in days
    static func month(_ s: String) -> String { String(s.prefix(7)) }
}

public final class HabitEngine {
    public private(set) var s: HabitState
    public init(_ state: HabitState) { s = state }

    // MARK: calendar
    public func weekIndex(_ localDate: String) -> Int {
        let days = LocalDate.diff(localDate, s.planStart)
        return days < 0 ? 0 : days / 7 + 1
    }
    public func weekDates(_ week: Int) -> [String] {
        let start = LocalDate.add(s.planStart, days: 7 * (week - 1))
        return (0..<7).map { LocalDate.add(start, days: $0) }
    }
    public func openTasks(_ week: Int) -> [TaskDef] { s.tasks.filter { $0.opensWeek <= week } }
    public func dailyDue(_ week: Int) -> [String] { openTasks(week).filter { $0.cadence == .daily }.map(\.taskId) }

    // MARK: days
    public func dayStatus(_ localDate: String) -> DayStatus {
        let wk = weekIndex(localDate)
        let due = dailyDue(wk)
        let doneSet = s.completions[localDate] ?? []
        let done = due.filter { doneSet.contains($0) }
        return DayStatus(localDate: localDate, weekIndex: wk, dailyDue: due, dailyDone: done,
                         complete: wk >= 1 && !due.isEmpty && done.count == due.count)
    }

    @discardableResult
    public func completeTask(_ taskId: String, on localDate: String) throws -> DayStatus {
        guard let tdef = s.tasks.first(where: { $0.taskId == taskId }) else { throw HabitError.unknownTask(taskId) }
        let wk = weekIndex(localDate)
        if tdef.opensWeek > wk { throw HabitError.taskNotOpen(taskId, wk) }
        let before = dayStatus(localDate).complete
        s.completions[localDate, default: []].insert(taskId)
        let after = dayStatus(localDate)
        if after.complete && !before { onDayComplete(localDate) }
        maybeBank(wk)
        return after
    }

    @discardableResult
    public func uncompleteTask(_ taskId: String, on localDate: String) -> DayStatus {
        s.completions[localDate]?.remove(taskId)
        return dayStatus(localDate)
    }

    private func onDayComplete(_ localDate: String) {
        if let last = s.lastCompleteDate {
            let gap = LocalDate.diff(localDate, last)
            if gap == 1 { s.currentDays += 1 }
            else if gap <= 0 { return }
            else { s.currentDays = 1 }
        } else { s.currentDays = 1 }
        s.lastCompleteDate = localDate
        s.longestDays = max(s.longestDays, s.currentDays)
    }

    // MARK: streaks
    public func streakAtRisk(today: String) -> Bool {
        guard let last = s.lastCompleteDate, s.currentDays > 0 else { return false }
        return LocalDate.diff(today, last) == 2
    }
    public func repairAvailable(today: String) -> Bool { s.repairUsedMonth != LocalDate.month(today) }
    @discardableResult
    public func useRepair(today: String) -> Bool {
        guard streakAtRisk(today: today), repairAvailable(today: today) else { return false }
        s.lastCompleteDate = LocalDate.add(today, days: -1)
        s.repairUsedMonth = LocalDate.month(today)
        return true
    }
    /// Call on app foreground.
    public func reconcile(today: String) {
        guard let last = s.lastCompleteDate else { return }
        if LocalDate.diff(today, last) >= 2 { s.currentDays = 0 }
    }

    // MARK: weeks
    public func daysCompleteInWeek(_ week: Int) -> Int { weekDates(week).filter { dayStatus($0).complete }.count }
    public func weeklyProgress(_ week: Int) -> [String: (done: Int, target: Int)] {
        let dates = Set(weekDates(week))
        var out: [String: (Int, Int)] = [:]
        for t in openTasks(week) where t.cadence == .weekly {
            let done = s.completions.filter { dates.contains($0.key) && $0.value.contains(t.taskId) }.count
            out[t.taskId] = (done, t.weeklyTarget ?? 0)
        }
        return out
    }
    private func maybeBank(_ week: Int) {
        if (1...HabitConstants.pathWeeks).contains(week), !s.bankedWeeks.contains(week),
           daysCompleteInWeek(week) >= HabitConstants.bankThreshold { s.bankedWeeks.insert(week) }
    }
    public func isBanked(_ week: Int) -> Bool { s.bankedWeeks.contains(week) }

    // MARK: scans
    public func scanWindowOpen(today: String) -> Int? {
        let wk = weekIndex(today)
        return HabitConstants.scanWeeks.first { wk >= $0 && s.scans[$0] == nil }
    }
    public func daysUntilNextScan(today: String) -> Int? {
        let wk = weekIndex(today)
        for sw in HabitConstants.scanWeeks where s.scans[sw] == nil && wk < sw {
            return LocalDate.diff(LocalDate.add(s.planStart, days: 7 * (sw - 1)), today)
        }
        return nil
    }
    @discardableResult
    public func recordScan(today: String, scanId: String) throws -> Int {
        guard let sw = scanWindowOpen(today: today) else { throw HabitError.noScanWindow }
        s.scans[sw] = scanId
        return sw
    }

    // MARK: distress
    public func shouldShowDistress(today: String, _ sig: DistressSignals) -> Bool {
        let triggered = sig.resultsOpensToday >= HabitConstants.distressResultsOpens || sig.rescanAttemptsInWindow >= HabitConstants.distressRescanAttempts
        guard triggered else { return false }
        if let last = s.distressLastShown, LocalDate.diff(today, last) < HabitConstants.distressCooldownDays { return false }
        return true
    }
    public func markDistressShown(today: String) { s.distressLastShown = today }

    public var finishedPath: Bool { s.scans[8] != nil }
}
