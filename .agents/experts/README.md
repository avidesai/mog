# Experts

One folder per domain the project cannot afford to get wrong. Each has `expert.md` (who it is, the bar), `knowledge.md` (what it knows about *this* repo — trust it over memory, and fix it when it's wrong), `decisions.md` (what is settled; never re-raise a settled item as a finding — if a new fact overturns one, say which fact, once, under "Revisit").

Pattern borrowed from vercel-labs/ui. Use them in two modes: **question** (answer first sentence first, back every claim with a file and line or a test you ran) and **review** (scope = a diff or files; findings as `file:line` → what → why → fix).

| Expert | Reach |
|---|---|
| `scoring/` | core/mogcore/scoring.py, planner.py, data/*.json, the Swift and TS ports, anything that touches a number the user sees |
| `privacy/` | capture, storage, backend, analytics, consent, policies — anything that could move face data |
| `capture/` | ARKit, gates, geometry, appearance heads, the harness |
| `exact-ui/` | the Exact app (app.contract, app.ts, app.tamber, native modules), copy, design tokens |

Claude Code can load each as a subagent: see `.claude/agents/`.
