# Build plan — v1 in 12 weeks at 12–15 h/week

Rules-only scorer, habit layer in v1, profile capture pending spike 2. Budget $300–400. Dates assume a start on **Mon 17 Nov 2026**; shift everything if the start moves. Each week has a definition of done; if a week's done-criterion isn't met, the next week doesn't start — scope gets cut instead.

**What's already built (this repo):** data tables with citations, deterministic scorer + planner + habit engine with a test suite and golden fixtures, full copy deck, legal drafts, App Store listing and review notes, design system v7 and 28 screens. The iOS work below is porting and wiring, not inventing.

| Wk | Dates | Focus | Done when |
|---|---|---|---|
| 1 | 17–23 Nov | **Spikes 1 & 3 + account.** Pay the $99. Xcode project, SwiftUI, iOS 18 floor. ARKit `ARFaceAnchor` + MediaPipe Face Landmarker in one view; dump raw landmarks + pose + distance to JSON per frame. Capture yourself 10× across 3 sessions. Run `tools/` CV analysis on 10 candidate frontal metrics. | Per-metric CV computed for 10 metrics on real captures; ≥6 reach tier A/B. If fewer than 4 do, STOP and re-scope around skin/adiposity/grooming (eng doc, "The decision that gates everything"). |
| 2 | 24–30 Nov | **Spike 2 (profile) decision + port core.** Label 60–100 profile images (self + consenting friends, phone captures) with the 12 key points; fine-tune a tiny heatmap regressor on a pretrained backbone; measure landmark error. In parallel: port `mogcore` to Swift (`swift/MogCore`), load the same JSON, pass `fixtures/scoring_cases.json` to 1e-6. | Swift package passes fixtures. Profile go/no-go written down: ship in v1 or flag off to v1.1. |
| 3 | 1–7 Dec | **Capture subsystem.** Gates (yaw/pitch/roll/distance/luma/clipping/expression/occlusion/sharpness) live at preview rate; shutter disabled until all pass; 10-frame auto-capture; frame rejection + median + IQR. Gate chips + hints from `copy/strings.json`. | On-device, every gate demonstrably blocks capture; a clean capture yields a `MetricReading` set that `MogCore.score` accepts. Frames never written to disk (verify with a file-system audit). |
| 4 | 8–14 Dec | **Metric layer.** Pose de-rotation, perspective correction (TrueDepth), scale normalisation, the ~22 frontal metric functions. Appearance heads: ship skin evenness and adiposity as coarse 3-category outputs from simple image statistics + landmark geometry (no training) — spike 5's cheap path. Hairline/beard as manual onboarding toggles if the heads aren't ready. | `score` runs end-to-end on a live capture. Re-scan yourself 5× same session: score SD measured and logged. |
| 5 | 15–21 Dec | **Reveal → Results → Metric detail → Paywall.** Build from the canvas. Overlays drawn from the metric's `inputs` on the captured still (then the still is deleted — overlays are re-rendered from stored landmark *subsets* only while the result screen is open; decide and document). RevenueCat + Superwall wired; products `weekly_499`, `annual_3499_trial3d`, `lifetime_5999`. Free/Pro gating per the table. | Full first-session flow works on device: onboarding → consent → capture → reveal → results → paywall. Purchase works in sandbox. Restore works. |
| 6 | 22–28 Dec | **Habit layer.** Today, Task detail, Day complete, Streak save, Plan, Path, Progress. `HabitEngine` port + local persistence (SwiftData/SQLite, encrypted). Local-date handling per the spec. Scan windows gate the Scan button. Distress card wired to opens/rescan counters. (Holiday week — half capacity; this is the lightest UI week deliberately.) | All habit tests green in Swift; a week can be simulated by changing device date. |
| 7 | 29 Dec–4 Jan | **Backend + consent + deletion.** Supabase: schema from eng doc + habit tables, RLS, Sign in with Apple. Consent screen with versioned record. Sync toggle (off). Delete-everything path with an automated test against the real schema. Policies hosted on the domain (GitHub/Cloudflare Pages). State attestation gate for IL/TX/WA. | Delete test passes in CI. Policies live at stable URLs. Consent recorded with policy version. |
| 8 | 5–11 Jan | **Phrasing + Methodology + Settings + Share.** Try iOS 26 Foundation Models for on-device phrasing with the strict schema; denylist scan over output; static copy fallback. If quality/determinism fails, Edge Function proxy to a cheap cloud model behind a flag (≤$50). Methodology screen from copy deck. Share card composer (photo opt-in). | Every plan card renders with or without the model. Denylist render-time scan has a test that forces a hit and confirms fallback. |
| 9 | 12–18 Jan | **Consistency harness + fairness smoke + privacy audit.** 5+ people (friends; stratify sex and skin tone at minimum), 10 captures each across ≥3 sessions. Compute per-metric CV → overwrite `reliability_tier` in `metrics.json`; drop anything tier D; rebuild reference + fixtures; bump model version. MITM proxy run over a full session incl. crash + analytics; save the trace. | **Score SD ≤ 0.2 on the 10-point scale** (release gate). Zero face-derived egress in the trace. If SD > 0.2, week 10 becomes a second harness week and TestFlight slips. |
| 10 | 19–25 Jan | **TestFlight + review prep.** Internal TestFlight, then 10–20 external testers from the audience. Fix capture UX from gate-failure telemetry. Paywall gate checklist (terms visible, close control, restore). App Store listing, screenshots from the canvas screens with real data, review notes from `appstore/`. Submit for review early — expect TrueDepth questions. | Build in review. |
| 11 | 26 Jan–1 Feb | **Review buffer + seed panel.** Answer App Review. Meanwhile recruit the ~$100–150 seed rater panel (friends/testers) to validate the peer-rating pipeline design for v1.1 — no code yet, just the consent copy and the rating UI sketch. Founder-led content: "same face, 10 scans" video. | Approved, or on second submission with every objection answered. |
| 12 | 2–8 Feb | **Launch.** Phased release 10% → 100% over 3 days. Watch gate-failure telemetry, crash rate, re-scan frequency distribution, distress-card rate (aggregate only). Day-7: first retention and conversion read. | Live. First week's numbers written into the Project. |

## Spend tracker

| Item | Budget | When |
|---|---|---|
| Apple Developer Program | $99 | Week 1 |
| Domain | ~$15 | Week 7 |
| LLM API (only if on-device fails) | $0–50 | Week 8 |
| Seed rater incentives | $100–150 | Week 11 |
| Reserve | ~$50 | — |
| **Total** | **$264–364** | |

## Cut list, in order, if time runs out
1. Profile capture → v1.1 (flag). Removes CaptureProfile, 10 profile metrics, chin/convexity rules.
2. Share card composer → v1.1.
3. Cloud sync → v1.1 (consent copy already says "optional"; just hide the toggle).
4. LLM phrasing → static copy only (already the floor).
5. Progress screen deltas → show scans list only until week-4 data exists anyway.

**Never cut:** gates, consent, deletion test, denylist, MITM audit, the SD ≤ 0.2 gate, 18+.

## Weekly ritual (30 min, Sunday)
Run the test suite. Re-read the done-criterion for the week just finished. Write three lines into the Project README: what shipped, what slipped, what's cut. Check the spend tracker.
