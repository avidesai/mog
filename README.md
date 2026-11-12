# mog

iPhone-first facial-harmony measurement app for the looksmaxxing audience. Working name. Guided capture → on-device geometry → deterministic score against published norms, with a stated band → evidence-graded plan → one habit loop (streak, eight-week path, scans at weeks 4 and 8).

```
core/      deterministic engines — Python reference (test suite in core/tests) + Swift port (MogCore), shared JSON tables,
           copy deck, legal drafts, App Store assets, 12-week build plan
ios/       the app: SwiftUI, iOS 18, ARKit mesh capture, depends on core/swift/MogCore
backend/   Supabase schema, RLS, tested delete_everything(); Edge Functions
site/      public policies site (versioned URLs), GitHub Pages workflow
design/    design system (tokens, components, brand book) and the 28 v1 artboards as HTML
docs/      engineering design doc, design-language bible, foundation research, project index
tools/     token generator; spike analysis lives in core/tools/cv_analysis.py
```

## Start here

1. `docs/index.md` — what's decided, what's open, where the live Claude docs are.
2. `core/plan/build-plan.md` — the 12-week plan with a done-criterion per week. Week 1 is the go/no-go spike.
3. `ios/README.md` — how to generate the Xcode project and what's wired.

## Run the core

```
cd core && python -m pytest -q
python -m mogcore.cli score fixtures/example_scan.json
```

## Invariants (the tests enforce these; don't ship a change that breaks one)

- Images, depth data and landmarks never leave the device. Only named measurements can sync, opt-in.
- The score is a published-norm percentile with a band; the free score is the real score.
- Tier X never renders. Tier 3/4 never become tasks. Every string passes the denylist.
- The streak counts days the plan was done, never scans. One repair a month, never purchasable.
- 18+. No colour ever encodes score quality.

Private. © Avi Desai.
