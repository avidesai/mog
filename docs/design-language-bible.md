# Mog — Design Language Bible and UI Kit

Nov 11, 2026 · @Avi

The app should look like a measurement instrument that occasionally becomes beautiful. Monochrome, dense and precise everywhere, with a single accent reserved for the measurement under discussion — and a serif display face permitted in exactly two places, the score reveal and the share card. This document is the source of truth for every visual decision, and is written to be handed to a design tool as a brief.

## Decision record — 11 November 2026

This section supersedes the sections below wherever they disagree. The 28-screen canvas **Mog — Gamified Direction** and the Mog design system (v3 tokens) are the current reference; the sections that follow are the original instrument-direction draft, kept for the reasoning.

**The direction is warm and pressable, not clinical.** The instrument draft read as lab software. What survives from it: ivory and warm neutrals, Inter Tight with tabular numerals, Instrument Serif for the big numbers, blue meaning *measurement* only, no colour encoding score quality, the measured face as hero, and every one of the honesty rules. What changed:

| Was | Now |
| --- | --- |
| Two registers, dark reveal and share | One light register. The only dark surface is the camera viewport |
| Radius 4 / 8 / 12 | 4 / 12 / 16 / 20, pills at 999. Cards and buttons are 16 |
| Flat buttons | Chunky: hairline edge, 4px bottom lip in a darker fill. Press compresses |
| Bronze as second accent | Amber for the streak flame only; gold for the week-8 finish node only; bronze stays on the wordmark tick |
| Metric cards in a flat list | A grouped overview, then a swipe stack one metric at a time, then detail |
| Results-first home | Today-first home: the day count, three tasks from the plan, the week's banking progress, the scan countdown |
| Nothing to return for between scans | The streak, and a path of eight weeks that banks at 5 of 7 days with scans at weeks 4 and 8 |

**One mechanic.** The streak is the only reward system. XP, levels, badges, leagues and a clean-capture bonus were all built and then cut: each was a second currency with no meaning tied to the product, and together they were the Duolingo failure mode. The streak counts days the plan was done — never scans or opens — and a missed day offers one earned repair a month, never a purchasable one. Banked weeks never reset.

**Onboarding is three questions**, not eight: goals, sex and age band (the screen says these are the only things the reference ranges depend on), and realistic time. The self-rating question was cut because it primes the comparison frame; the distress signal comes from rescan behaviour instead.

**The plan is derived, not picked.** The rules engine selects habits from findings; the "add to plan" affordance was removed because it contradicted that. Every task row names the finding it serves.

**Screens in v1 (28):** Start · Goals · About you · Time · Consent · Capture front · Capture profile · Processing · Reveal · Results overview · Results, free user · Results, model changed · Metric swipe · Metric detail · Paywall · Today · Today, scan day · Today, no scan yet · Today, quiet check-in · Task detail · Day complete · Missed a day · Plan · Path · Progress · Share · Methodology · You/Settings.

**Still open:** the name (Mog carries store collisions and sits in tension with the voice rules; the wordmark is one line of type and costs nothing to redo), and whether profile capture ships in v1 or v1.1.

## Design principles

Six rules, in priority order. When two screens disagree, the higher rule wins.

**1. The measurement is the hero, not the number.** Every finding appears on the user's own face with the measured line drawn on it. A score with no visible basis is what every competitor ships and what every reviewer distrusts. If a card cannot show its evidence, the card is wrong.

**2. Show uncertainty, always.** Bands, not points, wherever the underlying confidence is real. The interface must never look more certain than the pipeline is. A design that hides the confidence band to look cleaner has broken the product's only differentiator.

**3. Nothing fake, anywhere.** No teaser scores, no placeholder numbers behind blur, no invented social proof, no fabricated activity counters. Locked content shows its real label and a blurred value, so the user knows exactly what exists. This rule is absolute and has no design exceptions.

**4. Density is respect.** This audience reads specifications for fun. They want the value, the reference range, the evidence grade and the method. Do not protect them from information — structure it so a glance gets the headline and a scroll gets the depth.

**5. Low scores are facts, never verdicts.** The interface states percentiles and measurements. It never editorializes about the person. No red for a low score, no frowning iconography, no "needs work" language. Neutral color, neutral type, actionable next step.

**6. Earn drama twice.** The product is flat, quiet and instrument-like everywhere except the score reveal and the share card. Spending visual drama anywhere else devalues both.

## Visual direction

### The look in one line

A precision measurement instrument, rendered in near-monochrome with a single blue accent, that becomes briefly cinematic at the score reveal and on the share card.

### What it rejects, deliberately

The category has one look: near-black ground, neon or chrome gradient, glow, heavy drop shadows, scanning-grid motifs, aggressive italics. Umax, LooksMax AI and the long clone tail all run variants of it. Adopting it would make the app visually indistinguishable from products whose core failing is that they are not credible — and it raises the odds of being read as another variant under Apple's June 2026 warning about opportunistic clones of popular app categories.

