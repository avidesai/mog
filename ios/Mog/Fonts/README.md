# Fonts

Bundled: Inter Tight (Regular, Medium, SemiBold, Bold) and Instrument Serif (Regular), converted from the
`@fontsource` woff2 builds (Latin subset) to TTF. Both are under the SIL Open Font License 1.1 — see the
LICENSE files beside them. `project.yml` lists them under `UIAppFonts`; `Typography.swift` falls back to
system fonts if any file is missing.

To refresh: `npm i @fontsource/inter-tight @fontsource/instrument-serif`, then convert with fontTools
(`TTFont(path); f.flavor = None; f.save(...)`).
