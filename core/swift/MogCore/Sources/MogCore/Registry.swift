import Foundation

// Mirrors mogcore/registry.py. Loads and validates metrics.json, rules.json,
// references.json, denylist.json. Throws on any inconsistency.

public enum EvidenceGrade: String, Codable, CaseIterable {
    case strong, moderate, weak, community, contradicted
    public var cap: Double {
        switch self {
        case .strong: return 1.0
        case .moderate: return 0.6
        case .weak: return 0.1
        case .community: return 0.02
        case .contradicted: return 0.0
        }
    }
}

public enum ReliabilityTier: String, Codable { case A, B, C, D
    public var nominalWeight: Double { switch self { case .A: return 1.0; case .B: return 0.6; case .C, .D: return 0.0 } }
}

public enum Direction: String, Codable { case toward_mean, higher_better, lower_better, none }
public enum Pose: String, Codable { case frontal, profile }
public enum Sex: String, Codable { case male, female }
public enum Cadence: String, Codable { case daily, weekly, once }

/// Safety tier: 1–4 or X. Encoded in JSON as a number or the string "X".
public enum SafetyTier: Equatable, Codable {
    case tier(Int), excluded
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let n = try? c.decode(Int.self) { self = .tier(n); return }
        let s = try c.decode(String.self)
        guard s == "X" else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "bad safety tier \(s)") }
        self = .excluded
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .tier(let n): try c.encode(n); case .excluded: try c.encode("X") }
    }
    public var isPlanEligible: Bool { self == .tier(1) || self == .tier(2) }
    public var isProfessional: Bool { self == .tier(3) || self == .tier(4) }
}

public struct ReferenceNorm: Codable { public let mean: Double; public let sd: Double }

public struct Metric: Codable, Identifiable {
    public struct Reference: Codable {
        public let male: ReferenceNorm
        public let female: ReferenceNorm
        public let pooled: Bool
        public let source: String
    }
    public let id: String
    public let name: String
    public let short: String
    public let unit: String
    public let pose: Pose
    public let inputs: [String]
    public let definition: String
    public let reference: Reference
    public let direction: Direction
    public let evidence_grade: EvidenceGrade
    public let reliability_tier: ReliabilityTier
    public let confidence_floor: Double
    public let community_name: String?
    public let plain: String
    public let note: String?
    public let modifiable: Bool?
    public let noise_sd: Double?

    public var isModifiable: Bool { modifiable ?? false }
    public var weightCap: Double { evidence_grade.cap }
    /// Tier gate only (A/B eligible); magnitude comes from reliability(_:).
    public var nominalWeight: Double { reliability_tier.nominalWeight > 0 ? 1.0 : 0.0 }
    /// Attenuation r = 1 / (1 + (noise_sd / pop_sd)^2). Mirrors Metric.reliability in registry.py.
    public func reliability(_ sex: Sex) -> Double {
        let n = noise_sd ?? 0
        if n <= 0 { return 1.0 }
        let sd = ref(sex).sd
        return 1.0 / (1.0 + (n / sd) * (n / sd))
    }
    public func weightFor(_ sex: Sex) -> Double { weight * reliability(sex) }
    public var scorable: Bool { direction != .none && weightCap > 0 && nominalWeight > 0 && unit != "category" }
    public var weight: Double { scorable ? nominalWeight * weightCap : 0.0 }
    public func ref(_ sex: Sex) -> ReferenceNorm { sex == .male ? reference.male : reference.female }
}

public struct Trigger: Codable {
    public let metric: String
    public let op: String?
    public let value: Double?
    public let category: String?
    public let min_confidence: Double?
}

public struct RuleCopy: Codable { public let headline: String; public let body: String; public let why_this: String }

public struct Rule: Codable, Identifiable {
    public let id: String
    public let version: Int
    public let triggers: [Trigger]
    public let goal_match: [String]
    public let safety_tier: SafetyTier
    public let evidence_grade: EvidenceGrade
    public let expected_timeline_weeks: [Int]
    public let effort: String
    public let impact_rank: Int
    public let evidence_refs: [String]
    public let overlay: String?
    public let excludes: [String]
    public let cadence: Cadence
    public let weekly_target: Int?
    public let time_cost_min: Int
    public let opens_week: Int
    public let task_title: String?
    public let copy: RuleCopy
    public let always_on: Bool?
    public let is_info_card: Bool?

    public var alwaysOn: Bool { always_on ?? false }
    public var isInfoCard: Bool { is_info_card ?? false }
}

public struct Goal: Codable { public let id: String; public let label: String }

