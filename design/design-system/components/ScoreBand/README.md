# ScoreBand

The score and its range, always together. On the reveal it sits inside a ring whose fill is the percentile; everywhere else it is a compact header row.

## Anatomy

- **Reveal**: a 13px `track` ring with an `accent` arc at the percentile, `display-reveal` serif numeral inside, `likely 5.9 – 6.9` in `detail` beneath. The ring fills over `deliberate`; the numeral does **not** count up.
- **Header**: `value-lg` numeral, the range in `caption`, the tier chip right-aligned. 1.5px hairline card.

## Rules

- The range is never hidden or collapsed. A typical band is ±0.4 to 0.6; narrower means the model is overconfident and the UI is lying for it.
- A low score uses identical type, weight and colour to a high one. No red, no softer copy, no encouragement.
- The tier chip is never coloured by tier.
- The numeral never animates to "settle". It arrives, then the range draws.

## Copy that travels with it

`6.4` · `likely 5.9 – 6.9` · `HTN · 68th percentile`. One tap away: "This estimates how an average rater would score this capture. About half of what makes a face appealing to any one person is their own taste, and nothing can measure that."
