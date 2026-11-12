// GENERATED from design/design-system/tokens.json by tools/gen_tokens.py — do not edit by hand.
import SwiftUI

public enum Tokens {
    // MARK: Colours (light / dark)
    public enum Colors {
        /// App background. Warm ivory. Every neutral below is mixed to sit on it.
        public static let paper = Color(light: 0xFBF9F5, dark: 0x15130F)
        /// Cards, task rows, sheets.
        public static let surface50 = Color(light: 0xFFFFFF, dark: 0x1E1B16)
        /// Quiet grounds: locked cards, info panels, the scan countdown. Depth without shadow.
        public static let raised = Color(light: 0xF3EFE6, dark: 0x272319)
        /// Empty progress — range tracks, week pips, unfilled rings.
        public static let track = Color(light: 0xEFE9DD, dark: 0x2E2920)
        /// Primary text, score numerals, the dark primary button. Every score uses this, high or low.
        public static let ink900 = Color(light: 0x1A1714, dark: 0xF5F1EA)
        /// Secondary text and body copy.
        public static let ink700 = Color(light: 0x4A443D, dark: 0xCFC8BC)
        /// Tertiary text, captions, section labels. 4.6:1 on paper.
        public static let ink500 = Color(light: 0x7A7268, dark: 0x9B9284)
        /// Disabled, unchecked rings, inactive marks. Non-text only.
        public static let ink300 = Color(light: 0xB5ADA2, dark: 0x6B6457)
        /// Hairline borders and dividers, 1.5px on cards. Carries all depth in place of shadow.
        public static let line200 = Color(light: 0xE6E0D6, dark: 0x332E25)
        /// Measurement — the overlay line, metric markers, the current path node — and the primary button. One accent element per card.
        public static let accent = Color(light: 0x2E5BFF, dark: 0x8AA5FF)
        /// The 4px bottom lip on a primary button, and link hover.
        public static let accentDeep = Color(light: 0x1F44CC, dark: 0x6A86E6)
        /// The typical-range band on a track; the 'why this' panel; a selected option's ground.
        public static let accentWash = Color(light: 0xE8EDFF, dark: 0x1F2742)
        /// Text for done and improved: 'Done today', a delta that moved the right way. 5.4:1 on white. Never means a good score.
        public static let positive = Color(light: 0x157A49, dark: 0x6FC294)
        /// Filled check circles, banked path nodes, the day-complete ring. Graphical only — fails as small text.
        public static let positiveFill = Color(light: 0x1C9D5F, dark: 0x5FB885)
        /// Ground behind a done or improved state.
        public static let positiveWash = Color(light: 0xE6F4EC, dark: 0x16301F)
        /// The streak flame icon and nothing else. Graphical only.
        public static let flame = Color(light: 0xD97A0B, dark: 0xE8963A)
        /// The streak count beside the flame. 4.9:1 on white.
        public static let flameText = Color(light: 0xA85F08, dark: 0xE0A355)
        /// Ground of the streak pill and streak tile.
        public static let flameWash = Color(light: 0xFDF0DC, dark: 0x2E2010)
        /// The week-8 trophy node on the path. The only other warm accent in the product, and it appears once.
        public static let finish = Color(light: 0xE0A020, dark: 0xE8B24A)
        /// The wordmark tick. Brand mark only.
        public static let bronze = Color(light: 0x8E6020, dark: 0xD7A95C)
        /// A capture gate that is failing; a metric not measured. System state, never score.
        public static let caution = Color(light: 0x9A6514, dark: 0xD9A24E)
        /// Delete everything. The only red in the product.
        public static let critical = Color(light: 0xA8372A, dark: 0xE57A68)
    }
    // MARK: Spacing
    public enum Space {
        public static let s1: CGFloat = 4  // Label to value.
        public static let s2: CGFloat = 8  // Tight grouping; gap between chips.
        public static let s3: CGFloat = 12  // Gap between cards and rows.
        public static let s4: CGFloat = 16  // Card padding.
        public static let s5: CGFloat = 20  // Screen margin; hero-card padding.
        public static let s6: CGFloat = 24  // Section gap; bottom safe-area padding.
        public static let s7: CGFloat = 32  // Above a display headline.
        public static let s14: CGFloat = 56  // Top bar height; option-row minimum height.
    }
    // MARK: Radius
    public enum Radius {
        public static let sm: CGFloat = 4  // Blur plates behind locked values; range markers.
        public static let md: CGFloat = 12  // Small inline buttons inside a card.
        public static let lg: CGFloat = 16  // Cards, task rows, buttons, option rows, info panels. The workhorse.
        public static let xl: CGFloat = 20  // Hero cards: the photo frame, the capture viewport, the scan-day card.
        public static let cardstack: CGFloat = 24  // The swipe stack only.
        public static let full: CGFloat = 999  // Pills, chips, check circles, path nodes, the shutter ring.
    }
    // MARK: Border
    public enum Border {
        public static let hairline: CGFloat = 1.5  // Every card and row edge.
        public static let lip: CGFloat = 4  // The bottom edge of anything pressable — primary and secondary buttons, option rows, tappable task rows. A chunky button is hairline on three sides and lip on the bottom, in a darker shade of its fill.
        public static let emphasis: CGFloat = 2  // A selected option, the consent panel, the model-updated card.
    }
    // MARK: Motion (seconds)
    public enum Motion {
        public static let instant: Double = 0.1  // Press feedback, gate chip state changes. Cross-fade, no movement.
        public static let quick: Double = 0.18  // Sheet presentation, toasts.
        public static let standard: Double = 0.24  // Navigation, overlay metric transitions, swipe-stack advance.
        public static let deliberate: Double = 0.6  // The reveal and the day-complete ring. Nowhere else.
    }
}

