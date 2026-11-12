# App Review notes (paste into App Store Connect › App Review Information › Notes)

> The eng doc expects TrueDepth usage to draw questions (risk #6). These notes answer them before they're asked. Keep under 4,000 characters; this version is ~2,900.

---

**What the app does.** {app_name} measures facial proportions (e.g. canthal tilt, nasolabial angle) from guided front-camera captures, compares them against published anthropometric reference ranges with citations, and suggests self-directed habits (sunscreen, sleep, posture, gradual fat loss) graded by evidence strength. It is for adults 18+ and is rated 17+ / 18+ accordingly.

**TrueDepth / ARKit usage (Guideline 5.1.2(vi), 2.5.13).** ARKit face tracking is used for exactly two purposes: (1) measuring the distance from the camera to the face so that captures are only accepted between 45–75 cm, because perspective distortion at closer range changes measured proportions by up to ~30%; (2) measuring head yaw/pitch/roll so that captures are only accepted within ±3°. Face mesh and depth data exist in memory only until measurements are computed (seconds) and are never written to disk, never transmitted, and never exposed to any third-party SDK. No face data is used for advertising, marketing, analytics, or data mining. No third party receives it. We run a network-interception audit before every release and can supply the trace on request.

**Camera and face data never leave the device.** Only scalar measurements (named numbers like "canthal tilt 4.1°") can be synced, and only if the user opts in separately in Settings. The privacy policy and a dedicated biometric data retention policy are linked in-app and at {policy_url}.

**Consent.** Before the first capture the app shows a plain-English consent screen (what is captured, where it is processed, what is retained, how to delete) with an explicit "I consent" action separate from the Terms and from any purchase.

**Subscriptions (3.1.2).** Weekly, annual (3-day free trial) and lifetime. Price, period and auto-renewal terms are displayed on the paywall itself; Terms and Privacy links are on the paywall; a close control is visible from the first frame; Restore Purchases is on every paywall. The free tier includes the user's real score and tier — the same number shown to paying users — so there is no bait-and-switch.

**Health and safety (1.4.1, 5.1.1(iii)).** The app does not diagnose and does not provide medical advice. Recommendations come from a fixed, human-reviewed table; a generative model is used only to reword pre-approved copy and cannot add a recommendation. Prescription or surgical topics are only ever named with a referral to a licensed professional, never dosed or recommended, and the app states it has no financial relationship with any provider. A hard-coded exclusion list prevents dangerous practices (e.g. self-inflicted facial trauma, performance-enhancing drugs, caloric targets) from ever appearing. Scans are rate-limited and a non-intrusive wellbeing note with the 988 line appears if usage patterns suggest distress.

**Age (5.1.4, Texas SB 2420).** 18+ rating; self-attestation of age at onboarding; Declared Age Range API consumed where available; capture blocked on under-18 signals; date of birth not stored.

**Sign in with Apple** is the only sign-in method (4.8).

**Demo.** Reviewer account not needed; Sign in with Apple works with any Apple ID in sandbox. To exercise capture, hold the device 50–60 cm from the face in even light with a neutral expression; the shutter fires automatically once the on-screen checks pass. A demo video is attached showing the full flow.

**Geographic note.** Face measurement is not offered to users who attest residence in Illinois, Texas or Washington, pending state-specific legal review. All other features function there.

Contact for review questions: {contact_email}.