So: **no gradients as decoration, no glow, no chrome, no scan-line motifs, no drop shadows beyond a 1px hairline border.** Depth comes from borders and spacing, not from blur or shadow.

### Reference points

| Source | What is borrowed |
| --- | --- |
| Hims | One accent color carrying all emotional weight against an achromatic canvas; tight tracking giving body text an editorial density unusual in consumer health |
| Whoop | Utilitarian density; data as the primary surface; the discipline of showing a lot without feeling cluttered |
| Hinge | A serif display face against a geometric sans; stark surfaces; dark reserved for immersive moments |
| Tinder's 2026 rebrand | The decision to delete the signature gradient for a more mature palette, as the category's premium end moves away from the look the clones are still using |
| Clinical imaging software | Measurement lines over the subject; tabular numerals; reference ranges beside values |

### What is deliberately not borrowed

Oura's atmospheric warmth was considered and rejected for v1. It is the better model for the harm-reduction framing, and it is also closest to the category default, which makes differentiation harder. The relevant framing axis — body-as-machine versus body-as-temple — is handled in the copy rules instead, which is where it actually belongs.

### The two registers

|  | Instrument register | Reveal register |
| --- | --- | --- |
| Where | Everything: onboarding, capture, metric cards, plan, settings | Score reveal screen, share card |
| Ground | Paper, light | Ink, near-black |
| Display face | Grotesque | Serif |
| Density | High | Extremely low, one idea per screen |
| Motion | Functional, fast | Choreographed, slow |

The reveal register appears twice in the entire product. That scarcity is the point.

## Color tokens

The palette is intentionally small. One accent, one warning, one positive, and a gray ramp doing everything else. A designer who needs a color that is not here should add a gray, not a hue.

### Base ramp

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `--ink-900` | `#111112` | `#F4F4F2` | Primary text, score numerals |
| `--ink-700` | `#3A3A3D` | `#C9C9C5` | Secondary text, card labels |
| `--ink-500` | `#6E6E73` | `#96968F` | Tertiary text, captions, units |
| `--ink-300` | `#A8A8AD` | `#6A6A64` | Disabled, placeholder |
| `--line-200` | `#E3E3DF` | `#2C2C2A` | Hairline borders, dividers, card edges |
| `--surface-50` | `#FFFFFF` | `#1A1A18` | Card surfaces |
| `--paper` | `#FAFAF8` | `#111110` | App background |
| `--ink-max` | `#0A0A0A` | `#0A0A0A` | Reveal ground and share card, both modes |

The background is warm off-white rather than pure white, and the dark mode ground is warm near-black rather than pure black. Pure white and pure black both read as cheap at this density.

### Accent and semantics

| Token | Value | Use | Hard rule |
| --- | --- | --- | --- |
| `--accent` | `#2E5BFF` | The measurement currently under discussion; primary buttons; active states | Never more than one accent element visible per card |
| `--accent-wash` | `#2E5BFF` at 8% | Fill behind an active measurement region | Never as a decorative background |
| `--positive` | `#1F8A54` | Improvement deltas, met goals, strong evidence badge | Never used to mean "good score" |
| `--caution` | `#B5731A` | Low capture quality, suppressed metric, limited-evidence badge | Never used to mean "bad score" |
| `--critical` | `#B3341F` | Destructive confirmation, hard errors only | Never on a score, metric or finding |

### The rule that matters most

**No color encodes score quality.** A 3.1 and an 8.4 are set in the same `--ink-900` at the same weight. Semantic color is reserved for system state — capture quality, evidence strength, change over time — and never for a judgement about the person.

This is a deliberate departure from every competitor, which use red-to-green ramps on facial metrics. Those ramps are why screenshots of those apps read as cruel, and they are the single easiest thing to point at in a critical article.

### Evidence badges

Badges carry meaning through label and border weight, not fill color, so a row of metric cards does not become a traffic light.

| Grade | Treatment |
| --- | --- |
| Well supported | `--ink-900` text, `--ink-900` 1px border |
| Reasonable support | `--ink-700` text, `--line-200` border |
| Limited evidence | `--ink-500` text, `--line-200` border |
| Community metric | `--ink-500` text, `--line-200` dashed border |
| Research disagrees | `--caution` text, `--caution` 1px border |

### Data visualization

Deltas and history use a single hue: `--accent` for the series, `--ink-300` for the prior value, `--line-200` for grid. Reference ranges render as a `--line-200` band with the user's value as an `--accent` marker. Three categorical colors exist for charts that genuinely need them (`#2E5BFF`, `#6E6E73`, `#B5731A`) and no more.

## Typography

### Families

| Role | Family | Fallback | Licensing |
| --- | --- | --- | --- |
| UI and body | **Inter Tight** | SF Pro | Open, SIL — free, which matters at this budget |
| Numerals | Inter Tight, tabular figures enabled | SF Pro tabular | Same |
| Display, reveal only | **Instrument Serif** | New York | Open, SIL — free |

