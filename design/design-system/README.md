# Mog

A facial-measurement app for the looksmaxxing audience, built around one promise and one habit: **the same face gives the same number, and the only thing you're asked to do every day is the work.**

Direction decided 11 November 2026. The 28-screen canvas "Mog — Gamified Direction" is the reference implementation of this system; where the two disagree, the canvas is newer.

## The look in one line

Warm, precise, and pressable. Ivory and warm neutrals, one blue that always means *measurement*, chunky rounded controls with a bottom lip, and your own face with the geometry drawn on it as the hero image.

## Principles

In priority order. When two screens disagree, the higher rule wins.

1. **The measurement is the hero, not the number.** Every finding appears on the user's own face with the line drawn on it. A card that cannot show its evidence is wrong.
2. **Show uncertainty, always.** The score carries its range. Never a bare point where the pipeline has a band.
3. **Nothing fake, anywhere.** No teaser scores, no numbers behind blur (the blur is a plate, and the UI says so), no invented social proof. Absolute.
4. **One mechanic, done well.** The streak. No XP, no levels, no badges, no leagues. The path runs on *weeks banked*, which is just the streak at a weekly grain, and it decides when the next scan unlocks.
5. **Low scores are facts, never verdicts.** State the percentile and the measurement. No red, no softening preamble, no encouragement — all three read as pity to this audience.
6. **Earn warmth; don't spray it.** The flame and its count are amber. The week-8 trophy is gold. Everything else is ink, blue, green or neutral.

## What each colour means

This is the whole semantic system. A colour used outside its meaning is a bug.

| Colour | Means | Where |
| --- | --- | --- |
| `accent` blue | **Measurement**, and the primary action | Overlay lines and markers, the current path node, primary buttons, selected options |
| `positive` green | **Done, or moved the right way** | Today's checked tasks, banked weeks, the day-complete ring, improvement deltas |
| `flame` amber | **The streak** | The flame icon and the count beside it. Nothing else. |
| `finish` gold | **The end of the eight weeks** | The week-8 trophy node, once |
| `caution` | **System state**: a failing gate, an unmeasured metric | Capture chips, suppressed rows |
| `critical` red | **Delete everything** | One button, in Settings |
| Warm neutrals | Everything else | |

**No colour encodes score quality.** A 3.1 and an 8.4 are set in `ink-900` at the same weight. Red-to-green ramps on facial metrics are why screenshots of competing apps read as cruel.

## Controls are chunky

Anything pressable is a `radius-lg` block with a `hairline` edge and a `lip` (4px) on the bottom in a darker shade of its fill. Pressing compresses it. This is most of the difference between "instrument" and "something I'd open tomorrow", and it costs nothing.

- **Primary**: `accent` fill, `accent-deep` lip, white `button` text.
- **Dark primary**: `ink-900` fill, `paper` text — used when blue would wrongly imply measurement (e.g. "See all 35").
- **Secondary**: `surface-50` fill, `line-200` hairline and lip, `ink-900` text.
- **Option row**: secondary, 56px minimum; selected swaps the edge to 2px `accent`.
- **Tappable task row**: a secondary card with a 30px check circle.

No gradients. No glow. No shadow except the capture shutter's `0 1px 2px rgba(0,0,0,0.08)`.

## Type

- **Inter Tight** for everything, tabular numerals on every number. Tight tracking is the signature.
- **Instrument Serif** only for the big declarative numbers and titles: the score on reveal and share, `Day 12`, `Week 2 of 8`, `Four habits`. Never for body, buttons, chips or the paywall.
- Section labels are `section-label`: 12px, 700, uppercase, 0.06em tracking, `ink-500`.

Writing numbers: scores to one decimal (`6.4`), ranges with an en dash (`5.9–6.9`), degrees closed up (`128°`), deltas signed (`+0.3`, `−5°`), percentiles whole (`68th`).

## Voice

Native with guardrails — harmony, PSL tiers, canthal tilt, softmaxxing — because euphemism marks an outsider. Never the comparative end: no mogged, no subhuman, no "better than X% of men". Percentiles are against a reference set, never against other users.

The register is a dry technician who occasionally lets a plain sentence land: "Bone doesn't move week to week. Skin and fat do." "Tuesday got away." "Streaks are for the work, never for the number."

Pattern for a finding: **measurement, reference, plain reading.** No judgement adjective.

## What the product refuses to do

Rank users against each other. Sell streak repairs (one a month, earned). Celebrate a score. Beautify the photo it measures. Recommend anything on the exclusion list (bone smashing, mewing as a fix, steroids, peptides, surgery as a habit). Show a number it hasn't measured — including its own re-scan reliability, which the Methodology screen labels a target until the study exists.

## Accessibility

Text 4.5:1 on its ground, including 11px captions; `ink-300` and `positive-fill` and `flame` are graphical only. 44px targets. Dynamic Type to `accessibilityMedium`. Reduce Motion collapses the reveal and the day-complete ring to a crossfade. Nothing is communicated by colour alone — checks carry a glyph, deltas carry a sign, locked rows carry a lock.

## iOS 26

System chrome (navigation, tab bar, sheets) adopts Liquid Glass as SwiftUI provides it. Content surfaces — cards, overlays, the reveal — stay opaque. A shifting translucent ground under a number the product claims is stable is the wrong signal.
