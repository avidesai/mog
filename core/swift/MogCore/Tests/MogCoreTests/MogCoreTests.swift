import XCTest
@testable import MogCore

// The cross-language gate: every case in fixtures/scoring_cases.json must reproduce
// composite_std to 1e-6 and tier exactly. If this fails, the Swift port has drifted
// from the Python spec — fix the port, never the fixture.

final class FixtureTests: XCTestCase {
    struct Case: Codable {
        let name: String; let sex: String; let age_band: String; let profile_captured: Bool
        let readings: [String: MetricReading]
        let expected: Expected
        struct Expected: Codable { let composite_std: Double; let score: Double; let tier: String; let n_scored: Int }
    }

    func testRegistryLoads() throws {
        let reg = try Registry.load()
        XCTAssertGreaterThanOrEqual(reg.metrics.count, 30)
        XCTAssertGreaterThanOrEqual(reg.rules.count, 25)
    }

    func testGoldenFixtures() throws {
        let reg = try Registry.load()
        let url = Bundle.module.url(forResource: "scoring_cases", withExtension: "json", subdirectory: "Resources")
            ?? Bundle.module.url(forResource: "scoring_cases", withExtension: "json")!
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        XCTAssertFalse(cases.isEmpty)
        for c in cases {
            let r = try score(ScoreInput(sex: Sex(rawValue: c.sex)!, ageBand: c.age_band, readings: c.readings, profileCaptured: c.profile_captured), reg)
            XCTAssertEqual(r.compositeStd, c.expected.composite_std, accuracy: 1e-6, c.name)
            XCTAssertEqual((r.score * 100).rounded() / 100, c.expected.score, accuracy: 0.005, c.name)
            XCTAssertEqual(r.tier, c.expected.tier, c.name)
            XCTAssertEqual(r.nScored, c.expected.n_scored, c.name)
        }
    }

    func testDeterministic() throws {
        let reg = try Registry.load()
        var rd: [String: MetricReading] = [:]
        for (id, m) in reg.metrics {
            let n = m.ref(.male)
            rd[id] = m.unit == "category" ? MetricReading(value: id == "hairline_stage" ? 1 : 0, confidence: 0.9)
                                          : MetricReading(value: n.mean + 0.7 * n.sd, confidence: 0.9, iqr: 0.05 * n.sd)
        }
        let a = try score(ScoreInput(sex: .male, ageBand: "18-24", readings: rd), reg)
        let b = try score(ScoreInput(sex: .male, ageBand: "18-24", readings: rd), reg)
        XCTAssertEqual(a.composite, b.composite)
        XCTAssertEqual(a.compositeStd, b.compositeStd)
    }

    func testNonFiniteReadingIsSuppressed() throws {
        let reg = try Registry.load()
        var rd: [String: MetricReading] = [:]
        for (id, m) in reg.metrics {
            let n = m.ref(.male)
            rd[id] = m.unit == "category" ? MetricReading(value: id == "hairline_stage" ? 1 : 0, confidence: 0.9)
                                          : MetricReading(value: n.mean, confidence: 0.9, iqr: 0.05 * n.sd)
        }
        let base = try score(ScoreInput(sex: .male, ageBand: "18-24", readings: rd), reg)
        for broken in [MetricReading(value: .nan, confidence: 0.9), MetricReading(value: 0.5, confidence: .nan)] {
            var bad = rd
            bad["facial_adiposity"] = broken
            let r = try score(ScoreInput(sex: .male, ageBand: "18-24", readings: bad), reg)
            XCTAssertEqual(r.metrics.first { $0.id == "facial_adiposity" }?.suppressedReason, "low_confidence")
            XCTAssertEqual(r.nScored, base.nScored - 1)
            XCTAssertTrue(r.score.isFinite)
        }
    }

    func testAllRuleCopyPassesDenylist() throws {
        let reg = try Registry.load()
        for r in reg.rules.values where r.safety_tier != .excluded {
            for text in [r.copy.headline, r.copy.body, r.copy.why_this] {
                let hits = reg.denylist.scan(text, infoCard: r.isInfoCard).filter { hit in
                    !(r.safety_tier.isProfessional && reg.denylist.allowedInProfessional.contains(hit.match.lowercased()))
                }
                XCTAssertTrue(hits.isEmpty, "\(r.id): \(hits.map(\.match))")
            }
        }
    }

    func testTierBands() {
        XCTAssertEqual(tierForPercentile(41).short, "LTN")
        XCTAssertEqual(tierForPercentile(50).short, "MTN")
        XCTAssertEqual(tierForPercentile(68).short, "HTN")
        XCTAssertEqual(tierForPercentile(90).short, "Chadlite")
        XCTAssertEqual(tierForPercentile(99).short, "Chad")
    }
}

final class HabitTests: XCTestCase {
    let tasks = [TaskDef(taskId: "spf", cadence: .daily, opensWeek: 1), TaskDef(taskId: "sleep", cadence: .daily, opensWeek: 1),
                 TaskDef(taskId: "active", cadence: .daily, opensWeek: 3), TaskDef(taskId: "lift", cadence: .weekly, opensWeek: 1, weeklyTarget: 3)]
    let start = "2026-11-16"
    func day(_ n: Int) -> String { LocalDate.add(start, days: n - 1) }
    func completeDay(_ e: HabitEngine, _ d: String) { for t in e.dailyDue(e.weekIndex(d)) { try! e.completeTask(t, on: d) } }

    func testDateArithmetic() {
        XCTAssertEqual(LocalDate.add("2026-11-30", days: 1), "2026-12-01")
        XCTAssertEqual(LocalDate.add("2028-02-28", days: 1), "2028-02-29")
        XCTAssertEqual(LocalDate.diff("2027-01-01", "2026-11-16"), 46)
    }

    func testStreakAndRepair() throws {
        let e = HabitEngine(HabitState(planStart: start, tasks: tasks))
        completeDay(e, day(1)); completeDay(e, day(2))
        XCTAssertEqual(e.s.currentDays, 2)
        XCTAssertTrue(e.streakAtRisk(today: day(4)))
        XCTAssertTrue(e.useRepair(today: day(4)))
        completeDay(e, day(4))
        XCTAssertEqual(e.s.currentDays, 3)
        XCTAssertFalse(e.useRepair(today: day(6)))
        completeDay(e, day(6))
        XCTAssertEqual(e.s.currentDays, 1)
    }

    func testBankingNeverUnbanks() throws {
        let e = HabitEngine(HabitState(planStart: start, tasks: tasks))
        for n in 1...5 { completeDay(e, day(n)) }
        XCTAssertTrue(e.isBanked(1))
        e.uncompleteTask("spf", on: day(5))
        XCTAssertTrue(e.isBanked(1))
    }

    func testScanWindows() throws {
        let e = HabitEngine(HabitState(planStart: start, tasks: tasks))
        XCTAssertNil(e.scanWindowOpen(today: day(21)))
        XCTAssertEqual(e.scanWindowOpen(today: day(22)), 4)
        XCTAssertEqual(try e.recordScan(today: day(22), scanId: "a"), 4)
        XCTAssertEqual(e.daysUntilNextScan(today: day(23)), 27)
        XCTAssertEqual(e.scanWindowOpen(today: day(50)), 8)
    }

    func testTaskNotOpenThrows() {
        let e = HabitEngine(HabitState(planStart: start, tasks: tasks))
        XCTAssertThrowsError(try e.completeTask("active", on: day(1)))
    }
}
