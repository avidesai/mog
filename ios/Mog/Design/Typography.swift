import SwiftUI
import UIKit

/// Resolves a `TextStyle` to a SwiftUI `Font`, using the bundled Inter Tight / Instrument Serif
/// when present (see Fonts/README.md) and falling back to the system fonts otherwise.
enum Typography {
    private static let interTightAvailable: Bool = UIFont(name: "InterTight-Regular", size: 12) != nil
    private static let instrumentSerifAvailable: Bool = UIFont(name: "InstrumentSerif-Regular", size: 12) != nil

    static func font(_ s: TextStyle) -> Font {
        switch s.family {
        case .serif:
            return instrumentSerifAvailable ? .custom("InstrumentSerif-Regular", size: s.size)
                                            : .system(size: s.size, weight: .regular, design: .serif)
        case .sans:
            guard interTightAvailable else { return .system(size: s.size, weight: s.weight) }
            let name: String
            switch s.weight {
            case .bold: name = "InterTight-Bold"
            case .semibold: name = "InterTight-SemiBold"
            case .medium: name = "InterTight-Medium"
            default: name = "InterTight-Regular"
            }
            return .custom(name, size: s.size)
        }
    }
}

extension View {
    /// Apply a token text style: font, tracking, line spacing, and tabular numerals for values.
    func textStyle(_ s: TextStyle, color: Color = Tokens.Colors.ink900) -> some View {
        self.font(s.font)
            .tracking(s.tracking)
            .lineSpacing(s.lineSpacing)
            .foregroundStyle(color)
            .monospacedDigit()
    }
}

extension Text {
    func style(_ s: TextStyle, color: Color = Tokens.Colors.ink900) -> some View {
        self.font(s.font).tracking(s.tracking).lineSpacing(s.lineSpacing).foregroundStyle(color).monospacedDigit()
    }
}
