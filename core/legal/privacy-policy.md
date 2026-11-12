# Privacy Policy

**{app_name}** · Effective {effective_date} · Version 1.0

> **Draft for counsel review.** Written by the developer from the engineering architecture. Not legal advice; not yet reviewed by a privacy attorney. Companion documents: the [Biometric Data Retention and Destruction Policy](biometric-data-policy.md), which governs everything about face data, and the [Terms of Use](terms.md).

## The short version

Your face is measured on your phone. The images and face geometry never leave it and are deleted in seconds. The only things that can leave your phone are named measurements (numbers), and only if you turn syncing on. We don't sell data, we don't run ads, and nothing in the app is allowed to see your face except the measurement code.

## 1. What we collect

**You give us**

- A Sign in with Apple identifier. We get an Apple-relayed email address if you choose to share one; we never see a password.
- Onboarding answers: your goals, which reference table to compare you against (male or female), your age band, and how much time you have per day.
- An attestation that you are 18 or older (we store the time you attested, not a date of birth).
- Your consent decisions and when you made them.

**The app computes on your phone**

- Facial measurements derived from guided camera captures. How these are handled — captured, processed, deleted, retained — is set out in full in the Biometric Data Policy. In summary: frames, depth data and landmarks exist for seconds and never leave the device; named measurements are kept on the device; they are synced to your account only if you turn that on.
- A score, a tier, a plan of recommendations, and your habit data (which days you completed your plan, your streak, which weeks you banked).

**We collect automatically**

- Purchase and subscription status, through Apple and our subscription service (RevenueCat).
- Product analytics from a fixed allowlist of events (for example: "capture gate failed: lighting", "paywall viewed", "plan card opened"). Analytics never include a score, a measurement value, an image, any derivative of an image, or your goal text. We use PostHog.
- Crash reports, which are scrubbed of any face-derived content before transmission.

**We do not collect** your contacts, location, photo library, browsing, or advertising identifier. There is no advertising or attribution SDK in the app.

## 2. How we use it

- To measure, score and build a plan for you — on your phone.
- To keep your history across devices, if you turn on sync.
- To phrase plan copy in natural language. When this uses a cloud model, the model receives structured findings (metric names, categories like "high", your goals) and never an image, landmark, coordinate, or score. Where supported, this runs on-device instead.
- To process purchases and restore them.
- To improve capture and the product, from aggregate, non-identifying analytics.
- To comply with law and enforce our Terms.

We do not use your data to train any model. A future, separate, opt-in consent would be required for that and the app does not currently ask for it.

## 3. Who we share it with

| Who | What | Why |
|---|---|---|
| Apple | Sign-in, purchases, Declared Age Range signal | Platform |
| Supabase | Account, consent records, synced measurements (opt-in), plan and habit data | Hosting |
| RevenueCat | Purchase status | Subscriptions |
| Superwall | Which paywall layout you saw and whether you purchased | Paywall configuration |
| PostHog | Allowlisted events, no face-derived content | Analytics |
| A large-language-model provider (only when on-device phrasing is unavailable) | Structured findings and goals; no image, landmark or score | Phrasing plan copy |

None of these receive face data, because face data never leaves your device. We do not sell personal information and we do not share it for cross-context behavioural advertising.

## 4. Your choices and rights

- **Sync** is off by default and can be turned off at any time. Turning it off deletes synced measurements from our servers within 30 days.
- **Consent to measurement** can be withdrawn in Settings; the app stops measuring.
- **Delete everything** in Settings wipes local data immediately and permanently deletes server data within 30 days.
- **Access and portability:** email {contact_email} and we will export what we hold about your account.
- Residents of California and other states with comprehensive privacy laws have rights to know, delete, correct, and opt out of sale or sharing (we do none). Exercise them at {contact_email}. We will not discriminate against you for doing so.
- Residents of the EEA/UK: our legal bases are consent (measurement, sync, analytics) and contract (account, purchases). You have rights of access, rectification, erasure, restriction, portability and objection, and may complain to your supervisory authority.

## 5. Where the app isn't available

At launch, face measurement is not offered to residents of Illinois, Texas or Washington. See the Biometric Data Policy, section 10.

## 6. Children

The app is for adults 18 and over and is rated 18+. We do not knowingly collect data from anyone under 18; if we learn we have, we delete it. Contact {contact_email}.

## 7. Security

Encrypted local storage with Apple's complete data-protection class; TLS everywhere; row-level security on the server so each account can only read its own data; no passwords. Before every release we run a network-interception audit to confirm that no capture, landmark or image leaves the device on any path, including crash and analytics traffic.

## 8. Retention

See the Biometric Data Policy, section 6, for all face-related data. Account data is kept for the life of the account and deleted within 30 days of account deletion, except consent records, which we keep for three years after deletion as evidence that consent was obtained.

## 9. Changes

We will post changes here with a new version and effective date. Changes affecting face data re-prompt consent in the app.

## 10. Contact

{legal_entity} · {contact_email} · {postal_address}
