# EvidenceBadge

States how strong the research behind a metric actually is. This component is the clearest expression of the product's positioning — it is the thing no competitor ships.

## The five variants

| Grade | Treatment |
| --- | --- |
| Well supported by research | `ink-900` text, `ink-900` 1px border |
| Reasonable support | `ink-700` text, `line-200` border |
| Limited evidence | `ink-500` text, `line-200` border |
| Community metric, little evidence | `ink-500` text, `line-200` dashed border |
| Research points the other way | `caution` text, `caution` 1px border |

Exactly these five strings. No variants, no rewording.

Meaning is carried by label text and border weight, never by fill color, so a column of metric cards does not become a traffic light.

## Why the fifth variant matters

It will appear on facial width-to-height ratio, and the explanation should be direct: the community treats a higher ratio as desirable, while meta-analytic evidence associates it with lower rated attractiveness. Saying so plainly is the clearest available proof that the app reports findings rather than telling the audience what it wants to hear.

## Behaviour

Tappable, opening a sheet with the citation and a plain-English note on the strength of the research. `label` type, 2px vertical and 6px horizontal padding, `radius-sm`.
