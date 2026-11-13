"""Renders the v1 artboards to PNG with the bundled fonts — for the App Store, for visual QA, and
for anyone who can't open the Claude Design canvas.

    python tools/render_screens.py                      # all boards → design/renders/<name>.png @3x (1170×2532)
    python tools/render_screens.py --store              # the 7 App Store shots with captions → design/renders/store/*.png (1290×2796)

The .dc.html artboards @import Google Fonts; we strip that and inject design/fonts/fonts.css so the
render is faithful offline. support.js (the canvas runtime) is not needed for static rendering.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import re
from pathlib import Path

from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parent.parent
BOARDS = ROOT / "design" / "screens-gamified"
FONTS = (ROOT / "design" / "fonts" / "fonts.css").read_text()
OUT = ROOT / "design" / "renders"

# App Store order and captions (core/appstore/listing.md)
STORE = [
    ("Reveal", "A score with its uncertainty, every time."),
    ("Capture", "The shutter waits until the measurement will be valid."),
    ("MetricDetail", "Every number shown on your own face, with its reference range."),
    ("ResultsOverview", "What the research actually supports."),
    ("Main", "A plan built from your findings, not a list of tips."),
    ("Journey", "Eight weeks. Re-scan when something can have changed."),
    ("Methodology", "How the score works, in full."),
]


def prepare(html: str) -> str:
    html = re.sub(r"<script src=\"\./support\.js\"></script>", "", html)
    html = re.sub(r"@import url\('https://fonts\.googleapis\.com[^']*'\);", "", html)
    # x-dc/helmet are custom elements the runtime unwraps; make them inert boxes
    html = html.replace("<x-dc>", '<div class="x-dc">').replace("</x-dc>", "</div>").replace("<helmet>", "<div>").replace("</helmet>", "</div>")
    fonts = FONTS.replace('url("', f'url("file://{ROOT}/design/fonts/')
    return html.replace("</head>", f"<style>{fonts} html,body{{margin:0;background:#FBF9F5}} .x-dc>div:first-child{{display:none}}</style></head>")


async def render(boards: list[str], scale: int, store: bool) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "store").mkdir(exist_ok=True)
    async with async_playwright() as p:
        b = await p.chromium.launch()
        ctx = await b.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=scale)
        page = await ctx.new_page()
        for name in boards:
            src = BOARDS / f"{name}.dc.html"
            page_html = prepare(src.read_text(encoding="utf-8"))
            await page.set_content(page_html, wait_until="load")
            await page.evaluate("document.fonts.ready")
            await page.screenshot(path=str(OUT / f"{name}.png"), clip={"x": 0, "y": 0, "width": 390, "height": 844})
            print("rendered", name)
        if store:
            # 6.9" shots: 1290×2796. Device frame = the screen render centered on paper with the caption above.
            cap_ctx = await b.new_context(viewport={"width": 430, "height": 932}, device_scale_factor=3)
            cp = await cap_ctx.new_page()
            for name, caption in STORE:
                import base64
                shot = "data:image/png;base64," + base64.b64encode((OUT / f"{name}.png").read_bytes()).decode()
                html = f"""<!doctype html><html><head><style>{FONTS.replace('url("', f'url("file://{ROOT}/design/fonts/')}
                html,body{{margin:0;width:430px;height:932px;background:#FBF9F5;font-family:'Inter Tight'}}
                .cap{{position:absolute;left:28px;right:28px;top:56px;font-family:'Instrument Serif';font-size:34px;line-height:1.1;letter-spacing:-.02em;color:#1A1714}}
                .frame{{position:absolute;left:38px;top:168px;width:354px;height:766px;border-radius:40px;overflow:hidden;border:1.5px solid #E6E0D6;background:#000}}
                .frame img{{width:354px;height:766px;display:block;object-fit:cover}}
                </style></head><body><div class="cap">{caption}</div><div class="frame"><img src="{shot}"></div></body></html>"""
                await cp.set_content(html, wait_until="load")
                await cp.evaluate("document.fonts.ready")
                await cp.screenshot(path=str(OUT / "store" / f"{STORE.index((name, caption)) + 1:02d}-{name}.png"))
                print("store shot", name)
        await b.close()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--store", action="store_true")
    ap.add_argument("--only", nargs="*")
    a = ap.parse_args()
    idx = json.loads((BOARDS / "canvas.json").read_text())
    boards = [Path(k).stem.replace(".dc", "") for k in idx["boards"]]
    if a.only:
        boards = [x for x in boards if x in a.only]
    asyncio.run(render(boards, 3, a.store))


if __name__ == "__main__":
    main()