Both families are free and open-licensed. A paid pairing such as Söhne with Tiempos Headline would be marginally better, and is the first upgrade to make once revenue exists.

### The serif rule

Instrument Serif appears in exactly two places: the score numeral on the reveal screen, and the score numeral on the share card. Nowhere else — not in headings, not in the paywall, not in onboarding. Every additional use costs the reveal its impact.

### Scale

Tight tracking throughout is the signature; it gives body copy an editorial density unusual for a consumer health app, which is directly borrowed from Hims.

| Token | Size / line | Weight | Tracking | Use |
| --- | --- | --- | --- | --- |
| `display-reveal` | 112 / 100 | 400 (serif) | −0.03em | The score numeral, reveal screen |
| `display-share` | 88 / 80 | 400 (serif) | −0.03em | The score numeral, share card |
| `title-1` | 28 / 34 | 600 | −0.022em | Screen titles |
| `title-2` | 22 / 28 | 600 | −0.020em | Section headers |
| `title-3` | 17 / 24 | 600 | −0.016em | Card titles, metric names |
| `body` | 15 / 22 | 400 | −0.012em | Card body, descriptions |
| `body-sm` | 13 / 19 | 400 | −0.010em | Secondary detail |
| `label` | 12 / 16 | 500 | 0.01em | Field labels, badges, units |
| `mono-value` | 17 / 22 | 500 tabular | −0.01em | Metric values |
| `mono-value-lg` | 24 / 28 | 500 tabular | −0.015em | Headline metric values |
| `caption` | 11 / 15 | 400 | 0.01em | Footnotes, citations, legal |

### Numerals

Tabular figures everywhere a number appears — metric values, scores, ranges, dates, deltas. Proportional figures cause values to shift horizontally between re-renders, which on a screen full of measurements reads as instability. In an app whose promise is that numbers do not move, numerals that visibly jitter undermine the claim at the typographic level.

### Writing numbers

- Scores to one decimal: `6.4`, never `6.40` or `6`
- Ranges with an en dash and a single unit: `5.9–6.9`, `115–125°`
- Degrees close up to the numeral: `4.2°`
- Ratios to two decimals: `1.92`
- Deltas always signed: `+0.3`, `−0.1`
- Percentiles as whole numbers: `68th percentile`

### Constraints

Support Dynamic Type to at least `accessibilityMedium`; the metric card must reflow rather than truncate. Never set body copy below 13pt. Never use italics for emphasis — use `--ink-900` against `--ink-700`. No all-caps except in `label` tokens, and never on a tier name.

## Space, grid, radius, elevation

### Spacing scale

A 4pt base, used strictly. `2, 4, 8, 12, 16, 20, 24, 32, 40, 56, 80`. No value outside this scale appears anywhere.

| Context | Value |
| --- | --- |
| Screen horizontal margin | 20 |
| Card internal padding | 16 |
| Gap between cards | 12 |
| Gap between sections | 32 |
| Gap between a label and its value | 4 |
| Space above a section header | 40 |
| Bottom safe area padding | 24 plus inset |

### Grid

Single column, full width minus 20pt margins. Metric cards may run two-up in a 12pt-gutter grid on the detail screen, but never on the results summary, where comparison across cards matters more than density.

### Radius

| Token | Value | Use |
| --- | --- | --- |
| `radius-sm` | 4 | Badges, chips, input fields |
| `radius-md` | 8 | Cards, buttons, sheets |
| `radius-lg` | 12 | Share card, reveal panel |
| `radius-full` | 999 | Only the capture-progress ring |

Small radii are part of the instrument character. A 16 or 20pt radius immediately reads as a friendly consumer app and pulls the whole design toward the category default.

### Elevation

There is effectively none. Depth is communicated by a 1px `--line-200` border and background differentiation between `--paper` and `--surface-50`.

The single permitted shadow is on the capture shutter control: `0 1px 2px rgba(0,0,0,0.08)`. Nothing else in the product casts a shadow. This is the rule most likely to be violated by a design tool asked to make something look polished, so it should be stated explicitly in any handoff brief.

### Touch targets and layout

Minimum 44×44pt for anything tappable. Primary actions sit in a bottom-anchored container with 20pt margins and a `--line-200` top border, not floating. Scroll content ends with 80pt of clearance so the last card is never trapped behind the action bar.

## Component library

Eighteen components cover all of v1. Anything a screen needs that is not here should be questioned before it is designed.

### MetricCard

The workhorse. Appears dozens of times per session, so its density and restraint set the character of the whole app.

**Anatomy, top to bottom:** metric name (`title-3`) with evidence badge right-aligned on the same line · value (`mono-value-lg`) with unit in `--ink-500` · reference range bar, 4pt tall, `--line-200` band with the user's value as a 2pt `--accent` marker · range labels at each end (`caption`) · one-line plain-English reading (`body-sm`, `--ink-700`) · optional overlay thumbnail, 56×56, `radius-sm`.

