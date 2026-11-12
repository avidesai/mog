import SwiftUI
import MogCore

/// Results overview. Free users see the real score + their strongest and most improvable
/// measurement; the rest of the rows show "measured, locked". Pro sees everything.
struct ResultsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let result: ScoreResult
    @State private var selected: MetricResult?
    @State private var showPaywall = false

    private var groups: [(String, [String])] {
        [(Copy.s("results.group_eyes"), ["canthal_tilt_deg", "intercanthal_to_width_ratio", "eye_aspect_ratio", "eye_width_to_intercanthal", "brow_to_eye_distance_ratio"]),
         (Copy.s("results.group_midface"), ["midface_ratio", "nasal_width_to_intercanthal", "nose_length_to_face_height", "philtrum_length_ratio"]),
         (Copy.s("results.group_lower"), ["mouth_width_to_nose", "mouth_width_to_interpupillary", "lip_ratio_upper_lower", "lower_third_split", "bigonial_to_bizygomatic", "chin_width_to_mouth"]),
         (Copy.s("results.group_proportion"), ["facial_thirds_upper", "facial_thirds_middle", "facial_thirds_lower", "face_height_to_width", "bitemporal_to_bizygomatic", "symmetry_index", "fwhr"]),
         (Copy.s("results.group_profile"), ["nasofrontal_angle_deg", "nasolabial_angle_deg", "nasal_tip_projection_goode", "facial_convexity_deg", "mentolabial_angle_deg", "cervicomental_angle_deg", "chin_projection_eline_mm", "gonial_angle_deg", "ramus_to_mandible_ratio", "forehead_slope_deg"]),
         (Copy.s("results.group_appearance"), ["skin_evenness", "facial_adiposity", "hairline_stage", "beard_presence"])]
    }

    var body: some View {
        NavigationStack {
            Screen {
                ScoreBand(result: result, display: TypeStyle.displayDay).frame(maxWidth: .infinity)

                if let s = result.topStrength, let m = metric(s) {
                    SectionLabel(text: Copy.s("results.section_strength"))
                    MetricRow(m: m, locked: false) { open(m) }
                }
                if let s = result.mostImprovable, let m = metric(s) {
                    SectionLabel(text: Copy.s("results.section_improvable"))
                    MetricRow(m: m, locked: false) { open(m) }
                }

                SectionLabel(text: Copy.s("results.section_groups"))
                ForEach(groups, id: \.0) { title, ids in
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        Text(title).style(TypeStyle.title3)
                        ForEach(ids, id: \.self) { id in
                            if let m = metric(id) {
                                let free = id == result.topStrength || id == result.mostImprovable
                                MetricRow(m: m, locked: !(app.isPro || free)) { if app.isPro || free { open(m) } else { showPaywall = true } }
                            }
                        }
                    }
                }
                if !app.isPro { Text(Copy.s("results.free_locked_note")).style(TypeStyle.detail, color: Tokens.Colors.ink500) }
                Button(Copy.s("results.see_plan")) { dismiss() }.buttonStyle(.chunky).padding(.top, Tokens.Space.s2)
            }
            .navigationTitle(Copy.s("results.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(Copy.s("common.done")) { dismiss() } } }
            .toolbarBackground(Tokens.Colors.paper, for: .navigationBar)
        }
        .onAppear { app.analytics.track(.resultsOpened); Store.counters().resultsOpens += 1 }
        .sheet(item: $selected) { m in MetricDetailView(m: m) }
        .sheet(isPresented: $showPaywall) { PaywallView(placement: "results_locked_row") }
    }

    private func metric(_ id: String) -> MetricResult? { result.metrics.first { $0.id == id } }
    private func open(_ m: MetricResult) { app.analytics.track(.metricOpened(metric: m.id)); selected = m }
}

extension MetricResult: Identifiable {}

struct MetricRow: View {
    let m: MetricResult
    let locked: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.metric.short).style(TypeStyle.rowTitle)
                    if m.display == .suppressed {
                        Text(suppressedShort).style(TypeStyle.detail, color: Tokens.Colors.caution).lineLimit(1)
                    } else if locked {
                        Text(Copy.f("common.measured_locked", ["metric": m.metric.short])).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                    } else {
                        Text(valueText).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                    }
                }
                Spacer()
                if locked && m.display != .suppressed {
                    Image(systemName: "lock").font(.system(size: 13, weight: .semibold)).foregroundStyle(Tokens.Colors.ink300)
                } else if m.display != .suppressed {
                    EvidenceBadge(grade: m.metric.evidence_grade)
                }
            }
            .padding(Tokens.Space.s4)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous).fill(locked ? Tokens.Colors.raised : Tokens.Colors.surface50)
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous).strokeBorder(Tokens.Colors.line200, lineWidth: Tokens.Border.hairline)))
        }.buttonStyle(.plain)
    }
    /// First clause of the suppression copy ("Not measured on this capture").
    private var suppressedShort: String {
        let full = Copy.s("common.suppressed_\(m.suppressedReason ?? "not_measured")")
        return full.components(separatedBy: CharacterSet(charactersIn: "—.")).first?.trimmingCharacters(in: .whitespaces) ?? full
    }
    private var valueText: String {
        guard let v = m.value else { return "" }
        switch m.display {
        case .category: return Copy.s("common.category_\(m.category?.rawValue ?? "typical")")
        default: return MetricFormat.value(v, unit: m.metric.unit) + " · " + Copy.s("common.category_\(m.category?.rawValue ?? "typical")")
        }
    }
}

enum MetricFormat {
    static func value(_ v: Double, unit: String) -> String {
        switch unit {
        case "deg": return String(format: "%.0f°", v)
        case "mm": return String(format: "%+.1f mm", v)
        case "index": return String(format: "%.2f", v)
        case "category": return String(format: "%.0f", v)
        default: return String(format: "%.3g", v)
        }
    }
}
