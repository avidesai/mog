# Privacy — what I know about this repo

- Capture: frames, depth, mesh live in memory for the 10-frame burst; `FaceFrame` arrays are dropped when the completion closure returns. Nothing is written. Debug builds have a landmark dump (`SpikeTools.swift`) to Documents — `#if DEBUG` only, and `tools/captures/` is gitignored.
- Retained on device: `ScanRecord` (named measurements as JSON, score, tier), `HabitRecord`, `UsageCounters`, `UserProfile` (UserDefaults). SwiftData store has complete file protection.
- Overlays: in-session `SessionStill` (projected anchor points, in memory, cleared on background); afterwards a schematic. No still image is kept even in memory in v1 (image: nil).
- Server (opt-in sync only): `scans.metrics_json` constrained to a flat map of numbers < 8 KB (`is_flat_scalar_map`). A scan insert requires an active `sync` consent (trigger). RLS on every table. `delete_everything()` hard-deletes and tombstones; consents outlive the account (ON DELETE SET NULL, 3-year window). All tested in `backend/supabase/tests/deletion_test.sql` on PostgreSQL 16 in CI.
- Phrasing: `phrase` Edge Function validator refuses any `value|score|percentile|z|landmarks|coords|image|pixels` key; output gated by schema + denylist; 204 on doubt.
- Analytics: closed allowlist in `Analytics.swift`; properties are categorical; transport is a no-op logger until PostHog.
- Age: 18+; attestation timestamp stored, never DOB. IL/TX/WA blocked from capture at launch via state attestation.
- Policies: drafts in `core/legal/`, site builder in `site/`, must be hosted before first capture (BIPA 15(a)).
