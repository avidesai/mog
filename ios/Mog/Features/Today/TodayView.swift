import SwiftUI
import MogCore

/// Home. Four states: empty (no scan yet), normal day, scan day, all done. Plus the distress
/// card and the streak-save sheet, which are triggered by the habit engine, never by the UI.
struct TodayView: View {
    @Environment(AppModel.self) private var app
    @State private var showCapture = false
    @State private var openTask: PlanTask?
    @State private var showDayComplete = false
    @State private var showStreakSave = false
    @State private var showDistress = false
    @State private var tick = 0   // bump to re-render after engine mutations

    private var today: String { LocalDay.today() }

    var body: some View {
        NavigationStack {
            Group {
                if let habit = app.habit, let plan = app.latestPlan { dayBody(habit, plan) } else { emptyBody }
            }
            .navigationTitle(Copy.s("today.title")).navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Tokens.Colors.paper, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showCapture) { CaptureView() }
        .sheet(item: $openTask) { t in TaskDetailView(task: t) { toggle(t) } }
        .sheet(isPresented: $showDayComplete) { DayCompleteView(days: app.habit?.s.currentDays ?? 0) }
        .sheet(isPresented: $showStreakSave) { StreakSaveView(available: app.habit?.repairAvailable(today: today) ?? false) { useRepair in
            if useRepair, let h = app.habit, h.useRepair(today: today) { Store.save(habit: h.s); app.analytics.track(.repairUsed) }
            tick += 1
        } }
        .onAppear { checkTriggers() }
    }

    // MARK: states

    private var emptyBody: some View {
        Screen {
            Card(padding: Tokens.Space.s5, ground: Tokens.Colors.raised, radius: Tokens.Radius.xl) {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    Text(Copy.s("today.empty_title")).style(TypeStyle.title2)
                    Text(app.profile.consentGranted ? Copy.s("today.empty_body") : Copy.s("consent.decline_body")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                    if app.profile.consentGranted && !app.profile.measurementBlockedByState {
                        Button(Copy.s("today.empty_cta")) { showCapture = true }.buttonStyle(.chunky)
                    } else if app.profile.measurementBlockedByState {
                        Text(Copy.s("consent.state_block_body")).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                    }
                }
            }
        }
    }

    private func dayBody(_ habit: HabitEngine, _ plan: PlanResult) -> some View {
        let _ = tick
        let status = habit.dayStatus(today)
        let week = habit.weekIndex(today)
        let open = plan.tasks.filter { $0.opensWeek <= week }
        return Screen {
            HStack {
                Text(Copy.f("today.greeting_week", ["week": "\(max(1, week))"])).style(TypeStyle.title3, color: Tokens.Colors.ink700)
                Spacer()
                StreakPill(days: habit.s.currentDays)
            }

            if showDistress { DistressCard { showDistress = false } }

            if let scanWeek = habit.scanWindowOpen(today: today) {
                Card(padding: Tokens.Space.s5, ground: Tokens.Colors.surface50, radius: Tokens.Radius.xl) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        Text(Copy.f("today.scan_open_title", ["week": "\(scanWeek)"])).style(TypeStyle.title2)
                        Text(Copy.s("today.scan_open_body")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                        Button(Copy.s("today.scan_open_cta")) { showCapture = true }.buttonStyle(.chunky)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous).strokeBorder(Tokens.Colors.accent, lineWidth: Tokens.Border.emphasis))
            }

            if status.complete {
                Card(padding: Tokens.Space.s5, ground: Tokens.Colors.positiveWash, radius: Tokens.Radius.xl) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        Text(Copy.f("today.all_done_title", ["streak": "\(habit.s.currentDays)"])).style(TypeStyle.title2, color: Tokens.Colors.positive)
                        Text(Copy.s("today.all_done_body")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                    }
                }
            }

