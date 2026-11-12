# MetricCard

The workhorse of the product — it appears dozens of times per session, so its density and restraint set the character of the whole app.

## Anatomy

Top to bottom: metric name (`title-3`) with evidence badge right-aligned on the same line · value (`mono-value-lg`) with unit in `ink-500` · reference range bar, 4px tall, `line-200` track with the typical range as an `accent-wash` band and the user's value as a 2px `accent` marker · range labels at each end (`caption`) · one-line plain-English reading (`body-sm`, `ink-700`) · optional overlay thumbnail, 56×56, `radius-sm`.

## Variants

- **full** — all elements. The default on the results list.
- **compact** — name, value and range bar only, for two-up grids on the detail screen. Never on the results summary, where comparison across cards matters more than density.
- **locked** — real name and real evidence badge, value replaced by an 8px-blurred plate. Tap opens the paywall.
- **suppressed** — name, a `caution` reason line naming the specific gate that failed, a Retake action, no value.

## States

Default · pressed (`paper` background shift, no scale transform) · expanded (reveals method and citation).

## Rules

- **Never show a fabricated value behind the blur.** The locked variant blurs a plate, not a number. There is no number to reveal.
- The suppressed variant is the component that proves the product works as advertised. Every competitor returns a value for every metric regardless of whether the capture supported it. Showing a metric as unmeasurable, with the specific reason and a retake path, is more convincing than any accuracy claim.
- The reason line is specific: "Lighting was uneven on the left side," not "Could not measure."
- No color encodes whether the value is good. The badge describes evidence strength, not quality.

## What the consumer provides

The metric record (name, value, unit, reference range, evidence grade, confidence), the plain-English reading string, and the overlay thumbnail if one exists.
