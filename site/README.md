# site — public policies

Static build of `core/legal/*.md`. Versioned URLs (`/biometric-data-policy/v1.0/`), a stable alias per policy, and a versions index — prior versions are never removed, which is what the biometric policy promises.

```
python site/build.py --app-name Mog --entity "<legal entity>" --email privacy@<domain> \
  --address "<postal>" --effective 2026-12-01 --base-url https://policies.<domain> [--final]
```
`--final` strips the "draft for counsel review" callouts; leave it off until counsel has signed off.

`dist/` is gitignored; `.github/workflows/site.yml` builds and deploys to GitHub Pages on push when the repository variable `POLICIES_BASE_URL` is set. Point the custom domain at Pages (free), then put the resulting URLs into `ios/` (search for `example.invalid`) and the App Store listing.