/// Text styles from tokens.json.
public struct TextStyle {
    public enum Family { case sans, serif }
    public let family: Family; public let size: CGFloat; public let lineHeight: CGFloat; public let weight: Font.Weight; public let tracking: CGFloat
    public var font: Font { Typography.font(self) }
    public var lineSpacing: CGFloat { max(0, lineHeight - size * 1.2) }
}

public enum TypeStyle {
    public static let displayShare = TextStyle(family: .serif, size: 124, lineHeight: 104, weight: .regular, tracking: -4.96)
    public static let displayReveal = TextStyle(family: .serif, size: 104, lineHeight: 92, weight: .regular, tracking: -3.64)
    public static let displayDay = TextStyle(family: .serif, size: 52, lineHeight: 44, weight: .regular, tracking: -1.56)
    public static let displayTitle = TextStyle(family: .serif, size: 40, lineHeight: 38, weight: .regular, tracking: -1.2)
    public static let title1 = TextStyle(family: .sans, size: 28, lineHeight: 34, weight: .semibold, tracking: -0.62)
    public static let title2 = TextStyle(family: .sans, size: 20, lineHeight: 26, weight: .bold, tracking: -0.36)
    public static let title3 = TextStyle(family: .sans, size: 17, lineHeight: 24, weight: .semibold, tracking: -0.27)
    public static let rowTitle = TextStyle(family: .sans, size: 16, lineHeight: 22, weight: .semibold, tracking: -0.22)
    public static let body = TextStyle(family: .sans, size: 15, lineHeight: 22, weight: .regular, tracking: -0.18)
    public static let bodySm = TextStyle(family: .sans, size: 14, lineHeight: 20, weight: .regular, tracking: -0.17)
    public static let detail = TextStyle(family: .sans, size: 13, lineHeight: 19, weight: .regular, tracking: -0.13)
    public static let sectionLabel = TextStyle(family: .sans, size: 12, lineHeight: 16, weight: .bold, tracking: 0.72)
    public static let chip = TextStyle(family: .sans, size: 12, lineHeight: 16, weight: .semibold, tracking: 0.12)
    public static let caption = TextStyle(family: .sans, size: 11, lineHeight: 15, weight: .regular, tracking: 0.11)
    public static let value = TextStyle(family: .sans, size: 17, lineHeight: 22, weight: .medium, tracking: -0.17)
    public static let valueLg = TextStyle(family: .sans, size: 26, lineHeight: 28, weight: .bold, tracking: -0.52)
    public static let valueXl = TextStyle(family: .sans, size: 40, lineHeight: 40, weight: .bold, tracking: -0.8)
    public static let button = TextStyle(family: .sans, size: 16, lineHeight: 20, weight: .bold, tracking: -0.19)
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { tc in
            let v = tc.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        })
    }
}
