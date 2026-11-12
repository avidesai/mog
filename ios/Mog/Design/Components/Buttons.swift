import SwiftUI

/// The chunky primary button: 54pt, radius lg, accent fill, 4pt darker lip on the bottom.
/// Press feedback is the lip collapsing by 2pt (the button "sits down"), no scale, no shadow.
struct ChunkyButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, ink, critical }
    var variant: Variant = .primary

    private var fill: Color {
        switch variant {
        case .primary: return Tokens.Colors.accent
        case .secondary: return Tokens.Colors.surface50
        case .ink: return Tokens.Colors.ink900
        case .critical: return Tokens.Colors.critical
        }
    }
    private var lip: Color {
        switch variant {
        case .primary: return Tokens.Colors.accentDeep
        case .secondary: return Tokens.Colors.line200
        case .ink: return Color.black.opacity(0.35)
        case .critical: return Color.black.opacity(0.25)
        }
    }
    private var label: Color { variant == .secondary ? Tokens.Colors.ink900 : .white }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .textStyle(TypeStyle.button, color: label)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                            .strokeBorder(variant == .secondary ? Tokens.Colors.line200 : .clear, lineWidth: Tokens.Border.hairline)
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(lip)
                    .offset(y: pressed ? Tokens.Border.lip / 2 : Tokens.Border.lip)
            )
            .offset(y: pressed ? Tokens.Border.lip / 2 : 0)
            .animation(.easeOut(duration: Tokens.Motion.instant), value: pressed)
            .opacity(configuration.isPressed ? 0.98 : 1)
    }
}

extension ButtonStyle where Self == ChunkyButtonStyle {
    static var chunky: ChunkyButtonStyle { ChunkyButtonStyle() }
    static func chunky(_ v: ChunkyButtonStyle.Variant) -> ChunkyButtonStyle { ChunkyButtonStyle(variant: v) }
}

/// Quiet text button for "Not now", "Keep the free version", etc.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(TypeStyle.body, color: Tokens.Colors.ink500)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
extension ButtonStyle where Self == QuietButtonStyle { static var quiet: QuietButtonStyle { QuietButtonStyle() } }

/// Option row used in onboarding: hairline card with a 4pt lip; selected = 2pt accent border + wash.
struct OptionRow: View {
    let title: String
    var subtitle: String? = nil
    var rank: Int? = nil           // for ordered multi-select (goals)
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).style(TypeStyle.rowTitle)
                    if let subtitle { Text(subtitle).style(TypeStyle.detail, color: Tokens.Colors.ink500) }
                }
                Spacer(minLength: 0)
                if let rank, selected {
                    Text("\(rank)").style(TypeStyle.chip, color: .white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Tokens.Colors.accent))
                } else if selected {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Tokens.Colors.accent)
                }
            }
            .padding(.horizontal, Tokens.Space.s4)
            .frame(minHeight: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(selected ? Tokens.Colors.accentWash : Tokens.Colors.surface50)
                    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                        .strokeBorder(selected ? Tokens.Colors.accent : Tokens.Colors.line200,
                                      lineWidth: selected ? Tokens.Border.emphasis : Tokens.Border.hairline))
            )
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(selected ? Tokens.Colors.accentDeep.opacity(0.25) : Tokens.Colors.line200)
                    .offset(y: Tokens.Border.lip)
            )
        }
        .buttonStyle(.plain)
    }
}
