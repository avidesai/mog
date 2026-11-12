import SwiftUI
import MogCore

/// Task detail: the rule's copy (headline, body, why this, based on, evidence, effort, timeline)
/// and a single Done control. Nothing can be "added to plan" — the plan is derived from findings.
struct TaskDetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let task: PlanTask
    let onToggle: () -> Void

    var body: some View {
        let rule = app.registry.rules[task.ruleId]
        let done = app.habit?.s.completions[LocalDay.today()]?.contains(task.id) ?? false
        NavigationStack {
            Screen {
                if let rule {
                    HStack(alignment: .firstTextBaseline) {
                        Text(rule.copy.headline).style(TypeStyle.title1)
                        Spacer()
                        EvidenceBadge(grade: rule.evidence_grade)
                    }
                    Text(rule.copy.body).style(TypeStyle.body, color: Tokens.Colors.ink700)
                    Card(ground: Tokens.Colors.accentWash) {
                        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                            SectionLabel(text: Copy.s("task_detail.why_this"))
                            Text(rule.copy.why_this).style(TypeStyle.body)
                            if !task.findingRefs.isEmpty {
                                Text(Copy.s("task_detail.based_on") + ": " + task.findingRefs.compactMap { app.registry.metrics[$0]?.short }.joined(separator: ", "))
                                    .style(TypeStyle.detail, color: Tokens.Colors.accent)
                            }
                        }
                    }
                    HStack(spacing: Tokens.Space.s2) {
                        TierChip(tier: Copy.f("task_detail.how_long", ["low": "\(rule.expected_timeline_weeks[0])", "high": "\(rule.expected_timeline_weeks[1])"]))
                        TierChip(tier: Copy.s("task_detail.effort") + ": " + Copy.s("task_detail.effort_\(rule.effort)"))
                    }
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(Copy.s("common.done")) { dismiss() } } }
            .toolbarBackground(Tokens.Colors.paper, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                footer { Button(done ? Copy.s("task_detail.mark_undone") : Copy.s("task_detail.mark_done")) { onToggle(); dismiss() }.buttonStyle(.chunky(done ? .secondary : .primary)) }
            }
        }
    }
}

/// Day complete: the 600 ms ring, the day number, nothing to tap but Done. No confetti.
struct DayCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    let days: Int
    @State private var drawn = false
    var body: some View {
        VStack(spacing: Tokens.Space.s6) {
            Spacer()
            ZStack {
                Circle().stroke(Tokens.Colors.track, lineWidth: 10).frame(width: 140, height: 140)
                Circle().trim(from: 0, to: drawn ? 1 : 0).stroke(Tokens.Colors.positiveFill, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 140, height: 140)
                Image(systemName: "checkmark").font(.system(size: 44, weight: .bold)).foregroundStyle(Tokens.Colors.positiveFill).opacity(drawn ? 1 : 0)
            }
            Text(Copy.f("today.all_done_title", ["streak": "\(days)"])).style(TypeStyle.displayDay)
            Text(Copy.s("today.all_done_body")).style(TypeStyle.body, color: Tokens.Colors.ink700)
            Spacer()
            Button(Copy.s("common.done")) { dismiss() }.buttonStyle(.chunky).padding(.horizontal, Tokens.Space.s5)
        }
        .padding(.bottom, Tokens.Space.s6)
        .background(Tokens.Colors.paper)
        .onAppear { withAnimation(.easeOut(duration: Tokens.Motion.deliberate)) { drawn = true } }
    }
}

/// Streak save: one repair a month, never sold. Shown only when the engine says the streak is at risk.
struct StreakSaveView: View {
    @Environment(\.dismiss) private var dismiss
    let available: Bool
    let decide: (Bool) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            HStack(spacing: 8) { Image(systemName: "flame.fill").foregroundStyle(Tokens.Colors.flame); Text(Copy.s(available ? "streak.save_title" : "streak.save_unavailable_title")).style(TypeStyle.title2) }
            Text(Copy.s(available ? "streak.save_body" : "streak.save_unavailable_body")).style(TypeStyle.body, color: Tokens.Colors.ink700)
            Spacer()
            if available {
                Button(Copy.s("streak.save_cta")) { decide(true); dismiss() }.buttonStyle(.chunky)
                Button(Copy.s("streak.save_decline")) { decide(false); dismiss() }.buttonStyle(.quiet)
            } else {
                Button(Copy.s("streak.save_unavailable_cta")) { decide(false); dismiss() }.buttonStyle(.chunky(.secondary))
            }
            Text(Copy.s("streak.repair_note")).style(TypeStyle.caption, color: Tokens.Colors.ink500).frame(maxWidth: .infinity)
        }
        .padding(Tokens.Space.s5).background(Tokens.Colors.paper)
        .presentationDetents([.medium])
    }
}
