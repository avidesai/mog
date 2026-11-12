# PathNode

One week on the eight-week path. The path is the streak at a weekly grain: a week banks at 5 of 7 days, and the two scans sit at weeks 4 and 8.

## States

| State | Node | Note |
| --- | --- | --- |
| Banked | 56px `positive-fill` disc, `positive` lip, white check | Links to Progress |
| Current | 56px `accent` disc, `accent-deep` lip, the day count ("4/5") in white | Links to Today. Label beside it: "You're here" + what banks it |
| Ahead | 56px `track` disc, week number in `ink-500` | Not tappable |
| Scan | 66px, white, 2px dashed `ink-300` ring, camera glyph | Sits at week 4. Becomes a solid `accent` node when it unlocks |
| Finish | 70px, white, 2.5px `finish` ring, trophy glyph | Week 8 only. The one place gold appears. |

Nodes zigzag down the screen joined by a dotted `#D8D2C6` connector; the connector between banked nodes is solid `positive-fill`.

## Rules

- A missed week stays open. It never resets, and the copy on the path says so.
- No "perfect week" tier, no 7/7 distinction. Five of seven is the bar and the bar is enough.
- The finish node is outlined, not filled, until it's reached. Gold you can see but don't have yet is the only aspirational device in the product.
- Labels beside nodes are plain: what the week is, what unlocks there. Never "Keep going!"