**Variants:** `full` (all elements) · `compact` (name, value, range bar only, for two-up grids) · `locked` (real name and badge, value replaced by an 8px-blurred plate, tap opens paywall) · `suppressed` (name, a `--caution` reason line, a Retake action, no value).

**States:** default, pressed (`--paper` background shift, no scale transform), expanded (reveals method and citation).

### ScoreBand

The point estimate as a large tabular numeral with the confidence interval rendered as a horizontal band beneath: a `--line-200` track, an `--accent` segment spanning low to high, and a 2pt vertical tick at the point estimate. Endpoint labels in `caption`. The band is never hidden, never collapsed to a single number, and never animated to "settle" on a value, which would imply a precision that does not exist.

### TierChip

The PSL tier. `label` type, `radius-sm`, 1px `--line-200` border, `--ink-700` text, transparent fill. Never colored by tier, never all-caps, never accompanied by an icon. Tapping opens an explainer sheet defining the tier as a percentile against the reference distribution.

### EvidenceBadge

Five variants per the color section. `label` type, 2pt vertical and 6pt horizontal padding, `radius-sm`. Tappable, opening a sheet with the citation and a plain-English note on the strength of the research.

### CaptureFrame

The live camera surface with the gating system. A full-bleed preview, a `radius-lg` mask with the area outside at 60% `--ink-max`, and a thin `--line-200` alignment guide. Gate status renders as a stack of at most three active chips at the top — never all nine at once, which would be unusable. The progress ring is the only `radius-full` element in the app, stroked 3pt in `--accent`, filling as gates pass. The shutter is disabled until all gates pass, with the single permitted shadow.

**Gate chip states:** pending (`--ink-500` text, `--line-200` border) · passing (`--accent` text and border) · failing (`--caution` text and border, plus a corrective instruction such as "Move a little further away").

### PlanCard

**Anatomy:** impact rank numeral in `--ink-300` · action headline (`title-3`) · body (`body`) · a "why this" row linking to the triggering finding, with the metric name and value in `--accent`, tappable to its overlay · a metadata row of timeline and effort chips · evidence badge.

**Variants:** `action` (safety tiers 1–2, in the main ranked plan) · `professional` (tiers 3–4, visually distinct with a `--line-200` dashed left border and no rank numeral, so it is never confused with something to act on alone).

### The remaining twelve

| Component | Note |
| --- | --- |
| `Button` | Primary (`--accent` fill, white text), secondary (`--line-200` border, `--ink-900` text), tertiary (text only). 48pt tall, `radius-md`, never full-width-with-gradient |
| `QuizOption` | Onboarding selection row, 56pt tall, `--line-200` border, selected state swaps border to `--accent` 2pt. No checkmark iconography |
| `ConsentPanel` | Distinct from everything else: `--surface-50`, 1px `--ink-900` border, explicit affirmative control labelled with the action, never styled as a generic continue button |
| `Paywall` | Three plan rows, terms visible inline, close control top-left at full opacity from the first frame, restore link. No countdown, no decoy pricing |
| `ShareCard` | Reveal register. 1080×1920 and 1080×1080 exports |
| `DeltaRow` | Previous value, arrow, current value, signed change in `--positive` or `--ink-700`. Never `--critical` |
| `Sheet` | Bottom sheet, `radius-lg` top corners, grabber, `--surface-50` |
| `EmptyState` | Single line of `body` in `--ink-500` plus one action. No illustrations |
| `Toast` | `--ink-900` fill, white text, `radius-md`, 3s |
| `SegmentedControl` | Front / Profile switching on the results screen |
| `CitationLink` | `caption`, `--ink-500`, underlined, opens a sheet rather than a browser |
| `DistressCard` | `--surface-50`, 1px `--line-200`, no accent, no icon, calm `body` copy, dismissible. Deliberately the least designed element in the product |

## The measurement overlay

This is the signature component and the one thing no competitor does well. It is what converts a number from an assertion into an observation, and it deserves more design attention than anything else in the app.

### Behaviour

The user's own capture, with the geometry for one metric drawn over it. One metric at a time, never several at once — a face covered in simultaneous measurement lines is the aesthetic of the apps this one is competing against, and it communicates nothing.

### Rendering

| Element | Treatment |
| --- | --- |
| Photo | Full width, `radius-md`, unmodified — never beautified, never filtered, never smoothed |
| Inactive geometry | 1pt `--line-200` at 40% opacity, showing the landmark scaffold faintly |
| Active measurement | 2pt `--accent`, full opacity |
| Measurement endpoints | 4pt `--accent` filled circles |
| Angle arcs | 2pt `--accent`, with the degree value set at the arc midpoint in `mono-value` on a `--paper` plate at `radius-sm` |
| Region fill | `--accent-wash` only when the metric describes an area rather than a line |
| Value callout | `mono-value-lg` on a `--surface-50` plate, 1px `--line-200`, positioned to avoid the face |