struct MetricsFile: Codable { let metrics: [Metric] }
struct RulesFile: Codable { let goals: [Goal]; let rules: [Rule] }
struct ReferencesFile: Codable { let refs: [String: Reference]
    struct Reference: Codable { let kind: String; let cite: String; let verify: Bool? }
}

public enum RegistryError: Error, CustomStringConvertible {
    case validation([String])
    case missingResource(String)
    public var description: String {
        switch self {
        case .validation(let e): return "Registry validation failed:\n  " + e.joined(separator: "\n  ")
        case .missingResource(let n): return "missing resource \(n)"
        }
    }
}

public final class Registry {
    public let metrics: [String: Metric]
    public let metricOrder: [String]
    public let rules: [String: Rule]
    public let ruleOrder: [String]
    public let goals: [String: String]
    public let referenceKinds: [String: String]
    public let denylist: Denylist
    public let compositeReference: CompositeReference

    public static func load(bundle: Bundle = .module) throws -> Registry {
        func data(_ name: String) throws -> Data {
            guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Resources")
                    ?? bundle.url(forResource: name, withExtension: "json") else { throw RegistryError.missingResource(name) }
            return try Data(contentsOf: url)
        }
        let dec = JSONDecoder()
        let m = try dec.decode(MetricsFile.self, from: data("metrics"))
        let r = try dec.decode(RulesFile.self, from: data("rules"))
        let refs = try dec.decode(ReferencesFile.self, from: data("references"))
        let deny = try Denylist(data: data("denylist"))
        let comp = try dec.decode(CompositeReference.self, from: data("composite_reference"))
        return try Registry(metrics: m.metrics, rules: r.rules, goals: r.goals, refs: refs, denylist: deny, composite: comp)
    }

    init(metrics: [Metric], rules: [Rule], goals: [Goal], refs: ReferencesFile, denylist: Denylist, composite: CompositeReference) throws {
        self.metricOrder = metrics.map(\.id)
        self.metrics = Dictionary(uniqueKeysWithValues: metrics.map { ($0.id, $0) })
        self.ruleOrder = rules.map(\.id)
        self.rules = Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0) })
        self.goals = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0.label) })
        self.referenceKinds = refs.refs.mapValues(\.kind)
        self.denylist = denylist
        self.compositeReference = composite
        let errors = validate()
        if !errors.isEmpty { throw RegistryError.validation(errors) }
    }

    func validate() -> [String] {
        var e: [String] = []
        for m in metrics.values {
            if m.reference.male.sd <= 0 || m.reference.female.sd <= 0 { e.append("\(m.id): non-positive sd") }
            if m.reference.source != "n/a" && referenceKinds[m.reference.source] == nil { e.append("\(m.id): unknown source \(m.reference.source)") }
            if m.evidence_grade == .community, let k = referenceKinds[m.reference.source], k != "community" { e.append("\(m.id): community grade must cite a community source") }
        }
        for r in rules.values {
            for t in r.triggers {
                if metrics[t.metric] == nil { e.append("\(r.id): unknown metric \(t.metric)") }
                if (t.op == nil) == (t.category == nil) { e.append("\(r.id): trigger needs exactly one of op/category") }
            }
            for g in r.goal_match where goals[g] == nil { e.append("\(r.id): unknown goal \(g)") }
            for x in r.excludes where rules[x] == nil { e.append("\(r.id): excludes unknown rule \(x)") }
            for ref in r.evidence_refs where referenceKinds[ref] == nil { e.append("\(r.id): unknown evidence ref \(ref)") }
            if r.safety_tier == .excluded && !r.goal_match.isEmpty { e.append("\(r.id): tier X must have no goals") }
            if r.safety_tier.isPlanEligible && r.cadence == .daily && r.task_title == nil && !r.isInfoCard { e.append("\(r.id): daily plan rule needs task_title") }
            if r.cadence == .weekly && (r.weekly_target ?? 0) == 0 { e.append("\(r.id): weekly rule needs weekly_target") }
            if r.triggers.isEmpty && !r.alwaysOn { e.append("\(r.id): no triggers must be always_on") }
            if r.safety_tier.isProfessional && r.task_title != nil { e.append("\(r.id): tier 3/4 never become tasks") }
            if r.expected_timeline_weeks.count != 2 { e.append("\(r.id): timeline needs two values") }
        }
        return e
    }
}

public struct CompositeReference: Codable {
    public struct Moment: Codable { public let mean: Double; public let sd: Double }
    public let n: Int
    public let seed: Int
    public let q_moments: [String: [String: Moment]]      // sex → metric → moment
    public let quantiles_std: [String: [Double]]           // sex → 1001 quantiles
    public let scorable_metrics: [String]
}
