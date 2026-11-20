# Fonts

Bundled: Inter Tight (Regular, Medium, SemiBold, Bold) and Instrument Serif (Regular), converted from the
`@fontsource` woff2 builds (Latin subset) to TTF. Both are under the SIL Open Font License 1.1. See the
LICENSE files in `app/assets/fonts/`, where the Exact app keeps its copies (`app/ui.contract` names them).
`fonts.css` here is what `tools/render_screens.py` injects into the artboards.

To refresh: `npm i @fontsource/inter-tight @fontsource/instrument-serif`, then convert with fontTools
(`TTFont(path); f.flavor = None; f.save(...)`).
