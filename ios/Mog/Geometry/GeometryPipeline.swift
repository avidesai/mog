import Foundation
import MogCore

/// Frames → readings. The whole on-device measurement path in one place so the privacy audit
/// has one function to read: nothing here writes to disk or touches the network.
enum GeometryPipeline {
    static let landmarker = Landmarker()

    static func readings(from frames: [FaceFrame], beardPresence: Int, hairlineStage: Int) -> [String: MetricReading] {
        let perFrame: [FrameAggregator.PerFrame] = frames.map { f in
            let pts = landmarker.points(from: f.vertices)
            var pf = MetricFunctions.compute(pts)
            var m = pf.metrics, c = pf.confidences
            // Appearance heads, cheap path (core/appearance): geometric adiposity proxy + skin evenness from the frame.
            if let ad = AdiposityProxy.compute(pts, mesh: f.vertices) {
                m["facial_adiposity"] = ad.index; c["facial_adiposity"] = 0.75 * (Double(ad.terms.count) / 3.0 + 0.34)   // more terms → more confidence, capped ≈1
            }
            if let s = f.skin, s.evenness.isFinite {
                m["skin_evenness"] = s.evenness; c["skin_evenness"] = s.nPixels >= 600 ? 0.8 : 0.7
            }
            pf = FrameAggregator.PerFrame(metrics: m, confidences: c.mapValues { min(1, $0) })
            return pf
        }
        var out = FrameAggregator.aggregate(perFrame)
        // Hairline and beard come from onboarding toggles in the interim (metrics.json: category metrics).
        out["beard_presence"] = MetricReading(value: Double(beardPresence), confidence: 0.9, iqr: 0)
        out["hairline_stage"] = MetricReading(value: Double(hairlineStage), confidence: 0.7, iqr: 0)
        return out
    }
}
