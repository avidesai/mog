# tools

- `gen_tokens.py` — regenerates `ios/Mog/Design/Tokens.swift` from `design/design-system/tokens.json`. Run after any token change.
- Spike analysis lives in `core/tools/cv_analysis.py` (it needs the scorer).
- `render_screens.py` — renders the 28 artboards to PNG with the bundled fonts (`--store` adds the 7 captioned App Store shots at 1290×2796 into `design/renders/store/`, which is committed; the raw renders are not).
