import SwiftUI
import MogCore

/// The eight-week path. Nodes: banked (green), current (accent), open (accent ring), upcoming
/// (track), scan weeks (viewfinder), and the week-8 finish — the single gold element.
struct PathView: View {
    @Environment(AppModel.self) private var app
    private var today: String { LocalDay.today() }

    var body: some View {
        NavigationStack {
            Screen {
                Text(Copy.s("journey.intro")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                if let habit = app.habit {
                    let current = habit.weekIndex(today)
                    VStack(spacing: 0) {
                        ForEach(1...HabitConstants.pathWeeks, id: \.self) { w in
                            HStack(spacing: Tokens.Space.s4) {
                                VStack(spacing: 0) {
                                    PathNode(week: w, state: state(w, current: current, habit: habit))
                                    if w < HabitConstants.pathWeeks { Rectangle().fill(w < current ? Tokens.Colors.positiveFill : Tokens.Colors.track).frame(width: 3, height: 36) }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(label(w, current: current, habit: habit)).style(TypeStyle.rowTitle)
                                    if (1...HabitConstants.pathWeeks).contains(w) && w <= current {
                                        Text(Copy.f("today.week_banking", ["days": "\(habit.daysCompleteInWeek(w))"])).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                                    }
                                    if HabitConstants.scanWeeks.contains(w) {
                                        Text(habit.s.scans[w] != nil ? Copy.s("journey.node_scan") + " ✓" : Copy.s("journey.node_scan")).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                                    }
                                }
                                .padding(.bottom, w < HabitConstants.pathWeeks ? 36 : 0)
                                Spacer()
                            }
                        }
                    }
                    if habit.finishedPath {
                        Card(padding: Tokens.Space.s5, radius: Tokens.Radius.xl) {
                            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                                Text(Copy.s("journey.finish_title")).style(TypeStyle.title2)
                                Text(Copy.s("journey.finish_body")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous).strokeBorder(Tokens.Colors.finish, lineWidth: Tokens.Border.emphasis))
                    }
                } else {
                    Card(ground: Tokens.Colors.raised) { Text(Copy.s("today.empty_title")).style(TypeStyle.body, color: Tokens.Colors.ink700) }
                }
                NavigationLink(Copy.s("progress.title")) { ProgressView_() }.font(TypeStyle.rowTitle.font).foregroundStyle(Tokens.Colors.accent)
            }
            .navigationTitle(Copy.s("journey.title")).navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Tokens.Colors.paper, for: .navigationBar)
        }
    }

    private func state(_ w: Int, current: Int, habit: HabitEngine) -> PathNode.State {
        if habit.isBanked(w) { return .banked }
        if w == HabitConstants.pathWeeks && habit.s.scans[8] != nil { return .finish }
        if w == current { return .current }
        if w < current { return .open }
        if HabitConstants.scanWeeks.contains(w) { return .scan }
        return .upcoming
    }
    private func label(_ w: Int, current: Int, habit: HabitEngine) -> String {
        if habit.isBanked(w) { return Copy.s("journey.node_banked") + " · " + Copy.f("journey.node_upcoming", ["week": "\(w)"]) }
        if w == current { return Copy.s("journey.node_current") }
        if w < current { return Copy.s("journey.node_open") + " · " + Copy.f("journey.node_upcoming", ["week": "\(w)"]) }
        return Copy.f("journey.node_upcoming", ["week": "\(w)"])
    }
}

/// Progress: the list of scans with deltas between consecutive scans on the same model version.
struct ProgressView_: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        let scans = Store.allScans()
        Screen(title: Copy.s("progress.title")) {
            if scans.count < 2 { Text(Copy.s("progress.empty_body")).style(TypeStyle.body, color: Tokens.Colors.ink700) }
            ForEach(Array(scans.enumerated()), id: \.element.id) { i, s in
                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Copy.f("progress.scan_label", ["n": "\(i + 1)", "date": s.localDate])).style(TypeStyle.rowTitle)
                            Text(Copy.f("common.likely_band", ["low": String(format: "%.1f", s.scoreLow), "high": String(format: "%.1f", s.scoreHigh)]) + " · " + s.tier).style(TypeStyle.detail, color: Tokens.Colors.ink500)
                        }
                        Spacer()
                        Text(String(format: "%.1f", s.score)).style(TypeStyle.valueLg)
                        if i > 0 { delta(from: scans[i - 1], to: s) }
                    }
                }
            }
            Text(Copy.s("progress.model_note")).style(TypeStyle.caption, color: Tokens.Colors.ink500)
        }
        .toolbarBackground(Tokens.Colors.paper, for: .navigationBar)
    }
    private func delta(from a: ScanRecord, to b: ScanRecord) -> some View {
        let d = b.score - a.score
        let noise = max(b.scoreHigh - b.score, a.scoreHigh - a.score)
        let text: String = a.modelVersion != b.modelVersion ? b.modelVersion : abs(d) < noise ? Copy.s("progress.delta_within_noise") : d > 0 ? Copy.f("progress.delta_up", ["value": String(format: "%.1f", d)]) : Copy.f("progress.delta_down", ["value": String(format: "%.1f", -d)])
        let color: Color = a.modelVersion != b.modelVersion ? Tokens.Colors.ink500 : abs(d) < noise ? Tokens.Colors.ink500 : d > 0 ? Tokens.Colors.positive : Tokens.Colors.ink700
        return Text(text).style(TypeStyle.chip, color: color)
    }
}
