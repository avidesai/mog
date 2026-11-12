# MeasurementOverlay

The signature component, and the one thing no competitor does well. It converts a number from an assertion into an observation.

## Behaviour

The user's own capture with the geometry for **one metric at a time** drawn over it. Never several at once — a face covered in simultaneous measurement lines is the aesthetic of the apps this one competes against, and it communicates nothing.

## Rendering

| Element | Treatment |
| --- | --- |
| Photo | Full width, `radius-md`, unmodified |
| Inactive geometry | 1px `line-200` at 40% opacity — the landmark scaffold, faint |
| Active measurement | 2px `accent`, full opacity |
| Endpoints | 4px `accent` filled circles |
| Angle arcs | 2px `accent`, degree value at the arc midpoint in `mono-value` on a `paper` plate at `radius-sm` |
| Region fill | `accent-wash`, only when the metric describes an area rather than a line |
| Value callout | `mono-value-lg` on a `surface-50` plate, 1px `line-200`, positioned clear of the face |
| Frankfort horizontal | `line-200` dashed, on every profile overlay — nearly every profile angle is defined against it |

## The honesty requirement

**The photo is never retouched, brightened, smoothed or warmed.** If the capture looks unflattering, that is the capture. An app that quietly beautifies the photo it measures has invalidated its own measurement, and will be caught doing it.

## Interaction

Tapping a metric card animates the overlay from the previous metric's geometry to this one — endpoints translating, lines redrawing over 240ms. This transition is how users learn what the measurements *are*, by watching them move.

Pinch to zoom up to 3×, measurement scaling with the image. Long-press hides all geometry to show the unmarked photo — users want this constantly, and it builds trust in the photo's authenticity.

## Export

Renders the photo, one measurement, the value and a small wordmark. User action only, and never with the score attached — the score belongs to the share card.
