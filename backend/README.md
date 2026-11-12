# backend — Supabase

Postgres schema, RLS and the deletion path. Edge Functions come in week 7/8.

```
supabase/migrations/0001_init.sql   schema (users, consents, entitlements, scans, plans, habit tables,
                                    reference_dists, model_versions, deletion_queue), RLS, triggers, delete_everything()
supabase/tests/deletion_test.sql    the test the eng doc demands: guards + hard deletion, against the real schema
supabase/tests/shim_auth.sql        local-only stand-in for Supabase's auth schema (never apply to Supabase)
supabase/tests/run_local.sh         migrations + tests against any Postgres ≥ 14
```

**Verified** on PostgreSQL 16: migrations apply; `metrics_json` refuses arrays/objects/strings; a scan cannot be written without an active `sync` consent; RLS hides other users' rows; `delete_everything()` leaves zero user-owned rows, tombstones the profile, revokes consents and queues auth removal. CI runs this on every push (`.github/workflows/core.yml`, job `backend`).

**What the server can never hold:** there is no column for an image, landmark, mesh, embedding or depth map, and `scans.metrics_json` is constrained to a flat map of numbers under 8 KB.

## Edge Functions (to write)

| Function | Trigger | Does |
|---|---|---|
| `revenuecat-webhook` | RevenueCat → HTTP | Upserts `entitlements` (service role, verifies the webhook secret) |
| `process-deletions` | cron, hourly | For each `deletion_queue` row older than 24 h: delete `auth.users` (cascades the tombstoned profile), mark processed. Purge `consents` older than 3 years past user deletion. |
| `phrase` | app → HTTP (only if on-device Foundation Models fail) | Receives `{findings: [...categories], goals: [...]}` — never a score, value, image or coordinate; calls the LLM with the fixed schema at temperature 0; runs the denylist; returns text or 204 (client falls back to static copy) |

## Apply to a real project

```
supabase link --project-ref <ref>
supabase db push          # applies migrations/
```
Then set the Sign in with Apple provider in Auth settings. No other auth method.
