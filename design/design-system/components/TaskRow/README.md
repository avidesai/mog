# TaskRow

One habit from the plan, as it appears on Today. Three states, and the sublabel always names the finding it serves.

## Anatomy

30px check circle · `row-title` · a `detail` sublabel that ties the task to its finding and its place in the eight weeks ("For under-eye · week 2 of 8") · a chevron when the row opens a detail screen.

## States

| State | Circle | Card | Sublabel |
| --- | --- | --- | --- |
| Pending | 2.5px `ink-300` ring | Secondary, with `lip` — it's pressable | `ink-500` |
| Done | `positive-fill` disc, white check | Hairline only, no lip — nothing left to press | `positive`: "Done today" or "Done · 34 days running" |
| Locked | `line-200` disc with a lock | `raised` ground, no border | When it opens, and why: "Opens week 5 — one change at a time" |

## Rules

- The sublabel always says **why**: the finding, not a motivational phrase. "For jaw–neck line", never "Keep it up!"
- Tapping a pending row opens Task detail; the check is ticked there or by a swipe, never by tapping the row.
- No XP, points or rewards on the row. The streak is counted elsewhere.
- Three rows on Today, never more — the plan filters to the user's stated time.