### The honesty requirement

The photo is never retouched, brightened, smoothed or warmed. If the capture looks unflattering, that is the capture. An app that quietly beautifies the photo it measures has invalidated its own measurement and will be caught doing it.

### Interaction

Tap a metric card, and the overlay animates from the previous metric's geometry to this one — endpoints translating, lines redrawing over 240ms. The transition between measurements is the single most satisfying moment in the product after the reveal, and it is also what makes the system legible: users learn what the measurements *are* by watching them move.

Pinch to zoom up to 3×, with the measurement scaling with the image. Long-press hides all overlay geometry to show the unmarked photo, which users will want constantly and which builds trust in the photo's authenticity.

### Profile overlays

Same system, applied to the profile capture. The Frankfort horizontal renders as a `--line-200` dashed reference line, since nearly every profile angle is defined against it, and showing it makes the measurements comprehensible rather than arbitrary.

### Export

The overlay is the most shareable artifact in the app after the score. An export renders the photo, one measurement, the value, and a small wordmark — at the user's explicit action only, and never with the score attached, which belongs to the share card.

## Motion

### Defaults

| Token | Duration | Curve | Use |
| --- | --- | --- | --- |
| `instant` | 100ms | ease-out | Press feedback, chip state changes |
| `quick` | 180ms | ease-out | Sheet presentation, toasts |
| `standard` | 240ms | spring, 0.9 damping | Navigation, overlay metric transitions |
| `deliberate` | 600ms | ease-in-out | Reveal choreography only |

Everything outside the reveal uses `instant` or `quick`. Instrument software feels responsive, not animated.

### Forbidden

No parallax, no spring bounce above 0.9 damping, no scale-on-press beyond 0.98, no shimmer or skeleton pulse on anything representing a real measurement, no confetti, no haptic celebration on a score. A score is a measurement, not an achievement, and celebrating it is both tonally wrong and the thing that would appear in a critical article about the app.

### The reveal, choreographed

The only sequence in the product that earns real time. Roughly 2.2 seconds total, skippable by tap from the first frame.

1. **0–400ms.** Ground crossfades from `--paper` to `--ink-max`. The capture, already on screen, dims to 30% and scales to 0.96.
2. **400–900ms.** The landmark scaffold draws on over the dimmed photo — a genuine render of the actual landmarks, not a decorative animation. This is a real moment of proof.
3. **900–1400ms.** Scaffold fades. The score numeral in Instrument Serif scales from 0.92 to 1.0 with an opacity fade. **It does not count up.** A counting animation implies the number was arrived at by searching, and the whole product claim is that it was computed.
4. **1400–1800ms.** The confidence band draws outward from the point estimate to its endpoints. The band appearing *after* the number, and visibly extending, is the design doing the honesty work.
5. **1800–2200ms.** Tier chip and the first two insight rows fade in at 60ms intervals.

Then the screen is static. No looping ambient motion, no pulsing.

### Capture feedback

Gate chips cross-fade between states over 100ms with no movement, since a jumping chip during careful head positioning is actively hostile. The progress ring fills continuously rather than stepping. When all gates pass, a single light haptic fires and the shutter becomes enabled — the only haptic in the capture flow.

### Reduce Motion

With Reduce Motion enabled, the reveal becomes a 200ms crossfade to the final composed state, and overlay transitions become instant cuts. Nothing is lost except choreography.

## Voice and copy

### The register

Native with guardrails. The app uses the audience's vocabulary — harmony, PSL tiers, softmaxxing and hardmaxxing, canthal tilt, midface — because using euphemisms instead would mark it immediately as an outsider product and forfeit forum credibility. It does not use the vocabulary of ranking people against each other.

The voice is a technician's: precise, unsentimental, slightly dry, never hyped and never consoling. It states what was measured and what follows from it.

### Permitted and excluded vocabulary

| Use | Never use |
| --- | --- |
| Harmony, proportion, projection | Subhuman, failo, cope, rope |
| PSL tier names — LTN, MTN, HTN, Chadlite | Mogged, mogging, mogger, anything comparative |
| Softmaxxing, hardmaxxing | Looksmatch, SMV, any market-value framing |
| Canthal tilt, gonial angle, midface ratio | Bone smashing, any excluded intervention, even to dismiss unprompted |
| Percentile, reference range, confidence band | Rating out of other people, "better than X% of men" |

That last exclusion is structural. The percentile is stated against a reference distribution, never as a comparison against other users — "68th percentile of the reference distribution" rather than "you beat 68% of guys." The second framing is what makes a product a ranking engine, and the ranking frame is both the dysmorphia risk and the reputational one.

### Score and tier copy

