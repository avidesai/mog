import SwiftUI
import MogCore

/// The plan as ranked cards; info cards; the professional section with its fixed footer.
struct PlanView: View {
    @Environment(AppModel.self) private var app
    @State private var selected: PlanCard?

    var body: some View {
        NavigationStack {
            Screen {
                if let plan = app.latestPlan, let habit = app.habit {
                    Text(Copy.s("plan.intro")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                    let week = habit.weekIndex(LocalDay.today())
                    let now = plan.plan.filter { $0.rule.opens_week <= week }
                    let later = plan.plan.filter { $0.rule.opens_week > week }
                    Text(Copy.f("plan.daily_minutes", ["minutes": "\(plan.dailyMinutes)"])).style(TypeStyle.detail, color: Tokens.Colors.ink500)

                    SectionLabel(text: Copy.s("plan.section_now"))
                    ForEach(Array(now.enumerated()), id: \.element.ruleId) { i, c in PlanCardView(index: i + 1, card: c) { selected = c } }

                    if !later.isEmpty {
                        SectionLabel(text: Copy.s("plan.section_opens_later"))
                        ForEach(later, id: \.ruleId) { c in PlanCardView(index: nil, card: c, locked: true, lockedLabel: Copy.f("task_detail.opens_later", ["week": "\(c.rule.opens_week)"])) { selected = c } }
                    }
                    if !plan.info.isEmpty {
                        SectionLabel(text: Copy.s("plan.section_info"))
                        ForEach(plan.info, id: \.ruleId) { c in PlanCardView(index: nil, card: c) { selected = c } }
                    }
                    if !plan.professional.isEmpty {
                        SectionLabel(text: Copy.s("plan.section_professional"))
                        ForEach(plan.professional, id: \.ruleId) { c in
                            PlanCardView(index: nil, card: c, dashed: true) { selected = c }
                        }
                        Text(Copy.s("plan.professional_footer")).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                    }
                    Text(Copy.s("plan.regenerated_note")).style(TypeStyle.caption, color: Tokens.Colors.ink500)
                } else {
                    Card(ground: Tokens.Colors.raised) { Text(Copy.s("today.empty_title")).style(TypeStyle.body, color: Tokens.Colors.ink700) }
                }
            }
            .navigationTitle(Copy.s("plan.title")).navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Tokens.Colors.paper, for: .navigationBar)
        }
        .sheet(item: $selected) { c in PlanCardDetail(card: c) }
    }
}

extension PlanCard: Identifiable { public var id: String { ruleId } }

struct PlanCardView: View {
    @Environment(AppModel.self) private var app
    let index: Int?
    let card: PlanCard
    var locked = false
    var lockedLabel: String? = nil
    var dashed = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Card(ground: locked ? Tokens.Colors.raised : Tokens.Colors.surface50) {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    HStack(alignment: .top) {
                        if let index { Text("\(index)").style(TypeStyle.valueLg, color: Tokens.Colors.ink300) }
                        Spacer()
                        EvidenceBadge(grade: card.rule.evidence_grade)
                    }
                    Text(card.rule.copy.headline).style(TypeStyle.title3)
                    Text(card.rule.copy.body).style(TypeStyle.bodySm, color: Tokens.Colors.ink700).lineLimit(3)
                    if !card.findingRefs.isEmpty {
                        Text(Copy.s("task_detail.based_on") + ": " + card.findingRefs.compactMap { app.registry.metrics[$0]?.short }.joined(separator: ", "))
                            .style(TypeStyle.detail, color: Tokens.Colors.accent)
                    }
                    if let lockedLabel { Text(lockedLabel).style(TypeStyle.detail, color: Tokens.Colors.ink500) }
                }
            }
            .overlay(alignment: .leading) {
                if dashed { RoundedRectangle(cornerRadius: 2).strokeBorder(Tokens.Colors.line200, style: StrokeStyle(lineWidth: 3, dash: [4, 4])).frame(width: 3).padding(.vertical, 12) }
            }
        }.buttonStyle(.plain)
    }
}

struct PlanCardDetail: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let card: PlanCard
    var body: some View {
        NavigationStack {
            Screen {
                HStack(alignment: .firstTextBaseline) { Text(card.rule.copy.headline).style(TypeStyle.title1); Spacer(); EvidenceBadge(grade: card.rule.evidence_grade) }
                Text(card.rule.copy.body).style(TypeStyle.body, color: Tokens.Colors.ink700)
                Card(ground: Tokens.Colors.accentWash) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                        SectionLabel(text: Copy.s("task_detail.why_this"))
                        Text(card.rule.copy.why_this).style(TypeStyle.body)
                    }
                }
                if card.rule.safety_tier.isProfessional {
                    Text(Copy.s("plan.professional_footer")).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                }
                if !card.rule.evidence_refs.isEmpty {
                    SectionLabel(text: Copy.s("settings.citations"))
                    ForEach(card.rule.evidence_refs, id: \.self) { Text($0).style(TypeStyle.caption, color: Tokens.Colors.ink500) }
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(Copy.s("common.done")) { dismiss() } } }
            .toolbarBackground(Tokens.Colors.paper, for: .navigationBar)
        }
    }
}
