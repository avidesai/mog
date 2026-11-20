# Exact UI — settled (13 Nov 2026; look revised 20 Nov)

- The app is built on expo/exact from here. The SwiftUI app in `ios/` is reference and fallback, not the product (owner's call, 13 Nov).
- Capture stays Swift: `ios/Mog/Capture` + `ios/Mog/Geometry` become the `mog-capture` native view module; the Contract never sees pixels, only readings.
- Scoring/planning/habit logic runs in `app.ts` as a dependency-free TypeScript port of MogCore that must pass `core/fixtures/scoring_cases.json` to 1e-6 — the same gate the Swift port has.
- Purchases via `@exact/purchases`; Sign in with Apple via `@exact/sign-in` (provider's own button). RevenueCat/Superwall are dropped unless `@exact/purchases` cannot express the trial.
- **The app is drawn to the Claude Design artboards** (`design/screens-gamified`): paper ground, Inter Tight and Instrument Serif, lipped buttons and option rows, hairline cards, the drawn tab bar (Today / Path / Metrics / You) and bars. Owner's call, 20 Nov, replacing the 13 Nov "platform chrome wins" line. Still the platform's: the switch, alerts, sheets' presentation, and text-size scaling.
- The five colour-meaning rules hold: blue = measurement and the primary action, green = done, amber = the streak flame only, gold = the week-8 finish only, nothing encodes score quality.
- Every string still comes from `core/copy/strings.json` (Exact's `strings/en.json` is generated from it) and passes the ladder + denylist.

## Revisit
- If Exact's iOS host cannot ship App Store builds by week 10 (`eas-ios` recipe exists; verify), the SwiftUI app ships v1 and Exact becomes v1.1.
