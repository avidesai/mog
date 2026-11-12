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

## Edge Functions

Written; pure logic in each `logic.ts` is tested with Node (`node --experimental-strip-types --test tests/functions.test.mjs`); the Deno `index.ts` wrappers are deployed with `supabase functions deploy <name>`.

| Function | Trigger | Does |
|---|---|---|
| `revenuecat-webhook` | RevenueCat → HTTP | Upserts `entitlements` (service role, verifies the webhook secret) |
| `process-deletions` | cron, hourly | For each `deletion_queue` row older than 24 h: delete `auth.users` (cascades the tombstoned profile), mark processed. Purge `consents` older than 3 years past user deletion. |
| `phrase` | app → HTTP (only if on-device Foundation Models fail) | Receives goal ids, rule ids, static copy and finding *categories* — the validator refuses any value, score, landmark or coordinate; calls the model at temperature 0 with a fixed system prompt; enforces same-ids-same-order, length caps, no exclamation marks, no dose/weight/calorie figures, then the denylist; returns text or **204** (client falls back to static copy) |

## Apply to a real project

```
supabase link --project-ref <ref>
supabase db push          # applies migrations/
```
Then set the Sign in with Apple provider in Auth settings. No other auth method.


Secrets per function: `ANTHROPIC_API_KEY`, `PHRASE_MODEL` (phrase); `CRON_SECRET` (process-deletions); `REVENUECAT_WEBHOOK_SECRET` (webhook). `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected by the platform.

**Consent retention:** `consents.user_id` is `ON DELETE SET NULL` so the records survive account deletion for the 3-year evidence window while everything else cascades. The test simulates the auth-user removal and checks exactly that.
