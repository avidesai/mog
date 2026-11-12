import SwiftUI
import MogCore

// MARK: - Card

struct Card<Content: View>: View {
    var padding: CGFloat = Tokens.Space.s4
    var ground: Color = Tokens.Colors.surface50
    var radius: CGFloat = Tokens.Radius.lg
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(ground)
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Tokens.Colors.line200, lineWidth: Tokens.Border.hairline))
            )
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View { Text(text.uppercased()).style(TypeStyle.sectionLabel, color: Tokens.Colors.ink500) }
}

// MARK: - Evidence badge (meaning in label + border, never fill)

struct EvidenceBadge: View {
    let grade: EvidenceGrade
    var body: some View {
        let (label, border, ink, dashed): (String, Color, Color, Bool) = {
            switch grade {
            case .strong: return (Copy.s("common.evidence_strong"), Tokens.Colors.ink900, Tokens.Colors.ink900, false)
            case .moderate: return (Copy.s("common.evidence_moderate"), Tokens.Colors.line200, Tokens.Colors.ink700, false)
            case .weak: return (Copy.s("common.evidence_weak"), Tokens.Colors.line200, Tokens.Colors.ink500, false)
            case .community: return (Copy.s("common.evidence_community"), Tokens.Colors.line200, Tokens.Colors.ink500, true)
            case .contradicted: return (Copy.s("common.evidence_contradicted"), Tokens.Colors.caution, Tokens.Colors.caution, false)
            }
        }()
        Text(label).style(TypeStyle.chip, color: ink)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                .strokeBorder(border, style: StrokeStyle(lineWidth: 1, dash: dashed ? [3, 3] : [])))
    }
}

// MARK: - Tier chip (never coloured by tier)

struct TierChip: View {
    let tier: String
    var body: some View {
        Text(tier).style(TypeStyle.chip, color: Tokens.Colors.ink700)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.sm).strokeBorder(Tokens.Colors.line200, lineWidth: 1))
    }
}

// MARK: - Score band: "6.4 · likely 5.9–6.9 · HTN", with the thin ring

struct ScoreBand: View {
    let result: ScoreResult
    var display: TextStyle = TypeStyle.displayReveal
    var body: some View {
        VStack(spacing: Tokens.Space.s2) {
            Text(String(format: "%.1f", result.score)).style(display)
            HStack(spacing: 6) {
                Text(Copy.f("common.likely_band", ["low": String(format: "%.1f", result.scoreLow), "high": String(format: "%.1f", result.scoreHigh)]))
                    .style(TypeStyle.body, color: Tokens.Colors.ink700)
                Text("·").style(TypeStyle.body, color: Tokens.Colors.ink300)
                TierChip(tier: result.tier)
            }
            Text(Copy.f("common.tier_subline", ["tier_long": result.tierLong, "pct": String(Int(result.percentile.rounded()))]))
                .style(TypeStyle.detail, color: Tokens.Colors.ink500)
                .multilineTextAlignment(.center)
        }
    }
}

/// Range track: typical band in accent-wash, the reading as a 2pt accent mark, band as a lighter mark pair.
struct RangeTrack: View {
    let value: Double
    let low: Double?      // band
    let high: Double?
    let refMean: Double
    let refSD: Double
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            // map ±3 SD onto the width
            let x: (Double) -> CGFloat = { v in CGFloat(min(1, max(0, ((v - refMean) / refSD + 3) / 6))) * w }
            ZStack(alignment: .leading) {
                Capsule().fill(Tokens.Colors.track).frame(height: 4)
                Capsule().fill(Tokens.Colors.accentWash).frame(width: x(refMean + refSD) - x(refMean - refSD), height: 4).offset(x: x(refMean - refSD))
                if let low, let high {
                    Rectangle().fill(Tokens.Colors.accent.opacity(0.25)).frame(width: max(2, x(high) - x(low)), height: 10).offset(x: x(low), y: 0)
                }
                RoundedRectangle(cornerRadius: 1).fill(Tokens.Colors.accent).frame(width: 2, height: 12).offset(x: x(value) - 1)
            }
        }
        .frame(height: 12)
    }
}

