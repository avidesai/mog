# app — the Exact app

`app.contract` (view), `app.ts` (data module), `app.test.contract` (tests), `app.json` (manifest). `strings/en.json` is generated from `core/copy/strings.json` by `node scripts/strings.mjs`; never hand-edit it. Views read it with `t("screen.key")`.

## Setup

The app finds Exact at `../../ext/exact`, so clone it next to this repo, or point `EXACT` at your checkout:

```
git clone https://github.com/expo/exact.git ../ext/exact     # from the repo root
bun ../ext/exact/scripts/exact.mjs setup
```

On Linux behind a TLS-intercepting proxy, the Hermes installer rejects the proxy's CA (it bundles its own roots). Download the archive `setup` names with curl, serve its folder locally, and rerun with `HERMES_LEAN_SYS_MIRROR=http://127.0.0.1:<port>`; the installer checks the archive's digest either way. If the pinned Playwright Chromium is missing, set `CHROME` to a Chrome binary.

## Loop

```
cd app
bun exact.mjs contract build app.contract --json --errors-only   # [] = clean
bun exact.mjs verify web                                          # any OS; look at .exact/verify/*.png
bun exact.mjs ios --prebuild && bun exact.mjs verify ios          # macOS with Xcode 27.1+
```

`verify ios`, `agent ios` and the simulator need macOS. Linux can cross-build an iOS bundle, but only with the Xcode 27.1 SDK extracted by xtool, plus Swift 6.4.2, LLVM 23 and rcodesign.

Then follow `HANDOFF.md §4` (architecture) and `§6` (order).
