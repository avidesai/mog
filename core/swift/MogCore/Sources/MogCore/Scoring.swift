import Foundation

// Mirrors mogcore/scoring.py exactly. Metrics are iterated in registry order;
// no reductions happen in any other order, so results are bit-identical to Python
// for the same inputs (both are IEEE-754 double).

public enum ScoringConstants {
    public static let qClamp = 3.0
    public static let flatBelowSD = 1.0
    public static let modelSigmaStd = 0.10
    public static let bandK = 1.0
    public static let minBandHalfPts = 0.15
    public static let iqrToSD = 1.349
    public static let beardConfidenceFactor = 0.8
    public static let beardAffected: Set<String> = [
        "bigonial_to_bizygomatic", "chin_width_to_mouth", "gonial_angle_deg", "ramus_to_mandible_ratio",
        "cervicomental_angle_deg", "chin_projection_eline_mm", "mentolabial_angle_deg",
    ]
    public static let modelVersion = "rules-1.0.0"
    /// (upper percentile bound, short, long). Nothing below LTN by design.
    public static let tiers: [(Double, String, String)] = [
        (45.0, "LTN", "Low-tier normie"), (65.0, "MTN", "Mid-tier normie"), (85.0, "HTN", "High-tier normie"),
        (97.0, "Chadlite", "Chadlite"), (100.1, "Chad", "Chad"),
    ]
}

public func tierForPercentile(_ p: Double) -> (short: String, long: String) {
    for (upper, s, l) in ScoringConstants.tiers where p < upper { return (s, l) }
    let last = ScoringConstants.tiers.last!
    return (last.1, last.2)
}

public struct MetricReading: Codable, Equatable {
    public var value: Double
    public var confidence: Double
    public var iqr: Double
    public var occluded: Bool
    public init(value: Double, confidence: Double, iqr: Double = 0, occluded: Bool = false) {
        self.value = value; self.confidence = confidence; self.iqr = iqr; self.occluded = occluded
    }
    enum CodingKeys: String, CodingKey { case value, confidence, iqr, occluded }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        value = try c.decode(Double.self, forKey: .value)
        confidence = try c.decode(Double.self, forKey: .confidence)
        iqr = try c.decodeIfPresent(Double.self, forKey: .iqr) ?? 0
        occluded = try c.decodeIfPresent(Bool.self, forKey: .occluded) ?? false
    }
}

public struct ScoreInput {
    public var sex: Sex
    public var ageBand: String
    public var readings: [String: MetricReading]
    public var profileCaptured: Bool
    public init(sex: Sex, ageBand: String, readings: [String: MetricReading], profileCaptured: Bool = true) {
        self.sex = sex; self.ageBand = ageBand; self.readings = readings; self.profileCaptured = profileCaptured
    }
}

public enum DisplayMode: String { case point, band, category, suppressed }
public enum ZCategory: String { case low, typical, high }

public struct MetricResult {
    public let id: String
    public let value: Double?
    public let z: Double?
    public let category: ZCategory?
    public let quality: Double?
    public let weight: Double
    public let display: DisplayMode
    public let suppressedReason: String?
    public let confidence: Double?
    public let refMean: Double
    public let refSD: Double
    public let metric: Metric
}

public struct ScoreResult {
    public let modelVersion: String
    public let percentile: Double
    public let score: Double
    public let scoreLow: Double
    public let scoreHigh: Double
    public let tier: String
    public let tierLong: String
    public let composite: Double
    public let compositeStd: Double
    public let sigmaCaptureStd: Double
    public let sigmaTotalStd: Double
    public let metrics: [MetricResult]
    public let topStrength: String?
    public let mostImprovable: String?
    public let nScored: Int
}

public enum ScoringError: Error { case noScorableMetrics }

public func qualityFromZ(_ z: Double, _ d: Direction) -> Double {
    var q: Double
    switch d {
    case .toward_mean: q = -abs(z)
    case .higher_better: q = z
    case .lower_better: q = min(-z, ScoringConstants.flatBelowSD)
    case .none: preconditionFailure("direction none is not scorable")
    }
    return max(-ScoringConstants.qClamp, min(ScoringConstants.qClamp, q))
}

public func qualitySlope(_ z: Double, _ d: Direction) -> Double {
    if abs(z) >= ScoringConstants.qClamp { return 0 }
    if d == .lower_better && -z >= ScoringConstants.flatBelowSD { return 0 }
    return 1
}

public func categoryFromZ(_ z: Double) -> ZCategory { z < -1 ? .low : (z > 1 ? .high : .typical) }

/// Linear interpolation into a sorted 1001-entry table (table[i] = i/10-th percentile).
public func percentileFromStd(_ s: Double, _ table: [Double]) -> Double {
    let n = table.count - 1
    if s <= table[0] { return 0 }
    if s >= table[n] { return 100 }
    var lo = 0, hi = n
    while hi - lo > 1 {
        let mid = (lo + hi) / 2
        if table[mid] <= s { lo = mid } else { hi = mid }
    }
    let a = table[lo], b = table[hi]
    let frac = b == a ? 0.0 : (s - a) / (b - a)
    return (Double(lo) + frac) * (100.0 / Double(n))
}

