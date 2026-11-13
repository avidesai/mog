# Exact UI — settled (13 Nov 2026)

- The app is built on expo/exact from here. The SwiftUI app in `ios/` is reference and fallback, not the product (owner's call, 13 Nov).
- Capture stays Swift: `ios/Mog/Capture` + `ios/Mog/Geometry` become the `mog-capture` native view module; the Contract never sees pixels, only readings.
- Scoring/planning/habit logic runs in `app.ts` as a dependency-free TypeScript port of MogCore that must pass `core/fixtures/scoring_cases.json` to 1e-6 — the same gate the Swift port has.
- Purchases via `@exact/purchases`; Sign in with Apple via `@exact/sign-in` (provider's own button). RevenueCat/Superwall are dropped unless `@exact/purchases` cannot express the trial.
- Platform chrome wins over the design system where they conflict. Keep: palette as tamber tokens, the five colour-meaning rules, one light register, evidence badges as `Badge`, the eight-week path as content. Drop: 4 px lips on buttons, custom nav/tab chrome.
- Every string still comes from `core/copy/strings.json` (Exact's `strings/en.json` is generated from it) and passes the ladder + denylist.

## Revisit
- Custom fonts (Inter Tight / Instrument Serif) in Exact: spike; if the platform font is the only option, that is the decision.
- If Exact's iOS host cannot ship App Store builds by week 10 (`eas-ios` recipe exists; verify), the SwiftUI app ships v1 and Exact becomes v1.1.
