# Mog — iOS

SwiftUI, iOS 18, iPhone only, TrueDepth required. Depends on `../core/swift/MogCore` for all scoring, planning and habit logic; the app itself is capture, geometry, persistence and screens.

> **Written without a compiler.** No Swift toolchain was available where this was authored. Expect a first `xcodebuild` to surface type nits (optional chaining, `Bundle.module` lookups, SwiftData macro details). The architecture and logic are deliberate; the syntax errors are not. Fix forward; nothing here was tested on a device.

## Generate and run

```
brew install xcodegen
cp Mog/Config/Secrets.xcconfig.example Mog/Config/Secrets.xcconfig   # set DEVELOPMENT_TEAM
# drop the five TTFs into Mog/Fonts/ (see Fonts/README.md) — optional, falls back to system fonts
cd ios && xcodegen generate && open Mog.xcodeproj
```

Run on a real iPhone with Face ID (the simulator has no TrueDepth).

## Week 1 — the spike this app exists to run

Settings › Debug (debug builds only):

1. **Vertex picker.** Tap your own face mesh to read ARKit vertex indices; fill `Geometry/landmark_map.json`. Until a point is picked, `Landmarker` uses a geometric heuristic for it at reduced confidence. 38 points; nasion, pronasale, menton, zygions and canthi matter most.
2. **Landmark dump.** Gated captures write `Documents/captures/<session>/capture_N.json` (per-frame pose, per-frame metrics, aggregated readings, raw vertices). Do 10 captures × 3 sessions (different times of day / lighting). Pull the folder with Xcode › Devices, then:
   ```
   python core/tools/cv_analysis.py path/to/captures/
   ```
   which prints per-metric within-session CV, between-session CV, and a provisional tier. Paste tiers into `core/data/metrics.json`, rebuild the reference table, bump the model version.

**Go/no-go:** ≥6 of the frontal metrics at tier A/B → continue. <4 → re-scope around skin / adiposity / grooming (eng doc).

A hypothesis to test in the same spike: the ARKit mesh is 3D and pose-normalised, so `Metrics.swift` already computes the profile angles (nasofrontal, nasolabial, convexity, mentolabial, E-line) from the **frontal** capture's midline. If their CV is acceptable, the separate profile capture and its custom landmark model (spike 2, the biggest unknown in the plan) may be unnecessary.

## Map

```
App/            MogApp (AppModel: registry, profile, score/plan/habit, services), RootView (routes, tabs)
Design/         Tokens.swift (GENERATED from design/design-system/tokens.json), Typography, Components
Copy/           Copy.s / Copy.f — every string from core/copy/strings.json; nothing hard-coded in views
Capture/        CaptureSession (ARKit), GateEvaluator (9 gates), LumaStats (lighting/sharpness), FrameAggregator (median + IQR)
Geometry/       Landmarker (picked indices + heuristics), MetricFunctions (→ metrics.json ids), GeometryPipeline
Features/       Onboarding, Consent, Capture, Results (Reveal, Results, MetricDetail), Paywall, Today (+ task sheets),
                Plan, Path (+ Progress), Settings (+ Methodology), Debug (spike tools)
Services/       UserProfile (UserDefaults), Store (SwiftData, complete file protection), Purchases (protocol + stub),
                Analytics (closed event allowlist, no-op transport)
```

## What is wired vs stubbed

| Wired | Stubbed / TODO (week) |
|---|---|
| Onboarding → consent (with policy version + state attestation) → capture → score → reveal → results → metric detail | Policy URLs point at `example.invalid` (7) |
| 9 capture gates, auto-capture, abort on drift, 10-frame median + IQR | Occlusion gate passes when tracked — decide in spike 1 |
| 24 frontal + profile-from-mesh metrics via heuristics / picked indices | Facial thirds (need trichion), cervicomental, gonial, ramus, forehead slope — need appearance layer or profile capture |
| Free/Pro gating of result rows; compliant paywall layout | RevenueCat + Superwall (5); `PurchasesStub` until then |
| Today / task detail / day complete / streak save / distress card, all driven by `HabitEngine` | — |
| Plan (now / later / info / professional), Path, Progress with noise-aware deltas; measurement overlays drawn on the user's own mesh projection in-session and on a labelled schematic afterwards (nothing geometric persisted — see `Features/Results/Overlay.swift`) | Photo backdrop under the in-session overlay (5; the geometry is the user's, the photo is cosmetic) |
| Settings incl. Delete everything (local wipe) | Supabase sync + server-side deletion + Sign in with Apple (7); appearance heads skin/adiposity (spike 5); LLM phrasing (8) |
| Analytics allowlist | PostHog transport (7) |

## Before TestFlight (week 10 checklist)

- Remove the Debug section (it's `#if DEBUG`, so Release builds already exclude it — verify).
- Replace every `example.invalid` URL.
- Run the MITM audit over a full session.
- `UIUserInterfaceStyle: Light` is intentional: one light register.
