# HANDOFF — Mog

Written 13 Nov 2026 for the Claude Code session taking this over. Paste this file, or just open the repo — `CLAUDE.md` points here. Read it top to bottom once; after that, `AGENTS.md` is the short version and the experts in `.agents/experts/` hold the detail per domain.

---

## 0. Where everything is

**The repo:** https://github.com/avidesai/mog — `main`, pushed 13 Nov 2026 with the full history. CI (`.github/workflows/`) runs on every push: the Python suite + strings-table check, the Postgres deletion test, the Node tests for the Edge Functions, `swift test` on macOS (allowed to fail until MogCore first compiles — then remove `continue-on-error`), and the policies-site deploy once the repository variable `POLICIES_BASE_URL` exists. **The repo was created public.** Nothing in it is secret (`Secrets.xcconfig` is gitignored; no keys anywhere), but the rules table, the copy deck and the legal drafts are the product — make it private unless you mean to open it.

```
HANDOFF.md  AGENTS.md  CLAUDE.md          ← you are here
app/         the Exact app — NOT YET CREATED; app/README.md has the exact commands; app/strings/en.json is generated
core/        engines (Python = spec, Swift port), data tables, copy deck, legal drafts, App Store assets, 12-week plan, tools
ios/         SwiftUI reference app (NEVER COMPILED — see §4). Capture + geometry code here is the seed of the Exact native module.
backend/     Supabase schema + RLS + tested delete_everything(); three Edge Functions (Deno) with Node-tested logic
site/        policies site builder (versioned URLs) + Pages workflow
design/      design system (tokens.json, components, brand book), 28 artboards as HTML, offline renders, bundled fonts
docs/        engineering design doc, design-language bible, foundation research, project index (snapshots of the live docs)
tools/       token generator, artboard renderer      scripts/   repo-level: strings.mjs (core copy → app/strings/en.json)
.agents/     skills (clean-copy, unslop) and four experts (scoring, privacy, capture, exact-ui)
.claude/     agent stubs that load the experts
```

**Live documents (edit these; `docs/*.md` are snapshots):**

| | URL | Notes |
|---|---|---|
| Engineering design doc | https://claude.ai/artifact/HoHrkAUy6ZoBmcjLv134sY | rev 20. Original body + three decision records at the end (11 Nov; 12 Nov build start; 12 Nov evening "noise finding"). Decision records supersede the body where they differ. |
| Design-language bible + UI kit | https://claude.ai/artifact/NRfuaHK1yQYLjjTTmN1orz | rev 17 + 11 Nov decision record (gamified-lite direction). |
| Design System "Mog" | https://claude.ai/artifact/Ud39Qbn4PiDgu5m1HJTLec | v7; source in `design/design-system/`. |
| Gamified Direction canvas — **the chosen 28 screens** | https://claude.ai/artifact/SkhqbXsYoAxQNjT2wJJE19 | v27; HTML in `design/screens-gamified/`; renders via `tools/render_screens.py`. |
| Original instrument canvas (superseded) | https://claude.ai/artifact/RU2rRYx5hzZ9a3xHTbGQ9k | `design/screens-instrument/`. Reference only. |
| Foundation research | `docs/foundation-research.md` | Metrics science, competitors, pricing, UX, marketing, legal. |
| Claude Project "Facial harmony" | (claude.ai) | Holds the same snapshots under `mog/`. |

---

## 1. What this is

