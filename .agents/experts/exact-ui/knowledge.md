# Exact UI — what I know (verified 13 Nov 2026 against expo/exact 513d10f; it moves weekly)

- Exact = Contract (`app.contract`: view/state/actions/resources/mutations/derive) + data module (`app.ts`, TypeScript on Hermes; grants for net/files/sqlite/secrets) + `app.json` manifest + optional `app.tamber` brand tokens + `modules/apple/*.swift` native modules and native views.
- **The data module can import pure-JS npm packages** (ESM or CommonJS) and its own `.ts`; anything needing Node, the DOM or a native addon is refused by name. (Earlier notes said "types only"; the checkout's `docs/start-here.md` says otherwise.) The MogCore port stays dependency-free regardless. `Date.now()` and randomness are refused in the data module: time comes in as an argument.
- **Strings:** `t("key", name=value)` reads `strings/<locale>.json`; keys must be literals, and keys and placeholders are checked at compile time. Our dotted keys (`today.title`) work as they are. A string with `{app_name}` needs `app_name=` passed at the call.
- **Fonts:** bundled fonts are supported: `font "Inter Tight"` with `400 = "assets/….ttf"` faces at file scope, then `font-family=`. Files go in `app/assets/`. The philosophy still says type is the platform's; a custom family is a deliberate brand choice, not a default.
- **Camera:** `@exact/camera` (viewfinder + still photos behind `device.camera`) exists but hands no frames to code, so it cannot replace ARKit. Capture stays a Swift native view (`docs/recipes/native-views.md`): hyphenated tag in `app.json` `modules`, `ExactModule` + `ExactNativeFactory`, string props, events `message/press/change/load`, time via `context.frames`/`context.after` (never timers, so `clock` works).
- Native modules (`docs/recipes/native-module.md`): `app.ts` calls `native.call({op:…})` / `native.watch`; a resource that reads native keeps its answer across launches.
- Batteries: `@exact/purchases`, `@exact/sign-in`, `permissions` (one grant line + a purpose key in `strings/en.json`), `theme`/`tamber`, `tabs`, `navigation-stack`, `grouped-form`, `persisted-setting`, `numeric-readout`, `motion`, `eas-ios`, `mobile-build`, `content-design` parts (`SummaryCard`, `RingProgress`, `StatBar`, `Badge`, `DoneMark`, `EmptyState`, `RoundButton`).
- Symbols are roles (`symbol:home`, `list`, `calendar`, `person`, `camera`, …; `contract vocab symbol` lists them). `symbol:sf/<name>` draws on Apple only and is blank on the web; for anything else, declare an icon in `app.tamber` with an SF name and an SVG.

- **Network the app makes on its own:** Exact's signed update delivery has installed Apple apps check for update bundles every 15 minutes while active (`deploy` in `app.json`, `deploy.check.interval`). It carries no face data, but the week-9 MITM audit will see it. Decide with the privacy expert whether v1 ships with delivery on.

## The loop on this repo

- Exact lives at `../ext/exact` beside the repo (the app's `exact.mjs` looks at `../../ext/exact` from `app/`; `EXACT` overrides).
- `bun exact.mjs contract build app.contract --json --errors-only` → `[]`. `bun exact.mjs contract fmt app.contract` before committing (one attribute per line once a line is long).
- `bun exact.mjs verify web` runs on Linux: tests, light/dark at two widths, reload, relaunch, and the largest text size. The first build takes about 3 minutes (the compiler), later ones about 10 s.
- **`verify ios` and `agent ios` need macOS.** A Linux cross build needs the Xcode 27.1 SDK (`xtool sdk install --slim Xcode_27.1.xip`, which needs an Apple download), Swift 6.4.2, LLVM 23 and rcodesign. None of that is in the cloud container.
- Container workarounds: the Hermes installer bundles its own TLS roots and fails behind the agent proxy, so serve the archive locally and set `HERMES_LEAN_SYS_MIRROR`. Exact pins Playwright Chromium 1248, so set `CHROME=/usr/bin/google-chrome`. Set `EXACT_FEEDBACK=0` so no feedback note goes to Expo.
- Web drawing of the native tab bar: each tab's symbol sits at the left, above a centred label (the tabs pattern does it too); iOS swaps in UITabBar. Leave it unstyled. With four tabs, the bar overflowed at the largest text size until each tab `button` got `min-width=0`.

## Philosophy constraints that collide with our design system
Controls, bars, type and dark mode are the platform's; emphasis is a *part*, not paint on a control; "leave the rest unsaid". Our chunky lipped buttons are therefore *tells*. Brand survives through `app.tamber` tokens (paper, accent #2E5BFF, positive, flame amber, finish gold) and content parts.
