# Mog — project index (as of 12 Nov 2026)

Working name: **Mog** (open question — collisions with Mogged / MogMax and tension with the no-comparative-language voice rule).

## Live documents (edit these; the .md copies here are snapshots)

| Asset | Link | Status |
|---|---|---|
| Engineering design doc (v1) | https://claude.ai/artifact/HoHrkAUy6ZoBmcjLv134sY | rev 18 — includes 11 Nov decision record + habit-layer data model |
| Design-language bible + UI kit spec | https://claude.ai/artifact/NRfuaHK1yQYLjjTTmN1orz | rev 17 — includes 11 Nov decision record (supersedes instrument-direction sections) |
| Design System "Mog" (tokens, components, brand book) | https://claude.ai/artifact/Ud39Qbn4PiDgu5m1HJTLec | v7 — synced to decided direction |
| **Gamified Direction canvas — the chosen v1 screen set (28 artboards)** | https://claude.ai/artifact/SkhqbXsYoAxQNjT2wJJE19 | v27 — canonical |
| Original "v1 Screens" canvas (instrument direction, bronze) | https://claude.ai/artifact/RU2rRYx5hzZ9a3xHTbGQ9k | superseded, kept for reference |

## The repo — `mog` (monorepo, 14 commits, ready to push to github.com/avidesai/mog)

```
core/     engines + data + copy + legal + appstore + plan + appearance heads (73 tests)
ios/      SwiftUI app (XcodeGen), not yet compiled
backend/  Supabase schema, RLS, delete_everything() — verified on PostgreSQL 16, CI job
site/     policies site builder (versioned URLs) + GitHub Pages workflow
design/   design system + 28 artboards as HTML      docs/  eng doc, bible, research, this index
```
Push: create an empty private repo `avidesai/mog` on GitHub, then from the unzipped repo folder
`git remote add origin git@github.com:avidesai/mog.git && git push -u origin main` (or `git clone mog.bundle mog`).
CI (`.github/workflows/core.yml`) runs the Python tests on every push and `swift test` on macOS.

**Done since the first push-ready state (12 Nov, early):** backend schema with the deletion test the eng doc demanded (passes for real); policies site ready to host the moment a domain exists; skin-evenness and adiposity proxies prototyped in Python with lighting/tone-invariance tests and ported to Swift (spike 5's cheap path, done before the spike).

**12 Nov, evening — the noise finding (read `core/README.md` › "The noise finding").** Simulated test–retest under tier-realistic noise gave ~1.9-point score SDs with the original weighting. Fixed in scoring rules-1.1.0 (attenuation weighting by noise/spread; band includes between-session noise and is calibration-tested). Provisional median SD now ~1.1 (band ±1.4); ~0.55 at half that noise. Release gate revised to median SD ≤ 0.6 on measured noise. The week-1 captures decide. Also this evening: fonts bundled (OFL), artboards render offline, 7 App Store shots + fastlane metadata, week-9 harness with fairness smoke.

**iOS status:** every v1 screen, the capture gates, the mesh-geometry metric layer, persistence, the habit loop and the spike tools are written. The first Xcode build will surface compiler nits (no toolchain here). Week 1 = `xcodegen generate`, build, run Settings › Debug › Vertex picker and Landmark dump on your own face, then `python core/tools/cv_analysis.py captures/`.

**Hypothesis worth testing in the same spike:** the ARKit mesh is 3D and pose-normalised, so profile angles are computed from the *frontal* capture's midline. If their reliability holds, the separate profile capture (spike 2, the plan's biggest unknown) may be unnecessary.

## Code and launch assets — `core/` (also in this Project as docs)

| Asset | Where | Status |
|---|---|---|
| Deterministic engines (scorer, planner, habit, denylist) — Python reference, 65 tests | `core/mogcore`, `core/tests` | Green. `python -m pytest -q` |
| Data tables with citations: 36 metrics, 30 rules, denylist, reference quantiles | `core/data/*.json` | Reliability tiers PROVISIONAL until week-9 harness; `verify:true` citations need checking against papers |
| Swift port `MogCore` (SwiftPM, iOS 18) + golden fixtures | `core/swift/MogCore` | Written, **not compiled** (no toolchain here). First Xcode task: `swift test` |
| Copy deck — every UI string, name-agnostic (`{app_name}`) | `core/copy/` | Scanned against denylist in CI |
| Legal drafts: biometric retention/destruction policy, privacy policy, terms | `core/legal/` | Drafts for counsel; must be hosted before first capture |
| App Store listing, screenshots order, privacy labels, App Review notes (TrueDepth) | `core/appstore/` | Draft |
| 12-week build plan with done-criteria, spend tracker, cut list | `core/plan/build-plan.md` | Starts Mon 17 Nov if you say go |

Snapshots in this Project: `mog-foundation-research.md`, `mog-engineering-design-doc.md`, `mog-design-language-bible.md`.

## Decisions locked on 11 Nov 2026
- Direction: warm ivory, pressable/chunky controls, gamified-lite. One mechanic only (daily plan → streak → eight-week path → scans at weeks 4 and 8). No XP, levels, badges, leagues, bonuses.
- Colour meaning: blue = measurement only; green = done/improved; amber flame = streak only; gold = week-8 finish only. No colour ever encodes score quality.
- Scoring at launch: deterministic rules-only, percentile vs sex/age reference, confidence band shown. Calibrated model later, funded by in-app peer ratings. Never train on SCUT-FBP5500.
- Privacy: nothing biometric leaves the device. 18+ at launch. BIPA-grade consent.
- Monetization: value-first hard paywall; $4.99/wk, $34.99/yr (3-day trial), $59.99 lifetime; RevenueCat + Superwall.
- Budget: $300–400 total. Paid options stay documented in the eng doc for later.

## Still open
- App name.
- Profile capture: v1 or v1.1.

## Next steps (in order) — see `core/plan/build-plan.md` for the week-by-week
1. **Week 1 (17–23 Nov):** pay the $99; Xcode project; ARKit + MediaPipe landmark dump; capture yourself 10× over 3 sessions; compute per-metric CV. Go/no-go on the thesis.
2. **Week 2:** profile spike (go/no-go on profile in v1); compile `MogCore`, pass fixtures.
3. Weeks 3–8: capture gates → metrics → results/paywall → habit layer → backend/consent/deletion → phrasing.
4. Week 9: consistency harness (median per-person score SD ≤ 0.6 — gate revised 12 Nov, see core/README "The noise finding"), fairness smoke, MITM audit. Weeks 10–12: TestFlight, review, launch.
5. Export canvases as PNG/PDF from the canvas page (Share › Export) when handing to anyone outside Claude.
