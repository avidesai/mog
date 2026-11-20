# Privacy — what I know about this repo

- Capture: frames, depth, mesh live in memory for the 10-frame burst; `FaceFrame` arrays are dropped when the completion closure returns. Nothing is written. Debug builds have a landmark dump (`SpikeTools.swift`) to Documents — `#if DEBUG` only, and `tools/captures/` is gitignored.
- Retained on device: `ScanRecord` (named measurements as JSON, score, tier), `HabitRecord`, `UsageCounters`, `UserProfile` (UserDefaults). SwiftData store has complete file protection.
- Overlays: in-session `SessionStill` (projected anchor points, in memory, cleared on background); afterwards a schematic. No still image is kept even in memory in v1 (image: nil).
- Server (opt-in sync only): `scans.metrics_json` constrained to a flat map of numbers < 8 KB (`is_flat_scalar_map`). A scan insert requires an active `sync` consent (trigger). RLS on every table. `delete_everything()` hard-deletes and tombstones; consents outlive the account (ON DELETE SET NULL, 3-year window). All tested in `backend/supabase/tests/deletion_test.sql` on PostgreSQL 16 in CI.
- Phrasing: `phrase` Edge Function validator refuses any `value|score|percentile|z|landmarks|coords|image|pixels` key; output gated by schema + denylist; 204 on doubt.
- Analytics: closed allowlist in `Analytics.swift`; properties are categorical; transport is a no-op logger until PostHog.
- Age: 18+; attestation timestamp stored, never DOB. IL/TX/WA blocked from capture at launch via state attestation.
- Policies: drafts in `core/legal/`, site builder in `site/`, must be hosted before first capture (BIPA 15(a)).

## The Exact app (from the 20 Nov review of the first storage code)
- `app/app.ts` keeps scans (named readings: value, confidence, iqr, occluded per metric), habit state, goals and time budget in `app:/data/mog.json`. Its only grants are read and write on that file. No net grant. Onboarding answers and the consent record are `persist` states (UserDefaults on Apple). `afterWipe` resets every one of them; the wipe test reloads and checks each, so add any new persisted state to both.
- Consent records `consentedAt` (epoch ms) and `consentPolicy` (policy version). A version change asks again before the next capture (`consentCurrent`). Withdrawing clears consent and keeps the measurements.
- The IL/TX/WA exclusion is a "Where you live" answer on the about screen. "Illinois, Texas or Washington" shows `consent.state_block_*` and no consent control.
- `resource app` is `transient`: the runner never keeps the view's score and readings outside `app:/data`. Call `<mog-capture>` from a mutation, never a resource source; a resource that calls `native.call` keeps its answer across launches.
- **Ship gates, open:**
  - Exact sets no file-protection class on `app:/data` (default: readable after first unlock). Policy §8 promises complete protection. Set it, by entitlement or a small native module on the data directory, when `host.ios` is added.
  - When `host.ios` is added, set `deploy.store.ios: "0"`, or update checks start (Exact reference.md:1427).
  - Capture is a stand-in that saves a fixture face. No build reaches a real person (share, TestFlight) until `<mog-capture>` replaces it.
  - `consent.point_policy` must become a link to the hosted policy (BIPA 15(a)) before the first real capture.
  - `consent.point_cloud` and `point_delete` describe sync that doesn't exist yet. Revisit them with the backend (step 7).