// MARK: - Streak pill (the one amber in the product)

struct StreakPill: View {
    let days: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(days > 0 ? Tokens.Colors.flame : Tokens.Colors.ink300)
            Text(days == 0 ? Copy.s("today.streak_zero") : days == 1 ? Copy.s("today.streak_single") : Copy.f("today.streak_days", ["streak": "\(days)"]))
                .style(TypeStyle.chip, color: days > 0 ? Tokens.Colors.flameText : Tokens.Colors.ink500)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(days > 0 ? Tokens.Colors.flameWash : Tokens.Colors.raised))
    }
}

// MARK: - Task row (hairline + lip, tappable, check circle)

struct TaskRow: View {
    let title: String
    var subtitle: String? = nil
    let done: Bool
    var locked: Bool = false
    let onToggle: () -> Void
    let onOpen: () -> Void
    var body: some View {
        HStack(spacing: Tokens.Space.s3) {
            Button(action: onToggle) {
                ZStack {
                    Circle().strokeBorder(done ? Tokens.Colors.positiveFill : Tokens.Colors.ink300, lineWidth: 2).frame(width: 28, height: 28)
                    if done { Circle().fill(Tokens.Colors.positiveFill).frame(width: 28, height: 28)
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white) }
                }
            }.buttonStyle(.plain).disabled(locked)
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).strikethrough(done, color: Tokens.Colors.ink300).style(TypeStyle.rowTitle, color: locked ? Tokens.Colors.ink500 : Tokens.Colors.ink900)
                    if let subtitle { Text(subtitle).style(TypeStyle.detail, color: Tokens.Colors.ink500) }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Tokens.Colors.ink300)
            }.buttonStyle(.plain)
        }
        .padding(Tokens.Space.s4)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous).fill(done ? Tokens.Colors.positiveWash : Tokens.Colors.surface50)
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous).strokeBorder(Tokens.Colors.line200, lineWidth: Tokens.Border.hairline)))
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous).fill(Tokens.Colors.line200).offset(y: Tokens.Border.lip))
    }
}

// MARK: - Path node

struct PathNode: View {
    enum State { case banked, current, open, upcoming, scan, finish }
    let week: Int
    let state: State
    var body: some View {
        ZStack {
            switch state {
            case .banked: Circle().fill(Tokens.Colors.positiveFill); Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            case .current: Circle().fill(Tokens.Colors.accent); Text("\(week)").style(TypeStyle.value, color: .white)
            case .open: Circle().strokeBorder(Tokens.Colors.accent, lineWidth: 2); Text("\(week)").style(TypeStyle.value, color: Tokens.Colors.accent)
            case .upcoming: Circle().fill(Tokens.Colors.track); Text("\(week)").style(TypeStyle.value, color: Tokens.Colors.ink500)
            case .scan: Circle().strokeBorder(Tokens.Colors.ink900, lineWidth: 2); Image(systemName: "viewfinder").font(.system(size: 16, weight: .semibold)).foregroundStyle(Tokens.Colors.ink900)
            case .finish: Circle().fill(Tokens.Colors.finish); Image(systemName: "flag.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            }
        }
        .frame(width: 48, height: 48)
    }
}

// MARK: - Gate chip (lives on the dark capture viewport only)

struct GateChip: View {
    let label: String
    let passing: Bool
    var body: some View {
        Text(passing ? "\(label) ✓" : label).style(TypeStyle.chip, color: passing ? Color(light: 0x7D9BFF, dark: 0x7D9BFF) : Color(light: 0xE0A355, dark: 0xE0A355))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.sm).strokeBorder(passing ? Tokens.Colors.accent : Color(light: 0xE0A355, dark: 0xE0A355), lineWidth: 1))
            .animation(.easeOut(duration: Tokens.Motion.instant), value: passing)
    }
}

// MARK: - Screen scaffold

struct Screen<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack {
            Tokens.Colors.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                    if let title { Text(title).style(TypeStyle.title1).padding(.top, Tokens.Space.s2) }
                    content()
                }
                .padding(.horizontal, Tokens.Space.s5)
                .padding(.bottom, Tokens.Space.s6)
            }
        }
    }
}
