# Mog — agent guide

Start with `HANDOFF.md` once. Then this is the standing guide.

## What this is
iPhone-first facial-harmony measurement app. Guided capture → on-device geometry → deterministic score against published norms **with a band** → evidence-graded plan → one habit loop. Budget $300–400. Being rebuilt on **expo/exact** (`app/`, once created); `ios/` is the SwiftUI reference and the seed of the capture native module; `core/` is the spec and the data.

## Rules
- **Verify by running.** `python -m pytest -q` in `core/`; `swift test` in `core/swift/MogCore`; `node --experimental-strip-types --test backend/supabase/tests/functions.test.mjs`; `backend/supabase/tests/run_local.sh` against Postgres; `bun exact.mjs verify ios` for the app, and look at every screenshot.
- **The Python engines are the spec.** Any port (Swift, TS) must reproduce `core/fixtures/scoring_cases.json` to 1e-6. Never edit a fixture to make a port pass. Any change that moves a score bumps the model version and regenerates `composite_reference.json` + fixtures.
- **Privacy invariants are not negotiable.** No frame, depth map, landmark, mesh, embedding or projected point is persisted, synced or sent. Run the privacy expert on any diff touching capture, storage, network or analytics.
- **Copy:** every string lives in `core/copy/strings.json`; run `.agents/skills/clean-copy` (should it exist?) before `core/copy/voice.md`; the denylist runs in CI. Fix the string, never the list.
- **Code:** finish every change with `.agents/skills/unslop`. Comments say why, in three lines or fewer; the privacy audit-trail comments stay.
- **Experts** in `.agents/experts/` (scoring, privacy, capture, exact-ui): read `knowledge.md` and `decisions.md` before working in their domain; never re-raise a settled decision as a finding; fix `knowledge.md` when it is wrong.
- **Exact:** trust the checkout over anything written here (pre-1.0, moves weekly). Platform chrome wins over our design system; brand lives in `app.tamber`.
- **Data tables** (`core/data/*.json`) are human-authored and versioned. `composite_reference.json` is generated. Reliability tiers and `noise_sd` are provisional until `core/tools/harness.py --write-tiers` runs on real captures.
- **Commits** are conventional, lowercase subject, and end with the attribution lines in the session's system reminder if one is present.
- **Delete; don't deprecate.** No compat shims before 1.0.

## Where things are
`HANDOFF.md §0` has the map and every live document link.
