---
name: clean-copy
description: Write or review user-facing interface text (labels, hints, empty states, toasts, confirmations, buttons) by first asking whether the text should exist at all, then tightening what survives. Use on any change to core/copy/strings.json, rule copy in core/data/rules.json, App Store text, or policy pages.
source: https://paste.rachel.systems/ukogokijaz.md (adapted; the ladder is theirs, the Mog-specific notes are ours)
---

# Clean copy

Most weak interface copy is not badly worded. It should not be there. The first question is never "how do I say this better" but "should this be said".

## The ladder — apply in order; the first rung that applies deletes the string

1. **Does it need to surface at all?** Text that answers a question the user would never have asked *plants* the question. A caption saying a preview is "at true profile size" makes them wonder whether it isn't.
2. **Does the label need to exist?** A caption is justified only when the value is meaningless without it. A unit beside a bare number stays. A caption that repeats its label goes.
3. **Is it pre-empting a worry the user never had?** Copy that rules out a failure rather than describing behaviour: reassurance about a fixed bug, a defence of a design choice. The fix for a fixed bug is the fix, not a caption about the fix.
4. **Rewrite, or delete if nothing is left.** Cut the clause, not the word. If nothing remains, remove the element, not just its text — never leave a stub.

## What survives

- A real consequence shown at the point of choice ("Unsynced measurements will be lost").
- A compatibility or scope fact the user cannot see for themselves ("Profile measurements need a profile capture").
- What an empty state means and what to do next.
- Units, scale or format for a bare value.

A correct consequence can stay while its permission-style clause ("only use this when…") is cut.

## Working style

- Judge each string **in context** with its neighbouring label, value and button. Redundancy is invisible in isolation — read it on the rendered screen (`python tools/render_screens.py`), not in the JSON.
- Cut whole clauses rather than swapping words.
- Report a batch as `file:line` → current string → rewrite or **cut** → the rung it failed. Leave passing copy alone.
- A string that matters only in a rare state should appear only in that state.

## Mog-specific

- Everything also passes `core/copy/voice.md` and the denylist (CI). The ladder runs *first*; voice polish on a string that should not exist is wasted.
- Privacy statements are the exception to rung 3 **only** at the point of capture and deletion (consent screen, processing footnote, delete confirmation). They are consequences shown at the point of choice. Everywhere else, a privacy reassurance is rung 3: cut it.
- An empty string in `strings.json` means the element is not rendered. Remove the element in the view too.
- Done in this spirit so far: `today.all_done_body` (cut), `plan.intro` ("Nothing here is generic" cut), `streak.repair_note` (trimmed). The rest of the deck has **not** had a full ladder pass — see HANDOFF.md.