- Score: **"6.4"**, with **"likely 5.9–6.9"** directly beneath. Never "your score is," never an exclamation mark.
- Tier: **"HTN"** with the subline **"High-tier normie · roughly the 68th percentile of our reference distribution"**.
- Low scores, stated flat: **"4.1 · likely 3.7–4.5 · LTN"** and then straight into the most improvable finding. No softening preamble, no encouragement — both read as pity to this audience and both undercut the instrument voice.
- What the score is, always one tap away: **"This estimates how an average rater would score this capture. About half of what makes a face appealing to any specific person is personal taste no model can measure."**

### Finding copy

Pattern: **measurement, reference, plain reading.** No judgement adjective.

> **Gonial angle 128°** Typical range for adult males, 115–125° Your jaw angle is slightly more obtuse than the typical range, which reads as a softer jawline in profile.

Never: "weak jaw," "poor," "needs improvement," "unfortunately."

### Evidence badge copy

Exactly these five strings, and no variants: *Well supported by research* · *Reasonable support* · *Limited evidence* · *Community metric, little evidence* · *Research points the other way*.

The last one will appear on FWHR, and the explanation should be direct about it: the community treats a higher ratio as desirable, while the meta-analytic evidence associates it with lower rated attractiveness. Saying so plainly is a credibility asset, not a liability — it is the clearest available proof that the app reports findings rather than telling the audience what it wants to hear.

### Locked-state copy

Name what is behind the lock, with no hype: **"Gonial angle · measured, locked"**. Never "Unlock your TRUE score," never "You won't believe." The free score is the real score, and the copy must never imply a better number is hidden.

### Paywall copy

State what is included and what it costs. No scarcity, no countdown, no "X people joined today." Price, period and renewal terms visible on the surface itself.

### Professional-referral copy

**"This is something a board-certified surgeon could assess. We don't recommend procedures and we have no financial relationship with any provider."** The second sentence is a trust asset worth keeping even when affiliate revenue becomes available.

### Distress copy

Calm, short, non-clinical, no accent color, no icon:

> If you're finding yourself checking this a lot, that's worth paying attention to. Appearance preoccupation is common and treatable. If it's weighing on you, talking to someone helps — 988 connects you to support any time.

Never A/B tested. Never styled to draw attention. Never used as an engagement surface.

## Screen inventory

&#91;embedded content: v1 screen flow · 23 screens, two visual registers\]

Two things in this flow are load-bearing. The paywall sits after a real, honest free result rather than before the scan, which is the structural decision that separates the product from the category. And the reveal register appears at only two nodes in the entire graph — everything else is instrument register, which is what makes those two moments land.

## Screen specs

Twenty-three screens in v1. Each is specified top to bottom in the order elements appear.

### 1. Launch

Wordmark centred, `--paper` ground, no tagline, no loading spinner under 400ms. Instrument register from the first frame.

### 2–9. Onboarding quiz

Eight screens, one question each. Identical structure: progress bar at top (2pt, `--line-200` track, `--accent` fill, no percentage text) · question in `title-1`, left-aligned, maximum two lines · `QuizOption` rows · bottom-anchored primary button.

| # | Question | Input |
| --- | --- | --- |
| 2 | Sex | Two options — drives every reference distribution |
| 3 | Age | Four bands, 18–24 through 45+, plus the age attestation |
| 4 | What do you want to improve? | Multi-select, six goals |
| 5 | What matters most? | Single select from what they chose above — sets primary goal weight |
| 6 | Current routine | Multi-select: skincare, training, hair treatment, none |
| 7 | How do you think you look now? | 1–10 slider — used for the distress signal, never shown back |
| 8 | Time you can realistically put in | Three options — drives effort filtering in the plan |
| 9 | What you'll get | Three lines, no imagery, then Continue |

Screen 9 is not a value-proposition sell. It is a plain statement of what the next two minutes involve, which suits the instrument voice and sets up the consent screen.

### 10. Consent

Deliberately visually distinct — `ConsentPanel` on `--surface-50` with a 1px `--ink-900` border. Plain-English body covering what is captured, that it is processed on the device, that nothing is uploaded, what is kept, for how long, and how to delete it. Link to the full policy. The affirmative control is labelled with the action itself, not "Continue." Never bundled with terms or the paywall.

### 11. Capture intro

Two illustrated steps — front, then profile — with a plain-language note on why positioning matters: the app can only be consistent if the captures are. Sets the expectation for gating before the user hits a failing gate.

### 12. Front capture

`CaptureFrame`. Gate chips top, progress ring around the shutter, corrective instruction directly above the shutter when a gate fails. Cancel top-left. No filters, no beauty mode, no mirror toggle.

### 13. Profile capture

Same component, different gate set, with a timer option and a distance prompt because the user cannot hold the phone at arm's length while facing sideways.

### 14. Processing

The landmark scaffold rendering progressively over the actual capture. Real progress, not a fake timer. Single line of status text in `body-sm`. Typically five to ten seconds.

### 15. Reveal

Reveal register. `--ink-max` ground. Score numeral in Instrument Serif, `ScoreBand` beneath, `TierChip`, then two insight rows — the top strength and the most fixable finding. A single tertiary "What this means" link. Bottom-anchored primary action to see the full breakdown.