            SectionLabel(text: Copy.s("today.tasks_header"))
            VStack(spacing: Tokens.Space.s3) {
                ForEach(open.filter { $0.cadence == .daily }) { t in
                    TaskRow(title: t.title, subtitle: subtitle(t), done: status.dailyDone.contains(t.id), onToggle: { toggle(t) }, onOpen: { openTask = t })
                }
                ForEach(open.filter { $0.cadence == .weekly }) { t in
                    let p = habit.weeklyProgress(week)[t.id] ?? (0, t.weeklyTarget ?? 0)
                    TaskRow(title: t.title, subtitle: Copy.f("task_detail.weekly_progress", ["done": "\(p.done)", "target": "\(p.target)"]),
                            done: p.done >= p.target, onToggle: { toggle(t) }, onOpen: { openTask = t })
                }
                ForEach(open.filter { $0.cadence == .once }) { t in
                    TaskRow(title: t.title, subtitle: subtitle(t), done: habit.s.completions.values.contains { $0.contains(t.id) }, onToggle: { toggle(t) }, onOpen: { openTask = t })
                }
            }

            Card(ground: Tokens.Colors.raised) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if (1...HabitConstants.pathWeeks).contains(week) {
                            Text(habit.isBanked(week) ? Copy.f("today.week_banked", ["week": "\(week)"])
                                 : Copy.f("today.week_banking", ["days": "\(habit.daysCompleteInWeek(week))"])).style(TypeStyle.rowTitle)
                        }
                        if let d = habit.daysUntilNextScan(today: today) {
                            Text(d == 1 ? Copy.s("today.scan_countdown_one") : Copy.f("today.scan_countdown", ["days": "\(d)"])).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                        }
                    }
                    Spacer()
                    weekPips(habit, week)
                }
            }
        }
    }

    private func weekPips(_ habit: HabitEngine, _ week: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(habit.weekDates(max(1, week)), id: \.self) { d in
                Circle().fill(habit.dayStatus(d).complete ? Tokens.Colors.positiveFill : Tokens.Colors.track).frame(width: 8, height: 8)
            }
        }
    }

    private func subtitle(_ t: PlanTask) -> String? {
        guard let first = t.findingRefs.first, let m = app.registry.metrics[first] else { return nil }
        return Copy.f("today.task_from_finding", ["metric": m.short])
    }

    // MARK: actions

    private func toggle(_ t: PlanTask) {
        guard let h = app.habit else { return }
        let wasComplete = h.dayStatus(today).complete
        let done = h.s.completions[today]?.contains(t.id) ?? false
        if done { h.uncompleteTask(t.id, on: today) }
        else {
            if h.streakAtRisk(today: today) && !wasComplete { showStreakSave = true }
            _ = try? h.completeTask(t.id, on: today)
            app.analytics.track(.taskCompleted(rule: t.ruleId))
        }
        Store.save(habit: h.s)
        let now = h.dayStatus(today)
        if now.complete && !wasComplete {
            app.analytics.track(.dayCompleted(week: now.weekIndex))
            if h.isBanked(now.weekIndex) && h.daysCompleteInWeek(now.weekIndex) == HabitConstants.bankThreshold { app.analytics.track(.weekBanked(week: now.weekIndex)) }
            showDayComplete = true
        }
        tick += 1
    }

    private func checkTriggers() {
        guard let h = app.habit else { return }
        let c = Store.counters()
        if h.shouldShowDistress(today: today, DistressSignals(resultsOpensToday: c.resultsOpens, rescanAttemptsInWindow: c.rescanAttempts)) {
            showDistress = true
            h.markDistressShown(today: today); Store.save(habit: h.s)
            app.analytics.track(.distressCardShown)
        }
    }
}

/// Calm, unstyled, never A/B tested. 988 is in the copy; nothing else.
struct DistressCard: View {
    let onDismiss: () -> Void
    var body: some View {
        Card(ground: Tokens.Colors.raised) {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text(Copy.s("today.quiet_checkin_title")).style(TypeStyle.title3)
                Text(Copy.s("today.quiet_checkin_body")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                Button(Copy.s("today.quiet_checkin_dismiss"), action: onDismiss).buttonStyle(.quiet).frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
