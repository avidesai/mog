# Button

Anything pressable is chunky: a `radius-lg` block, `hairline` on three sides, a 4px `lip` on the bottom in a darker shade of its fill. Press compresses the lip. This single detail carries most of the product's "I'd open this tomorrow" feel.

## Variants

| Variant | Fill | Lip | Text | Use |
| --- | --- | --- | --- | --- |
| Primary | `accent` | `accent-deep` | white, `button` | The one next step on a screen |
| Dark primary | `ink-900` | near-black | `paper` | When blue would wrongly imply measurement — "See all 35" |
| Secondary | `surface-50` | `line-200` | `ink-900` | Retake, back, the second choice |
| Option row | secondary, 56px, left-aligned, 600 weight | | | Onboarding and settings choices; selected swaps the edge to 2px `accent` |
| Disabled | secondary with `ink-300` text at 100% opacity | | | The shutter before gates pass |

Height 54px (option rows 56). Text `button`: 16px, 700. Minimum 44px touch target regardless of visual size.

## Rules

- Never a gradient. Never a glow. Never a shadow — the lip does the work.
- Press feedback is the lip compressing (translate 2px, lip 2px) over `instant`; no scale, no bounce.
- Primary actions sit in a bottom-anchored container with 20px margins and a hairline top border. One primary per screen.
- Dark text on a light fill, light text on a dark fill; never white on amber or gold, which fails contrast.
- A button never says "unlock", "reveal" or "your real score". There is nothing hidden to reveal.