public func score(_ inp: ScoreInput, _ reg: Registry) throws -> ScoreResult {
    let ref = reg.compositeReference
    let table = ref.quantiles_std[inp.sex.rawValue]!
    let moments = ref.q_moments[inp.sex.rawValue]!
    let beardPresent = (inp.readings["beard_presence"]?.value ?? 0) >= 1

    var results: [MetricResult] = []
    var sumW = 0.0, sumWQ = 0.0, sumWMu = 0.0, varRef = 0.0, varCap = 0.0

    for mid in reg.metricOrder {
        let m = reg.metrics[mid]!
        let norm = m.ref(inp.sex)
        func suppressed(_ reason: String, conf: Double?) -> MetricResult {
            MetricResult(id: mid, value: nil, z: nil, category: nil, quality: nil, weight: 0, display: .suppressed,
                         suppressedReason: reason, confidence: conf, refMean: norm.mean, refSD: norm.sd, metric: m)
        }
        guard let r = inp.readings[mid] else {
            results.append(suppressed(m.pose == .profile && !inp.profileCaptured ? "pose_missing" : "not_measured", conf: nil))
            continue
        }
        var conf = r.confidence
        if beardPresent && ScoringConstants.beardAffected.contains(mid) { conf *= ScoringConstants.beardConfidenceFactor }
        if r.occluded { results.append(suppressed("occluded", conf: conf)); continue }
        if conf < m.confidence_floor { results.append(suppressed("low_confidence", conf: conf)); continue }
        if m.reliability_tier == .D { results.append(suppressed("not_shipped", conf: conf)); continue }

        let z = (r.value - norm.mean) / norm.sd
        let cat = categoryFromZ(z)
        let display: DisplayMode = { switch m.reliability_tier { case .A: return .point; case .B: return .band; case .C: return .category; case .D: return .suppressed } }()
        var q: Double? = nil
        var w = 0.0
        if m.scorable {
            let qq = qualityFromZ(z, m.direction)
            q = qq
            w = m.weight
            let mo = moments[mid]!
            sumW += w
            sumWQ += w * qq
            sumWMu += w * mo.mean
            varRef += (w * mo.sd) * (w * mo.sd)
            let zSD = r.iqr > 0 ? (r.iqr / ScoringConstants.iqrToSD) / norm.sd : 0.0
            let t = w * zSD * qualitySlope(z, m.direction)
            varCap += t * t
        }
        results.append(MetricResult(id: mid, value: r.value, z: z, category: cat, quality: q, weight: w, display: display,
                                    suppressedReason: nil, confidence: conf, refMean: norm.mean, refSD: norm.sd, metric: m))
    }

    guard sumW > 0 else { throw ScoringError.noScorableMetrics }

    let composite = sumWQ / sumW
    let refMean = sumWMu / sumW
    let refSD = varRef.squareRoot() / sumW
    let compositeStd = (composite - refMean) / refSD
    let sigmaCapture = (varCap.squareRoot() / sumW) / refSD
    let sigmaTotal = (sigmaCapture * sigmaCapture + ScoringConstants.modelSigmaStd * ScoringConstants.modelSigmaStd).squareRoot()

    let pct = percentileFromStd(compositeStd, table)
    var pctLo = percentileFromStd(compositeStd - ScoringConstants.bandK * sigmaTotal, table)
    var pctHi = percentileFromStd(compositeStd + ScoringConstants.bandK * sigmaTotal, table)
    pctLo = min(pctLo, pct - ScoringConstants.minBandHalfPts * 10)
    pctHi = max(pctHi, pct + ScoringConstants.minBandHalfPts * 10)
    pctLo = max(0, pctLo); pctHi = min(100, pctHi)
    let (tier, tierLong) = tierForPercentile(pct)

    let scored = results.filter { $0.quality != nil && $0.weight > 0 }
    // ties broken by id, as in Python's (key, id) tuple sort
    let topStrength = scored.max { a, b in
        let ka = a.quality! * a.weight, kb = b.quality! * b.weight
        return ka != kb ? ka < kb : a.id < b.id
    }?.id
    let pool = scored.filter { $0.metric.isModifiable && $0.quality! < 0 }
    let mostImprovable = pool.min { a, b in a.quality! != b.quality! ? a.quality! < b.quality! : a.id < b.id }?.id

    return ScoreResult(modelVersion: ScoringConstants.modelVersion, percentile: pct, score: pct / 10, scoreLow: pctLo / 10,
                       scoreHigh: pctHi / 10, tier: tier, tierLong: tierLong, composite: composite, compositeStd: compositeStd,
                       sigmaCaptureStd: sigmaCapture, sigmaTotalStd: sigmaTotal, metrics: results, topStrength: topStrength,
                       mostImprovable: mostImprovable, nScored: scored.count)
}
