"""Builds the public policies site from core/legal/*.md into site/dist/.

    python site/build.py --app-name Mog --entity "Avi Desai" --email privacy@example.com \
        --address "..." --effective 2026-12-01 --base-url https://policies.example.com

Each policy is published at a versioned path (/biometric-data-policy/v1.0/) AND at a stable
alias (/biometric-data-policy/) that points at the current version. Prior versions are never
deleted — the biometric policy says all versions remain available. Deploy dist/ to GitHub Pages
or Cloudflare Pages; both are free.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
LEGAL = ROOT / "core" / "legal"
DIST = ROOT / "site" / "dist"
DOCS = [("biometric-data-policy", "Biometric Data Retention and Destruction Policy"),
        ("privacy-policy", "Privacy Policy"), ("terms", "Terms of Use")]

CSS = """
:root{--paper:#FBF9F5;--ink:#1A1714;--ink7:#4A443D;--ink5:#7A7268;--line:#E6E0D6;--accent:#2E5BFF;--raised:#F3EFE6}
@media(prefers-color-scheme:dark){:root{--paper:#15130F;--ink:#F5F1EA;--ink7:#CFC8BC;--ink5:#9B9284;--line:#332E25;--accent:#8AA5FF;--raised:#272319}}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font:16px/1.6 "Inter Tight",-apple-system,system-ui,sans-serif;-webkit-font-smoothing:antialiased}
main{max-width:720px;margin:0 auto;padding:40px 16px 80px}h1{font:400 40px/1.1 "Instrument Serif",Georgia,serif;letter-spacing:-.02em;margin:0 0 8px}
h2{font-size:20px;margin:40px 0 8px;letter-spacing:-.018em}h3{font-size:17px;margin:24px 0 6px}p,li{color:var(--ink7)}a{color:var(--accent)}
table{border-collapse:collapse;width:100%;font-size:14px;margin:12px 0}th,td{border:1px solid var(--line);padding:8px 10px;text-align:left;vertical-align:top}th{background:var(--raised);color:var(--ink)}
blockquote{margin:16px 0;padding:12px 16px;border-left:3px solid var(--accent);background:var(--raised);color:var(--ink7);font-size:14px;border-radius:0 12px 12px 0}
nav{font-size:13px;color:var(--ink5);margin-bottom:24px}nav a{color:var(--ink5);margin-right:12px}.meta{color:var(--ink5);font-size:13px;margin-bottom:32px}
footer{margin-top:64px;padding-top:16px;border-top:1px solid var(--line);font-size:13px;color:var(--ink5)}code{background:var(--raised);padding:1px 4px;border-radius:4px}
"""

PAGE = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} · {app}</title><meta name="description" content="{title} for the {app} app. Version {version}, effective {effective}."><meta name="robots" content="index,follow">
<link rel="canonical" href="{base}/{slug}/v{version}/"><style>{css}</style></head><body><main>
<nav><a href="{base}/">{app} policies</a>{navlinks}</nav>
{body}
<footer>Version {version} · effective {effective} · <a href="{base}/{slug}/">current version</a> · <a href="{base}/{slug}/versions/">all versions</a><br>{entity} · <a href="mailto:{email}">{email}</a></footer>
</main></body></html>"""

INDEX = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{app} policies</title><style>{css}</style></head>
<body><main><h1>{app} policies</h1><p class="meta">How the {app} app handles your data, in full. Every version of every policy stays published.</p>
<ul>{items}</ul><footer>{entity} · <a href="mailto:{email}">{email}</a></footer></main></body></html>"""


def render(md_text: str, subs: dict[str, str]) -> tuple[str, str]:
    for k, v in subs.items():
        md_text = md_text.replace("{" + k + "}", v)
    # strip the "Draft for counsel review" callout only when --final is passed; otherwise keep it visible
    version = re.search(r"(?:Policy version|Version)\s+(\d+\.\d+)", md_text)
    html = markdown.markdown(md_text, extensions=["tables", "sane_lists"])
    return html, (version.group(1) if version else "1.0")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--app-name", required=True); ap.add_argument("--entity", required=True); ap.add_argument("--email", required=True)
    ap.add_argument("--address", required=True); ap.add_argument("--effective", required=True); ap.add_argument("--base-url", required=True)
    ap.add_argument("--governing-law", default="the laws of the State of California"); ap.add_argument("--venue", default="San Francisco County, California")
    ap.add_argument("--final", action="store_true", help="remove the 'draft for counsel review' callouts")
    a = ap.parse_args()
    base = a.base_url.rstrip("/")
    subs = {"app_name": a.app_name, "legal_entity": a.entity, "contact_email": a.email, "postal_address": a.address,
            "effective_date": a.effective, "policy_url": f"{base}/biometric-data-policy/versions/", "governing_law": a.governing_law, "venue": a.venue,
            "terms_url": f"{base}/terms/", "privacy_url": f"{base}/privacy-policy/"}

    if DIST.exists():
        # keep previously published versions; only rebuild current ones
        pass
    DIST.mkdir(parents=True, exist_ok=True)
    manifest_path = DIST / "versions.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    navlinks = "".join(f'<a href="{base}/{s}/">{t}</a>' for s, t in DOCS)
    items = []
    for slug, title in DOCS:
        text = (LEGAL / f"{slug}.md").read_text(encoding="utf-8")
        if a.final:
            text = re.sub(r"^> \*\*Draft for counsel review\.\*\*.*?\n\n", "", text, flags=re.S | re.M)
        body, version = render(text, subs)
        page = PAGE.format(title=title, app=a.app_name, version=version, effective=a.effective, base=base, slug=slug, css=CSS, navlinks=navlinks, body=body, entity=a.entity, email=a.email)
        vdir = DIST / slug / f"v{version}"; vdir.mkdir(parents=True, exist_ok=True)
        (vdir / "index.html").write_text(page, encoding="utf-8")
        (DIST / slug / "index.html").write_text(page, encoding="utf-8")   # stable alias = current
        versions = sorted(set(manifest.get(slug, []) + [version]), key=lambda v: [int(x) for x in v.split(".")])
        manifest[slug] = versions
        vlist = "".join(f'<li><a href="{base}/{slug}/v{v}/">Version {v}</a></li>' for v in versions)
        (DIST / slug / "versions").mkdir(exist_ok=True)
        (DIST / slug / "versions" / "index.html").write_text(INDEX.format(app=a.app_name, css=CSS, items=vlist, entity=a.entity, email=a.email).replace(f"{a.app_name} policies</h1>", f"{title} — versions</h1>"), encoding="utf-8")
        items.append(f'<li><a href="{base}/{slug}/">{title}</a> <span class="meta">v{version}</span></li>')
    (DIST / "index.html").write_text(INDEX.format(app=a.app_name, css=CSS, items="".join(items), entity=a.entity, email=a.email), encoding="utf-8")
    manifest_path.write_text(json.dumps(manifest, indent=1))
    (DIST / ".nojekyll").write_text("")
    print("built", DIST, "→", [f"{s}/v{manifest[s][-1]}" for s, _ in DOCS])


if __name__ == "__main__":
    main()
