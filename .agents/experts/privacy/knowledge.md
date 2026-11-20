# Privacy: what I know about this repo

- Capture: frames, depth, mesh live in memory for the 10-frame burst; `FaceFrame` arrays are dropped when the completion closure returns. Nothing is written. The landmark dump (`ios/Mog/Debug/SpikeTools.swift`) writes raw vertices to Documents; it lives in the dev-only spike tools app (`com.avidesai.mog.spike`), `#if DEBUG` only, and must never be added to the Exact app. The dump folder is excluded from device backups and written with complete file protection; `captures/` is gitignored at any depth. The spike tools app has no consent screen or region check (the deleted SwiftUI screens put both in front of it), so it is for the developer's own face until consent for other people is handled.
- Retained on device: see the Exact app below. The SwiftUI store, overlays and analytics were deleted with the screens on 20 Nov (last at `d674aa6`).
- Server (opt-in sync only): `scans.metrics_json` constrained to a flat map of numbers < 8 KB (`is_flat_scalar_map`). A scan insert requires an active `sync` consent (trigger). RLS on every table. `delete_everything()` hard-deletes and tombstones; consents outlive the account (ON DELETE SET NULL, 3-year window). All tested in `backend/supabase/tests/deletion_test.sql` on PostgreSQL 16 in CI.
- Phrasing: `phrase` Edge Function validator refuses any `value|score|percentile|z|landmarks|coords|image|pixels` key; output gated by schema + denylist; 204 on doubt.
- Analytics: the Exact app has none, and `app.ts` has no net grant.
- Age: 18+; attestation timestamp stored, never DOB. IL/TX/WA blocked from capture at launch via state attestation.
- Policies: drafts in `core/legal/`, site builder in `site/`, must be hosted before first capture (BIPA 15(a)).

## The Exact app (from the 20 Nov review of the first storage code)
- `app/app.ts` keeps scans (named readings: value, confidence, iqr, occluded per metric), habit state, goals and time budget in `app:/data/mog.json`. Its grants are read and write on that file, and the camera. No net grant. Onboarding answers and the consent record are `persist` states (UserDefaults on Apple). `afterWipe` resets every one of them; the wipe test reloads and checks each, so add any new persisted state to both.
- Consent records `consentedAt` (epoch ms) and `consentPolicy` (policy version). A version change asks again before the next capture (`consentCurrent`). Withdrawing clears consent and keeps the measurements. "Not now" clears a standing consent too, and `consentCurrent` is false for a restricted region.
- The IL/TX/WA exclusion is a "Where you live" answer on the about screen. "Illinois, Texas or Washington" shows `consent.state_block_*` and no consent control.
- `resource app` is `transient`: the runner never keeps the view's score and readings outside `app:/data`. Call `<mog-capture>` from a mutation, never a resource source; a resource that calls `native.call` keeps its answer across launches.
- `<mog-capture>` (app/modules/apple) sends only `gates <mask> <hint>`, `aborted <i>`, `unsupported`, `denied` and `readings <json>`; `GeometryPipeline.json` writes finite `{value, confidence, iqr}` per metric id and nothing else. `saveScan` keeps registry metric ids with finite numbers (confidence clamped to [0,1], iqr ≥ 0). The capture view renders only while consent is current; withdrawing resets the capture and nothing is saved (tested).
- Readings live in the `captured` state only while the capture measures. `advance` discards them on any tick where the capture is not the top screen or consent is not current; a save, a failed save, "Not now", withdraw and Delete everything all call `resetCapture()` (tested: closing mid-measure, closing a re-scan, the wipe).
- **Ship gates, open:**
  - Exact sets no file-protection class on `app:/data`, and an Exact app cannot declare entitlements yet (Exact issues/20261113-ios-app-cannot-declare-entitlements-or-plist-keys.md). Set `NSFileProtectionComplete` on the data directory from `modules/apple` before release (policy §8).
  - The week-9 harness captures 5+ other people with the landmark dump, which has no consent or region step. Decide how their consent is taken before anyone else is captured.
  - No build reaches a real person until `<mog-capture>` compiles with the iOS host and the spike-1 device checks pass (core/plan/spike-1.md).
  - Run the network-interception audit on the first iOS build with `<mog-capture>` and keep the trace (policy §4).
  - Add an app-level `PrivacyInfo.xcprivacy` (UserDefaults behind `persist` is a required-reason API) before App Store submission.
  - `consent.point_policy` must become a link to the hosted policy (BIPA 15(a)) before the first real capture.
  - `consent.p1`/`p4`, `processing.footnote` and `methodology.privacy_body` are true only while `app.ts` has no network grant. Sync (step 7) must revisit them, bump `policyVersion` and ask again.
  - Before the policy is hosted, reconcile the draft with the Exact app: §10 says "Every other feature of the app is available" (a restricted resident cannot get past consent), and §3 and §6 describe a server-held consent record (the app keeps it on the phone only, and Delete everything erases it). `privacy-policy.md` also lists PostHog analytics, and the Exact app has none.
- **Closed:** `deploy.store.ios` is "0" in app.json (keep it when anything touches `host`).
