import SwiftUI
import MogCore

/// One measurement: value, reference range on a track, reading, reliability, evidence, and the
/// plain explanation. The capture overlay is a placeholder until overlays are drawn from stored
/// landmark subsets (week 5 decision — see build plan).
struct MetricDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let m: MetricResult

    var body: some View {
        NavigationStack {
            Screen {
                HStack(alignment: .firstTextBaseline) {
                    Text(m.metric.name).style(TypeStyle.title1)
                    Spacer()
                    EvidenceBadge(grade: m.metric.evidence_grade)
                }
                Text(m.metric.plain).style(TypeStyle.body, color: Tokens.Colors.ink700)

                if let v = m.value, m.display != .suppressed {
                    Card {
                        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                            HStack(alignment: .firstTextBaseline) {
                                SectionLabel(text: Copy.s("metric_detail.measured"))
                                Spacer()
                                if m.display == .category {
                                    Text(Copy.s("common.category_\(m.category?.rawValue ?? "typical")")).style(TypeStyle.valueLg)
                                } else {
                                    Text(MetricFormat.value(v, unit: m.metric.unit)).style(TypeStyle.valueLg)
                                }
                            }
                            if m.display != .category {
                                RangeTrack(value: v, low: nil, high: nil, refMean: m.refMean, refSD: m.refSD)
                                Text(Copy.f("common.typical_range", ["sex_plural": "s", "ref_low": MetricFormat.value(m.refMean - m.refSD, unit: m.metric.unit), "ref_high": MetricFormat.value(m.refMean + m.refSD, unit: m.metric.unit)]))
                                    .style(TypeStyle.detail, color: Tokens.Colors.ink500)
                            }
                            Divider().overlay(Tokens.Colors.line200)
                            SectionLabel(text: Copy.s("metric_detail.reading"))
                            Text(reading).style(TypeStyle.body)
                            Divider().overlay(Tokens.Colors.line200)
                            Text(Copy.s("metric_detail.reliability_\(m.metric.reliability_tier.rawValue)")).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                        }
                    }
                } else {
                    Card(ground: Tokens.Colors.raised) {
                        Text(Copy.s("common.suppressed_\(m.suppressedReason ?? "not_measured")")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                    }
                }

                if m.id == "fwhr" { Card(ground: Tokens.Colors.raised) { Text(Copy.s("metric_detail.fwhr_explainer")).style(TypeStyle.body, color: Tokens.Colors.ink700) } }
                if m.metric.evidence_grade == .community { Card(ground: Tokens.Colors.raised) { Text(Copy.s("metric_detail.community_explainer")).style(TypeStyle.body, color: Tokens.Colors.ink700) } }

                SectionLabel(text: Copy.s("metric_detail.reference"))
                Text(m.metric.definition).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                Text("Source: \(m.metric.reference.source)").style(TypeStyle.caption, color: Tokens.Colors.ink500)
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(Copy.s("common.done")) { dismiss() } } }
            .toolbarBackground(Tokens.Colors.paper, for: .navigationBar)
        }
    }

    /// Measurement, reference, plain reading — no judgement adjective (voice.md).
    private var reading: String {
        guard let cat = m.category else { return "" }
        let word = Copy.s("common.category_\(cat.rawValue)")
        return "\(m.metric.short) reads \(word) for the reference range."
    }
}
