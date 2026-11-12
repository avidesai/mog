# Legal set — status and what to do with it

| Document | Status | Hosting |
|---|---|---|
| `biometric-data-policy.md` | Draft, counsel review needed | Must be **publicly hosted** before the first capture is possible (BIPA 15(a) requires a public written policy). Linked from the Consent screen and the App Store listing. |
| `privacy-policy.md` | Draft, counsel review needed | Required by App Store Review 5.1.1. Linked from the paywall, Settings, and the App Store listing. |
| `terms.md` | Draft, counsel review needed | Linked from the paywall (3.1.2 requires a terms link on the paywall surface). |
| Consent screen copy | In `copy/strings.json` → `consent.*` | In-app. |

**Placeholders to fill:** `{app_name}` `{legal_entity}` `{contact_email}` `{postal_address}` `{effective_date}` `{policy_url}` `{governing_law}` `{venue}`.

**Decisions embedded in these drafts (change the drafts if you change the decision):**

- Illinois, Texas and Washington excluded from face measurement at launch via in-app state attestation (eng doc, "The legal gap"). Everything else in the app works there.
- Server-side deletion within 30 days; consent records kept 3 years post-deletion as evidence.
- Sync is a second, separate consent, off by default. A third consent for calibration contribution exists in the schema and is not asked for yet.
- No advertising or attribution SDK at launch. Adding one later requires an audit that it cannot reach face data (5.1.2(vi)).
- Date of birth is never stored; attestation timestamp is.

**Hosting at zero cost:** a GitHub Pages or Cloudflare Pages site on the ~$15 domain in the budget. Each policy at a stable URL with the version in the page, prior versions kept.

**The first thing revenue funds** is a privacy attorney's review of these three documents and of the question whether derived scalar measurements are "biometric identifiers" under BIPA, CUBI and MHMDA.
