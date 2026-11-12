import Foundation
import MogCore

/// Ten frames → one set of `MetricReading`s. Metrics are computed per frame by the geometry
/// layer, then the cross-frame median is the value and the interquartile range feeds the
/// confidence band (eng doc, "Capture and quality gates": median of 10, IQR → band).
enum FrameAggregator {
    struct PerFrame { let metrics: [String: Double]; let confidences: [String: Double] }

    static func aggregate(_ frames: [PerFrame]) -> [String: MetricReading] {
        guard !frames.isEmpty else { return [:] }
        let ids = Set(frames.flatMap { $0.metrics.keys })
        var out: [String: MetricReading] = [:]
        for id in ids.sorted() {
            let vals = frames.compactMap { $0.metrics[id] }.sorted()
            guard vals.count >= max(3, frames.count / 2) else { continue }   // a metric must be present on most frames
            let med = median(vals)
            let iqr = quantile(vals, 0.75) - quantile(vals, 0.25)
            let conf = frames.compactMap { $0.confidences[id] }.reduce(0, +) / Double(max(1, frames.count))
            out[id] = MetricReading(value: med, confidence: conf, iqr: iqr)
        }
        return out
    }

    static func median(_ sorted: [Double]) -> Double {
        let n = sorted.count
        return n % 2 == 1 ? sorted[n / 2] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2
    }

    /// Linear-interpolated quantile on a sorted array (matches numpy's default).
    static func quantile(_ sorted: [Double], _ q: Double) -> Double {
        let pos = q * Double(sorted.count - 1)
        let lo = Int(pos.rounded(.down)), hi = min(sorted.count - 1, lo + 1)
        return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - Double(lo))
    }
}
