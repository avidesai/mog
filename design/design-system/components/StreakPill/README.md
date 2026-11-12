# StreakPill

The streak is the product's one reward mechanic, and this is its only visual. A flame and a count, in a `flame-wash` pill, top-right of Today, the path and the daily screens.

## Anatomy

Flame glyph 13×15 in `flame` · count in `chip` weight 700, `flame-text` · `flame-wash` ground · `radius-full`. On Day complete it grows into a tile with `value-lg`.

## What it counts

Days on which all of today's tasks were ticked. **Never** scans, opens, or re-scans. A streak that rewarded checking your face daily would train the compulsive-checking behaviour the product exists to avoid, and would also be pointless — nothing changes day to day.

## States

- **Active**: as drawn.
- **Zero or broken**: the flame goes `#D8D2C6`, the count goes `ink-500`, the ground goes `raised`. No red, no sad face.
- **Repair available**: handled on the Missed-a-day screen, not in the pill.

## Rules

- Amber appears here and nowhere else in the product.
- One repair a month, earned, never purchasable. Selling streak repairs beside a paywall is a loot mechanic and the audience will call it one.
- Banked weeks don't reset when a streak breaks. The copy says so.
