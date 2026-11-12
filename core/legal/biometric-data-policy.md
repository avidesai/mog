# Biometric Data Retention and Destruction Policy

**{app_name}** · Effective {effective_date} · Policy version 1.0

> **Draft for counsel review.** This document was written by the developer from the engineering architecture, not by a lawyer. It is structured to satisfy the public-policy requirement of the Illinois Biometric Information Privacy Act (740 ILCS 14/15(a)), the consent-and-destruction requirements of Texas Bus. & Com. Code § 503.001, and the consumer-health-data obligations of the Washington My Health My Data Act, but it has not been reviewed by counsel in any of those states. Counsel review is the first expense this product will fund.

## 1. Who we are

{legal_entity} ("we") publishes the {app_name} iPhone application. Contact: {contact_email}. Postal: {postal_address}.

## 2. What this policy covers

This policy covers biometric identifiers and biometric information as those terms are used in state biometric privacy laws — in our case, data derived from scanning your face geometry — and consumer health data as defined by the Washington My Health My Data Act, which expressly includes biometric data.

## 3. What we collect, and where it exists

When you choose to take a measurement, and only after you have given the consent described in section 5, the app:

| Data | Where it exists | How long | Leaves your device? |
|---|---|---|---|
| Camera frames (ten per capture) | Your phone's memory only | Until measurements are computed — seconds | **Never** |
| TrueDepth depth data | Your phone's memory only | Seconds | **Never** |
| Face landmark coordinates and mesh | Your phone's memory only | Seconds | **Never** |
| **Measurements** (named scalar values, e.g. "canthal tilt 4.1°") | Encrypted storage on your phone | Until you delete them | Only if you turn on sync (section 4) |
| Score, tier and plan | Encrypted storage on your phone | Until you delete them | Only if you turn on sync |
| Your consent record (which policy version, when) | Your phone and our server | Until account deletion + the period in section 7 | Yes — this is how we prove consent |

Measurements are numbers. They are not an image, a template, or a descriptor from which a face can be reconstructed or matched. We nonetheless treat them with the care this policy describes, because whether derived scalar measurements constitute "biometric information" under some statutes is unsettled.

## 4. What we never do

- We never transmit, upload, or store a photograph, video frame, depth map, landmark set, mesh, embedding, or any other biometric template off your device. There is no code path in the app that does this. We verify it before every release with a network-interception audit and keep the trace.
- We never sell, lease, trade, or otherwise profit from biometric identifiers or biometric information.
- We never disclose biometric identifiers or information to a third party, except as required by a valid legal process, and never to advertising, analytics or attribution services.
- We never use face data for marketing, advertising, or use-based data mining, and no third-party SDK in the app can access it (Apple App Store Review Guideline 5.1.2(vi)).
- We never use your data to identify you, to match you against any database, or to compare you against other users.

## 5. Consent

Before the first capture, and again whenever this policy's version changes, the app shows you what is captured, where it is processed, what is kept, for how long, and how to delete it, and asks you to take a specific affirmative action — tapping a control labelled "I consent" — that is separate from accepting the Terms, separate from any purchase, and never pre-selected. The time and the policy version are recorded.

Syncing measurements to your account is a second, separate, opt-in consent, off by default and revocable in Settings at any time. Contributing to any future calibration dataset would be a third, separate consent; the app does not currently ask for it.

Withdrawing consent stops all further measurement immediately.

## 6. Retention schedule

| Data | Retention | Destruction |
|---|---|---|
| Camera frames, depth data, landmarks, mesh | Seconds; discarded the moment measurements are computed | Memory released; never written to disk |
| Measurements, scores, plans, habit data on your device | Until you delete them or delete the app | Encrypted store wiped on "Delete everything" |
| Synced measurements (opt-in) | Until you turn sync off, delete everything, or delete your account | Permanently deleted from our servers and backups within **30 days** |
| Consent records | For the life of the account and **3 years** after deletion, as evidence that consent was obtained | Deleted at the end of that period |
| Account identifier (Sign in with Apple) | Life of the account | Tombstoned at deletion so a later sign-in creates a new, unlinked account |

In all cases, biometric identifiers and information are permanently destroyed no later than the earlier of (a) the point at which the initial purpose for collecting them has been satisfied, or (b) three years after your last interaction with us. In practice, for the only true biometric data we handle — frames, depth, landmarks — that point is seconds after capture.

## 7. How to delete

Settings › Your data › **Delete everything.** This wipes all local data immediately and queues permanent server-side deletion of anything synced, completed within 30 days. You can also email {contact_email}. Deletion is tested automatically against our production schema on every release.

## 8. Security

Local data is stored in an encrypted container with Apple's complete data-protection class (inaccessible while the device is locked). Server data is stored with row-level security such that each account can read only its own rows. All transport is TLS. There is no password: authentication is Sign in with Apple only.

## 9. Age

The app is for adults 18 and over. We rate the app 18+ in the App Store, consume Apple's Declared Age Range API where available, and ask you to attest that you are 18 or older. We store the time of that attestation, not your date of birth. We do not knowingly collect any data from anyone under 18; if we learn that we have, we delete it.

## 10. Availability by state

At launch we do not offer face measurement to residents of Illinois, Texas or Washington. This is a conservative choice made because we have not yet had counsel review in those states, not because our handling differs there. Every other feature of the app is available.

## 11. Changes

A change to this policy bumps its version and re-prompts consent before the next measurement. The current and all prior versions are available at {policy_url}.

## 12. Contact

{contact_email} · {postal_address}
