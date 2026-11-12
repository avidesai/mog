# GateChip and CaptureFrame

The gating system is where score consistency is won or lost. The app refuses to measure a capture it cannot trust rather than measuring it badly.

## Why gating exists

A selfie taken at roughly 12 inches makes the nasal base appear about 30% wider than a portrait at 5 feet. An ungated app therefore measures camera distance and calls it nose width. This is the mechanism behind the single most common complaint about competitors: the same face producing different numbers.

## Chip states

- **pending** — `ink-500` text, `line-200` border
- **passing** — `accent` text and border, with a check
- **failing** — `caution` text and border, plus a corrective instruction below the frame ("Move a little further away")

## Rules

- **At most three active chips visible.** There are nine gates; showing all of them at once is unusable.
- Chips cross-fade between states over 100ms **with no movement**. A chip that jumps while someone is carefully positioning their head is actively hostile.
- The shutter is disabled until every gate for that pose passes. It carries the single permitted shadow in the product.
- The progress ring is the only `radius-full` element in the app. It fills continuously, never in steps.
- One light haptic when all gates pass — the only haptic in the capture flow.
- No filters, no beauty mode, no mirror toggle. An app that beautifies the photo it measures has invalidated its own measurement.

## Corrective copy

Always specific and actionable: "Move a little further away," "Turn slightly left," "Find more even light." Never "Capture failed."
