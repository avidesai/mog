import Foundation
import MogCore

/// Frames → readings. The whole on-device measurement path in one place so the privacy audit
/// has one function to read: nothing here writes to disk or touches the network.
enum GeometryPipeline {
    static let landmarker = Landmarker()

    static func readings(from frames: [FaceFrame], beardPresence: Int, hairlineStage: Int) -> [String: MetricReading] {
        let perFrame = frames.map { MetricFunctions.compute(landmarker.points(from: $0.vertices)) }
        var out = FrameAggregator.aggregate(perFrame)
        // Appearance heads (skin evenness, adiposity) are not implemented yet — spike 5 decides the
        // cheap path. Until then they are absent and the scorer suppresses them as not_measured.
        // Hairline and beard come from onboarding toggles in the interim (metrics.json: category metrics).
        out["beard_presence"] = MetricReading(value: Double(beardPresence), confidence: 0.9, iqr: 0)
        out["hairline_stage"] = MetricReading(value: Double(hairlineStage), confidence: 0.7, iqr: 0)
        return out
    }
}
