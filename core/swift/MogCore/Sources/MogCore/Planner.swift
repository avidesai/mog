import Foundation

// Mirrors mogcore/planner.py.

public enum PlannerConstants {
    public static let planMin = 3
    public static let planMax = 6
    public static let effortPenalty: [String: Double] = ["low": 0.0, "medium": 0.10, "high": 0.20]
    public static let goalWeightByRank: [Double] = [1.0, 0.85, 0.7]
    public static let goalWeightUnpicked = 0.25
}

public struct PlanInput {
    public var goals: [String]
    public var timeBudgetMin: Int
    public var score: ScoreResult
    public init(goals: [String], timeBudgetMin: Int, score: ScoreResult) { self.goals = goals; self.timeBudgetMin = timeBudgetMin; self.score = score }
}

public struct PlanCard {
    public let rule: Rule
    public let findingRefs: [String]
    public let rankScore: Double
    public var ruleId: String { rule.id }
}

public struct PlanTask: Identifiable {
    public let id: String
    public let ruleId: String
    public let title: String
    public let cadence: Cadence
    public let weeklyTarget: Int?
    public let opensWeek: Int
    public let timeCostMin: Int
    public let sortRank: Int
    public let findingRefs: [String]
}

public struct PlanResult {
    public let plan: [PlanCard]
    public let professional: [PlanCard]
    public let info: [PlanCard]
    public let tasks: [PlanTask]
    public let excludedBy: [String: String]
    public let dailyMinutes: Int
}

public enum PlannerError: Error { case unknownGoal(String), tierXReachedRanking }

private func triggerFires(_ t: Trigger, _ metrics: [String: MetricResult], _ reg: Registry) -> Bool {
    guard let m = metrics[t.metric], let v = m.value, m.z != nil else { return false }
    let floor = t.min_confidence ?? reg.metrics[t.metric]!.confidence_floor
    guard let conf = m.confidence, conf >= floor else { return false }
    if let cat = t.category { return m.category?.rawValue == cat }
    let x = t.value!
    switch t.op! {
    case ">": return v > x
    case ">=": return v >= x
    case "<": return v < x
    case "<=": return v <= x
    case "==": return v == x
    case "!=": return v != x
    default: return false
    }
}

private func goalWeight(_ rule: Rule, _ goals: [String]) -> Double {
    var best = 0.0
    for (i, g) in goals.enumerated() where rule.goal_match.contains(g) {
        best = max(best, PlannerConstants.goalWeightByRank[min(i, PlannerConstants.goalWeightByRank.count - 1)])
    }
    if best == 0 && !rule.goal_match.isEmpty { best = PlannerConstants.goalWeightUnpicked }
    return best
}

private func rank(_ rule: Rule, _ gw: Double) -> Double {
    let impact = 1.0 / Double(rule.impact_rank)
    let evidence = rule.evidence_grade == .contradicted ? 0.0 : rule.evidence_grade.cap
    return impact * (0.3 + evidence) * gw * (1.0 - (PlannerConstants.effortPenalty[rule.effort] ?? 0))
}

public func buildPlan(_ inp: PlanInput, _ reg: Registry) throws -> PlanResult {
    let goals = inp.goals.isEmpty ? ["general"] : inp.goals
    for g in goals where reg.goals[g] == nil { throw PlannerError.unknownGoal(g) }
    let metrics = Dictionary(uniqueKeysWithValues: inp.score.metrics.map { ($0.id, $0) })

    var fired: [(Rule, [String])] = []
    for rid in reg.ruleOrder {
        let rule = reg.rules[rid]!
        if rule.safety_tier == .excluded { continue }                       // first check
        if !goals.contains(where: { rule.goal_match.contains($0) }) { continue }
        if rule.alwaysOn && rule.triggers.isEmpty { fired.append((rule, [])); continue }
        if !rule.triggers.isEmpty && rule.triggers.allSatisfy({ triggerFires($0, metrics, reg) }) {
            fired.append((rule, rule.triggers.map(\.metric)))
        }
    }

    var excludedBy: [String: String] = [:]
    let firedIds = Set(fired.map { $0.0.id })
    for (rule, _) in fired {
        for x in rule.excludes where firedIds.contains(x) && excludedBy[x] == nil { excludedBy[x] = rule.id }
    }
    fired = fired.filter { excludedBy[$0.0.id] == nil }

    var cands: [PlanCard] = [], professional: [PlanCard] = [], info: [PlanCard] = []
    for (rule, refs) in fired {
        if rule.safety_tier == .excluded { throw PlannerError.tierXReachedRanking }   // second check
        let card = PlanCard(rule: rule, findingRefs: refs, rankScore: rank(rule, goalWeight(rule, goals)))
        if rule.safety_tier.isProfessional { professional.append(card) }
        else if rule.isInfoCard { info.append(card) }
        else { cands.append(card) }
    }
    let byRank: (PlanCard, PlanCard) -> Bool = { a, b in a.rankScore != b.rankScore ? a.rankScore > b.rankScore : a.ruleId < b.ruleId }
    cands.sort(by: byRank); professional.sort(by: byRank); info.sort(by: byRank)

    var plan: [PlanCard] = []
    var dailyMinutes = 0
    for c in cands {
        let cost = c.rule.cadence == .daily ? c.rule.time_cost_min : 0
        if plan.count >= PlannerConstants.planMax { break }
        if plan.count >= PlannerConstants.planMin && dailyMinutes + cost > inp.timeBudgetMin { continue }
        plan.append(c); dailyMinutes += cost
    }

    var tasks: [PlanTask] = []
    for (i, c) in plan.enumerated() {
        guard let title = c.rule.task_title else { continue }
        tasks.append(PlanTask(id: "task_\(c.rule.id)", ruleId: c.rule.id, title: title, cadence: c.rule.cadence,
                              weeklyTarget: c.rule.weekly_target, opensWeek: c.rule.opens_week,
                              timeCostMin: c.rule.time_cost_min, sortRank: i, findingRefs: c.findingRefs))
    }
    return PlanResult(plan: plan, professional: professional, info: info, tasks: tasks, excludedBy: excludedBy, dailyMinutes: dailyMinutes)
}
