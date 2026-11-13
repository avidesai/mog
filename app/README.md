# app — the Exact app (not yet created)

This folder will hold the expo/exact app: `app.contract`, `app.ts`, `app.json`, `app.tamber`, `app.test.contract`, `modules/apple/MogCapture.swift`, `strings/en.json`.

Create it from a source checkout of Exact, inside this repo:

```
bun <exact>/scripts/exact.mjs new ./app      # from the repo root; then cd app
bun exact.mjs pattern tabs                    # Today / Plan / Path / You
bun exact.mjs ios --prebuild                  # first build: 10–15 min
bun exact.mjs verify ios
```

Then follow `HANDOFF.md §4` (architecture) and `§6` (order). `strings/en.json` is generated from `core/copy/strings.json` by `node scripts/strings.mjs` — never hand-edit it.
