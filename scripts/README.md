# scripts: repo-level

- `sync-app.mjs`: `core/copy/strings.json` → `app/strings/en.json` (Exact strings table) and `core/data` + the golden fixtures → `app/data/`. Exact bundles nothing outside `app/`. `--check` for CI.

Area-specific tools live beside their area: `core/tools/` (reference table, fixtures, spike analysis, week-9 harness), `tools/` (design tokens → Swift, artboard renders), `site/build.py`, `backend/supabase/tests/run_local.sh`, `core/swift/MogCore/sync-data.sh`.