### 16. Results

Back to instrument register. Sticky header carrying the score small · `SegmentedControl` for Front and Profile · the overlay at top · `MetricCard` list grouped by region (Proportion, Eyes, Midface, Jaw and chin, Skin and hair) · locked cards interleaved in their real positions, never collected in a separate upsell block.

### 17. Metric detail

Full-screen overlay, large value, reference range with the user's position, method explanation, citation, evidence badge with its sheet, and any plan cards triggered by this finding.

### 18. Paywall

Title stating what Pro includes · three plan rows with annual pre-selected · inline terms · restore link · close control top-left at full opacity from frame one. No imagery, no testimonials, no countdown.

### 19. Plan

Ranked `PlanCard` list · then a `--line-200` divider · then the professional-referral section, visually distinct and unranked.

### 20. Share card composer

Preview with two or three layout options, a toggle for whether the score is included, and the export action. Reveal register.

### 21. History

Empty until a second scan exists. Then `DeltaRow` per metric that moved, plus a sparkline of the score over time using the single-hue chart treatment.

### 22. Settings

Account · subscription · consent management with each consent independently revocable · delete all data · policies · methodology.

### 23. Methodology

The credibility screen, linked from the reveal and from settings. States how the score is computed, what the panel is, the published test-retest figure, how fairness is checked, and what the app explicitly does not claim. No competitor ships anything like this, and it is the single best asset for forum credibility — it should be written to be screenshotted and posted.

## States

Every component needs all of these specified, because the states are where a design system either holds together or falls apart.

| State | Treatment | Rule |
| --- | --- | --- |
| Loading | No skeleton pulse on anything representing a measurement. A static `--line-200` placeholder block, or real progress | A shimmer on a number implies the number is being invented |
| Empty | One line of `body` in `--ink-500` and a single action. No illustration, no mascot | Instrument software does not apologize for having no data |
| Locked | Real label, real badge, 8px-blurred value plate, lock glyph at 12pt in `--ink-300` | Never a fabricated number behind the blur |
| Suppressed | Real label, `--caution` reason line, Retake action, no value | The reason is specific: "Lighting was uneven on the left side" |
| Low capture quality | Banner above results in `--caution`, listing which gates were marginal and what to change | Shown before the user wonders why a metric is missing |
| Offline | Silent. Scan, score, metrics and static plan copy all work | Only sync, history and LLM phrasing degrade, and they degrade quietly |
| LLM unavailable | Static rule copy renders with no error and no mention | The user should not be able to tell |
| Error | Plain sentence, specific cause, one recovery action | No error codes, no apologies, no `--critical` unless destructive |
| Pressed | `--paper` background shift, 0.98 scale maximum | No bounce |
| Disabled | `--ink-300` text, `--line-200` border, 100% opacity | Never below 40% opacity, which fails contrast |

### The suppressed state matters most

It is the state that proves the product works as advertised. Every competitor returns a number for every metric regardless of whether the capture supported it. Showing a metric as unmeasurable, with the specific reason and a retake path, is more convincing than any marketing copy about accuracy — and it is the direct visual expression of the determinism promise.

### Score change across versions

When a model version bump changes a stored score, the app says so explicitly rather than silently re-rendering: a `--surface-50` card on the results screen with the previous value, the new value, and a plain statement that the model was updated and what changed. This is the single highest-trust moment the product has, and the one thing that most separates it from apps whose scores appear to drift at random.

## Accessibility and the iOS 26 posture

### Accessibility requirements

| Requirement | Standard |
| --- | --- |
| Text contrast | 4.5:1 minimum. `--ink-500` on `--paper` passes; `--ink-300` is for non-text and disabled only |
| Accent contrast | `--accent` on `--paper` is 4.6:1. White on `--accent` is 4.9:1. Both pass |
| Touch targets | 44×44pt minimum |
| Dynamic Type | Support to `accessibilityMedium`; `MetricCard` reflows rather than truncating |
| VoiceOver | Metric cards announce as "name, value unit, within/outside typical range, evidence grade." Overlays carry a text description of the measurement |
| Reduce Motion | Reveal becomes a 200ms crossfade; overlay transitions become cuts |
| Reduce Transparency | Capture mask becomes solid rather than translucent |
| Color independence | Nothing is communicated by color alone — evidence badges use border style and label, deltas use sign |

The color-independence rule falls out of the design anyway, since no color encodes score quality. That principle does double duty as an accessibility property.

### Liquid Glass

Apple shipped Liquid Glass with iOS 26, and from April 28, 2026 every App Store Connect upload must be built with Xcode 26 and the iOS 26 SDK — which means standard SwiftUI components adopt the new material automatically on recompile.

**The posture: adopt it for system chrome, reject it for content.**

