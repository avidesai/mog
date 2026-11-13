---
name: unslop
description: Remove generated-looking code from a diff without changing behaviour — comments that restate the code, filler doc comments, defensive checks for impossible cases, one-caller helpers, vague names, hedge words in prose. Run as the last step of any change in this repo (Swift, TypeScript, Python, Contract, Markdown).
source: adapted from vercel-labs/ui .agents/skills/ui-sdk-unslop
---

# Unslop

Scope is the diff against the base unless given files. Behaviour never changes: the same tests pass before and after; nothing public is renamed.

## What goes

- **A comment that says what the next line does.** Delete it; if the line is unclear without it, rename something.
- **A comment on every declaration.** Keep only the one that stops a reader getting the code wrong.
- **A comment that explains the design** at length. Keep the one fact the code cannot show, in a line.
- **A comment longer than three lines.** Cut to the reason; more goes in a doc or a test name.
- **History or task narration.** "Now we", "Updated to", "As requested", "Fixed the bug where". Git holds history.
- **Section banners.** Split the file if it needs signposts.
- **Hedges and sales words** in comments, docs and copy: robust, seamless, comprehensive, simply, just, easily, ensure, leverage, utilize, note that, it's important to, honestly, genuinely. Cut the word; if nothing is left, cut the sentence.
- **Defensive checks the types rule out.** `guard let` on a non-optional, `?? []` on a value never nil, `try?` around code that cannot throw.
- **A cast or force-unwrap with no reason.** Fix the type or say why in a line.
- **One-caller helpers and rename-only wrappers.** Inline them unless the name explains something the call cannot.
- **Names that say nothing.** `data`, `result`, `temp`, `flag`, `item2`.
- **Options nobody passes**, parameters with one value, config objects for one setting.
- **Logs, probes, commented-out code.**

## What stays

- A *why* in three lines or fewer: a platform bug, a spec rule, a trade-off, a link to the test that pins it.
- Doc comments on public API that say what the reader cannot see: default, unit, when it fires, what happens on change.
- In this repo specifically: the privacy-invariant comments at the top of `GeometryPipeline.swift`, `Overlay.swift`, `Store.swift` and the backend migration. They are the audit trail, not narration. Keep them short.

## Steps

1. List what you will change, by file, before touching anything.
2. Change it.
3. Run the tests that reach the files (`python -m pytest -q` in core; `swift test` in core/swift/MogCore; `node --experimental-strip-types --test backend/supabase/tests/functions.test.mjs`; `bun exact.mjs verify` once the Exact app exists).
4. Delete each remaining comment in the diff and reread. If it still reads right, leave it deleted.