An iPhone-first facial-harmony measurement app for the looksmaxxing audience (working name **Mog** — see §7, it's an open problem). Guided capture → on-device geometry → a deterministic score against published anthropometric norms, shown **with its uncertainty band** → an evidence-graded plan of self-directed habits → one habit mechanic (daily plan → streak → eight-week path → re-scans at weeks 4 and 8). Budget **$300–400 total**. Solo builder, 12–15 h/week.

The thesis, in one line: everyone else in this category uploads a selfie to a model and gets a different number each time; we measure, say how reliable each number is, say what the research actually supports, and never let a face leave the phone.

Invariants (tests enforce most of them; don't ship a change that breaks one):
- Images, depth, landmarks, meshes, embeddings never leave the device, are never persisted. Only named measurements can sync, opt-in.
- The score is a published-norm percentile with a band. The free score is the real score.
- Tier X (dangerous practices) never renders. Tier 3/4 (clinician/surgical) never become tasks. Every string passes the denylist.
- The streak counts days the plan was done, never scans. One repair a month, never purchasable.
- 18+. No colour ever encodes score quality. No XP, levels, badges, leagues.

---

## 2. State of each part

### core/ — done, tested (77 Python tests green)
- `data/metrics.json` 36 metrics with (mean, sd) per sex, citation key, direction, evidence grade, **provisional** reliability tier and `noise_sd`, `modifiable` flag. `data/references.json` — `verify: true` means the figure has not been checked against the paper. `data/rules.json` 30 human-authored rules with safety tiers, triggers, excludes, static copy. `data/denylist.json`. `data/composite_reference.json` generated by `tools/build_reference.py` (never hand-edit).
- `requirements.txt` (pytest, numpy) and `requirements-tools.txt` (markdown, playwright, fonttools for the site/render/font tooling).
- `mogcore/` scorer, planner, habit engine, denylist. Read `core/README.md` — **especially "The noise finding"**, the most important discovery so far (§3).
- `copy/strings.json` every UI string, keyed by screen, name-agnostic (`{app_name}`). `copy/voice.md`.
- `legal/` biometric retention/destruction policy, privacy policy, terms — drafts for counsel. `appstore/` listing + review notes. `plan/build-plan.md` 12-week plan.
- `tools/cv_analysis.py` (spike 1) and `tools/harness.py` (week 9: per-person test–retest, tier/noise writeback, tone/sex fairness smoke). Both self-test.
- `appearance/` cheap-path skin evenness and adiposity proxies, tested (incl. lighting and tone invariance).
- `swift/MogCore` — Swift port, same JSON, golden fixtures. **Not compiled** (no toolchain here).

### ios/ — written, never compiled, now **reference**
SwiftUI app with every v1 screen, 9 capture gates, ARKit-mesh geometry → 24 metrics, SwiftData store, purchases stub, analytics allowlist, measurement overlays, spike tools (vertex picker, landmark dump). Bundled fonts. XcodeGen `project.yml`. Per the owner's 13 Nov direction (§4) the product moves to expo/exact; this code's **capture and geometry layers are kept** as the native module, and the rest is a faithful reference of what every screen should do. Expect compiler nits on first build; `ios/README.md` lists what's wired vs stubbed.

### backend/ — done, verified on PostgreSQL 16
Schema, RLS, consent-gated scans, flat-scalar guard on `metrics_json`, `delete_everything()` with a real test; consents survive account deletion (3-year evidence window). Edge Functions `phrase` (LLM rewording, schema + denylist gated, 204 fallback), `process-deletions`, `revenuecat-webhook` — logic tested with Node. Not deployed; no Supabase project exists yet.

### site/ — done
`python site/build.py …` renders the three policies with versioned URLs; Pages workflow. Needs a domain (~$15). **Must be live before the first real capture** (BIPA public-policy requirement).

### design/ — done
Tokens, components, brand book; 28 artboards (`screens-gamified/`); `tools/render_screens.py` renders them offline with the real fonts and produces the seven App Store shots (`design/renders/store/`, also in `ios/fastlane/screenshots/`).

---

## 3. The three things you must know before changing anything

**3.1 The noise finding (12 Nov).** Simulated test–retest under tier-realistic noise gave a ~1.9-point per-person score SD under the original weighting — ten times the gate the eng doc set. Cause: coefficient of variation is the wrong reliability measure when a metric's population spread is itself small (symmetry index). Fix shipped as scoring **rules-1.1.0**: reliability weight r = 1/(1+(noise_sd/pop_sd)²), band includes between-session noise, calibration test. Now ~1.1 under the provisional noise table, ~0.55 at half that. Gate: median SD ≤ 0.6 on **measured** noise. The product consequence: **the band is the number.** Until week-1 captures measure real noise, do not promise precision anywhere in copy or marketing. `core/README.md` has the full account; the eng doc has the decision record.

**3.2 Nothing has run on a device.** All Swift was written without a compiler. Spike 1 (§6) is the first time any of it meets reality, and three things specifically need verifying on an iPhone: the Euler-angle sign conventions in `CaptureSession.pose`, the `.landscapeRight` buffer projection in `LumaStats`/`SkinEvenness`, and the `Heuristics` anatomical-point estimates on a real mesh.

**3.3 Everything downstream of `landmark_map.json` is provisional.** All 38 ARKit vertex indices are `null`; heuristics fill in at reduced confidence. The vertex picker exists to fill them. Reliability tiers and `noise_sd` are guesses until `harness.py --write-tiers` runs on real captures.

---

## 4. Direction change (13 Nov): build on expo/exact

The owner's call: from here, **rely heavily on [expo/exact](https://github.com/expo/exact)**. Read its `README.md`, `AGENTS.md`, `docs/start-here.md`, `docs/contract-for-agents.md`, `docs/agent-pitfalls.md`, `rules/RULES.md`, and the recipes listed in `.agents/experts/exact-ui/knowledge.md`. Exact is pre-1.0 and changes weekly; trust the checkout over anything written here.

What Exact gives us that fits unusually well: an agent-native loop (`verify ios`, ten agent ops, `clock` instead of sleeps, screenshots you must actually look at), `@exact/purchases` and `@exact/sign-in` (removes RevenueCat/Superwall from the budget), a permissions recipe that derives manifests from one grant line, `app.tamber` for brand tokens with `light-dark()`, content parts (`SummaryCard`, `RingProgress`, `StatBar`, `Badge`, `DoneMark`, `EmptyState`), `eas-ios`/`share` for distribution, and a philosophy — *write the web, ship the platform; an app that says less looks more at home* — that is close to the bible's "one light register, no decoration without purpose".

What it costs us: TypeScript in `app.ts` cannot import npm code (fine — MogCore's port is dependency-free); runtime-level camera access is out for v1, so **capture is a Swift native view** (`docs/recipes/native-views.md`: "a view needing a platform API (a map, the camera) is a Swift view"); our chunky lipped buttons and custom nav are *tells* under Exact's philosophy and go; custom fonts are an open spike; first iOS build is 10–15 minutes; no API stability.

**Architecture on Exact**

```
app.contract        screens: onboarding(3) → consent → today / plan / path / you tabs; results, metric detail, paywall as routes/sheets
app.ts              data module: TS port of MogCore (score, plan, habit) — must pass core/fixtures/scoring_cases.json to 1e-6
                    resources: readings ← mog-capture native module; purchases ← @exact/purchases; identity ← @exact/sign-in
                    sqlite grant for scans/habit; secrets grant for the Supabase token; net.fetch only to Supabase + phrase
app.tamber          brand tokens from design/design-system/tokens.json (paper, ink, accent #2E5BFF, positive, flame, finish, line, raised)
app.test.contract   the flows: first session (onboarding→consent→capture→reveal→results→paywall), a day, a streak save, a scan window
modules/apple/      MogCapture.swift — ExactModule + ExactNativeFactory for <mog-capture>: ARKit session, gates, 10-frame median,
                    GeometryPipeline → readings; emits readings as a message; props: pose ("frontal"/"profile"), beard, hairline
                    (port of ios/Mog/Capture + ios/Mog/Geometry; keep the privacy invariants verbatim)
strings/en.json     generated from core/copy/strings.json (write a 20-line script; keep the JSON the source of truth)
```

**Design-system reconciliation.** Keep: the palette as tamber tokens, the five colour-meaning rules (blue = measurement, green = done, amber = streak flame only, gold = week-8 finish only, nothing encodes score quality), one light register with only the capture viewport dark, evidence badges as `Badge`, the score band as a content part, the path as content. Drop: 4 px lips, custom tab/nav chrome, any styled platform control. Decide fonts in the spike; if Exact's answer is the system font, that is the answer. Re-render the 28 artboards in your head as "same screens, platform chrome" — the information architecture and copy do not change.

**Fallback.** If Exact cannot ship an App Store build by week 10 (check `docs/recipes/eas-ios.md` and `porting-and-release.md` early), the SwiftUI app in `ios/` ships v1 and Exact becomes v1.1. Decide this by the end of week 3, not week 10.

---

## 5. Copy and code quality — use these, every time

- **Copy:** `.agents/skills/clean-copy/SKILL.md`, adapted from https://paste.rachel.systems/ukogokijaz.md. The ladder: should this string exist → does the label need to exist → is it pre-empting a worry → rewrite or delete the element. Run it **before** `core/copy/voice.md`. The deck has had only three cuts so far; **a full ladder pass over `core/copy/strings.json` and the 30 rule bodies in `rules.json`, read on the rendered screens, is pending.** Privacy statements survive rung 3 only at the point of capture and deletion.
- **Code:** `.agents/skills/unslop/SKILL.md`, adapted from vercel-labs/ui's `ui-sdk-unslop`. Last step of every change. The privacy-invariant comments are the exception and should stay short.
- **Experts:** `.agents/experts/{scoring,privacy,capture,exact-ui}` — `expert.md` (who), `knowledge.md` (what it knows about this repo; fix it when wrong), `decisions.md` (settled; never re-raise). Pattern from vercel-labs/ui. Claude Code loads them as `.claude/agents/<name>-expert.md`. Run the privacy expert on any diff touching capture, storage, network or analytics; the scoring expert on anything that moves a number.
- **vercel-labs/ui itself** (`@ui-sdk/*`): headless behaviours + ARIA for web UIs, zero deps, agent-operable (`snapshot`, `act`). It does not apply inside Exact (no npm in `app.ts`, and Exact renders its own DOM). It **does** apply to every web surface we build: the marketing/landing page, the policies site if it grows interaction, and the v1.1 peer-rating web tool. Install the skill with `npx skills add vercel-labs/ui --skill ui-sdk` when you start one of those. Its `AGENTS.md` and `contributing/` are also the model for how this repo's agent guidance is structured.

---

## 6. What's next, in order

1. **Check CI on the push** (Actions tab). Python, Postgres and Node jobs should be green; `swift test` is allowed to fail until MogCore first compiles — fix forward, never edit a fixture to pass.
2. **Set up Exact** (source checkout, `bun scripts/exact.mjs setup`), `exact new mog-app` inside this repo as `app/`, run the `tabs` pattern, get `verify ios` green on the placeholder. Decide fonts.
3. **Port MogCore to TypeScript** in `app/app.ts` (or `app/core/*.ts` imported locally): registry, scoring, planner, habit, denylist. Gate: `core/fixtures/scoring_cases.json` to 1e-6 and the habit tests' scenarios. Write `scripts/strings.mjs` to generate `strings/en.json` from `core/copy/strings.json`.
4. **Spike 1 — the go/no-go — on a real iPhone** ($99 developer account). Build `modules/apple/MogCapture.swift` from `ios/Mog/Capture` + `ios/Mog/Geometry` (or run the SwiftUI app's Debug tools first, whichever gets a mesh on screen sooner). Pick the 38 vertex indices with the vertex picker. Ten captures × three sessions. `python core/tools/cv_analysis.py captures/`, then `harness.py --write-tiers`. **≥ 6 frontal metrics at tier A/B → go; < 4 → re-scope around skin/adiposity/grooming.** Also read the mesh-derived profile angles' CV: if good, spike 2 (separate profile capture) is cancelled.
5. **Rebuild reference + fixtures, bump model version** once real `noise_sd` lands; re-read the test–retest SD. Lead the reveal with band + tier if the SD is near 1.
6. **Screens in Contract**, in first-session order, each with an `app.test.contract` flow and a looked-at screenshot: onboarding → consent → capture (native view) → processing → reveal → results → metric detail → paywall (`@exact/purchases`) → Today → task detail → day complete → streak save → plan → path → progress → settings → methodology. Full clean-copy ladder pass as each screen comes up.
7. **Backend**: create the Supabase project, `supabase db push`, deploy the three functions, Sign in with Apple via `@exact/sign-in`, hosted policies on the domain, replace every `example.invalid`.
8. **Week 9**: `harness.py` with 5+ people stratified by sex and tone; MITM audit of a full session; gate ≤ 0.6.
9. **TestFlight → review → phased launch** per `core/plan/build-plan.md` (dates assume a 17 Nov start; re-plan around the Exact ramp).

---

## 7. Open decisions (owner's)

- **App name.** "Mog" collides with Mogged/MogMax and is itself on our denylist (comparative vocabulary). Copy is name-agnostic; the listing and policies use `{app_name}`.
- **Profile capture in v1** — now depends on the week-1 CV of the mesh-derived profile angles.
- **Exact vs SwiftUI for v1** — Exact by default (§4); fallback decision by end of week 3.
- **Font** — spike in Exact.

---

## 8. Numbers to keep straight

36 metrics (22 scorable) · 30 rules · 7 goals · 28 screens · 77 Python tests · tiers LTN <45 / MTN 45–65 / HTN 65–85 / Chadlite 85–97 / Chad ≥97 · band min ±0.15 · gate median SD ≤ 0.6 measured (≤ 1.2 provisional) · prices $4.99 wk / $34.99 yr (3-day trial) / $59.99 lifetime · free tier = real score + tier + strongest + most-improvable + streak/plan · budget $300–400 (spent so far: $0).