| Surface | Treatment |
| --- | --- |
| Navigation bars, toolbars, tab bars, sheets | Standard SwiftUI components, Liquid Glass as the system provides it |
| Metric cards, overlays, score reveal, share card, plan cards | Custom, opaque, no translucency, no blur |
| Capture surface | Custom. The mask is a flat scrim, never a glass material |

The reasoning is specific rather than stylistic. Translucency behind a measurement value puts a shifting background underneath a number the product claims is stable, which is exactly the wrong signal. It also reduces contrast on dense tabular content. Letting the system handle navigation keeps the app feeling native and current; keeping content surfaces opaque keeps the instrument character intact.

The practical consequence for the build: audit every screen on an iOS 26 device after the first Xcode 26 compile, since components will have changed appearance without any code change. Budget time for it rather than discovering it at submission.

## Identity

### Wordmark

Inter Tight, 600 weight, tracking −0.03em, lowercase, `--ink-900`. No logotype drawing, no icon lockup, no custom letterforms in v1 — a typographic wordmark is free, appropriate to the instrument character, and trivially revisable once the name settles.

The one permitted flourish: a 2pt `--accent` measurement tick above the wordmark, echoing the overlay system. It ties the identity to the product's actual mechanic rather than being decoration.

### App icon

The icon must survive at 60×60 and must not look like the category. The clones run glowing faces, chrome jawlines, and neon gradients, which means a flat, restrained mark is differentiating at the only moment where differentiation is nearly free.

Direction: a single `--accent` measurement line and two endpoint dots on a `--paper` ground, reading as a caliper or a measured segment. No face, no silhouette, no gradient, no glow. Dark-mode and tinted variants follow automatically from a two-color mark.

### What the name does to the design

The working name is **Mog**, and it is carried throughout this document so nothing blocks on it. Three design-level consequences worth weighing before it is final:

- **It is three letters**, which is excellent for a wordmark and for an icon that could eventually be a letterform. Short names are a real typographic asset.
- **It collides in the store.** *Mogged* and *MogMax* already exist in this category. A wordmark that is hard to distinguish from competitors at thumbnail size gives away the differentiation the icon direction above is trying to buy.
- **It fights the voice rules.** The copy section excludes comparative vocabulary — mogging, mogger, mogged — because the ranking frame is the dysmorphia and reputational risk. A name drawn from that exact vocabulary sits in tension with every copy rule in this document, and that tension will be visible to anyone reading the app closely.

If the name holds, the design response is to lean the wordmark hard toward the instrument character so the typography argues against the name's connotation. If it changes, the stronger directions are measurement words or a short invented mark that reads as native without being a community verb. Either way the wordmark is one line of type and costs nothing to redo.

## Handoff

### How to use this document

Don't paste the whole thing. A design tool given 15 sections at once averages across them and produces something generic. Work screen by screen, with the token sections as fixed constraints.

**The brief that works:**

> Here is the design system \[paste: Visual direction, Color tokens, Typography, Space/grid/radius/elevation, and the relevant component specs\].
>
> Design screen \[N\]: \[paste that screen's spec\].
>
> Constraints that override any default: no gradients, no glow, no drop shadows beyond a 1px hairline border, no color encoding score quality, radius never above 12, serif only on the reveal and share card, tabular numerals on every number.

That constraint paragraph is the important part. A design tool asked to make something look good will reach for gradients, soft shadows, rounded corners and a red-to-green score ramp, because those are the defaults for the category. Every one of those breaks a rule here. Repeat the constraints in every single brief.

### Order to generate

1. **MetricCard, all four variants.** It appears more than anything else and sets the character. Get it right before anything else is drawn.
2. **The measurement overlay.** The signature component and the hardest to get right.
3. **Results screen**, composed from the two above.
4. **Reveal screen** — the only place the second register appears, so design it immediately after the instrument register is settled, while the contrast is deliberate.
5. **Capture screen** with all gate states.
6. **Onboarding**, as one template plus eight content fills.
7. **Paywall**, **Plan**, **Share card**.
8. **Everything else.**

### Review each output against this list

- Is there a gradient, glow or shadow that is not the one permitted shutter shadow?
- Does any color imply a score is good or bad?
- Is the serif anywhere other than the reveal or share card?
- Are numerals tabular and aligned?
- Is any number shown without its reference range or confidence band?
- Is any locked state showing an invented value?
- Is any radius above 12?
- Would this screen be distinguishable from a competitor's at thumbnail size?

The last question is the one that matters commercially. If a generated screen could be mistaken for Umax, it has failed regardless of how good it looks.

### What to pair this with

Hand over this document and the engineering design doc together. The screen specs assume behaviours defined there — gate thresholds, suppression rules, confidence bands, safety tiers — and a designer working from this document alone will produce screens that cannot hold the real data.

### Still open

- Final name, which determines the wordmark
- Whether profile capture ships in v1 or v1.1, which removes screen 13 and the profile segment of screen 16
- Whether the peer-rating mode arrives in v1.1, which adds roughly four screens and a moderation surface not specified here
