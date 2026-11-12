# Building a Looksmaxxing Face-Analysis App: Foundation Research and Plan (November 2026)

# Building a Looksmaxxing Face-Analysis App: Foundation Research and Plan (November 2026)

**Bottom line: there is a real, proven, and currently under-served opportunity here.** The category makes money: Umax hit $6M ARR in 3.5 months. But the leading apps are stale, inconsistent, or distrusted. Clavicular's own app, Face Harmony, launched in July 2026 and sits at 2.3 stars. That leaves room for an app positioned as *the honest, consistent, evidence-graded one*. The catch: "extremely unbiased and as accurate as possible" can only mean *consistent, transparent, calibrated measurement plus an honest estimate*. It cannot mean objective truth about attractiveness. Biometric privacy law, minors, and harmful advice are the three things that can kill the business.

## TL;DR

- **Opportunity and v1:** Build an iPhone app with this loop: guided front + profile capture → on-device landmark geometry → calibrated 0–10 estimate with a confidence band and per-metric harmony breakdown → personalized, evidence-graded improvement plan tied to each finding. Body scan, try-on, community, and Android wait until after product-market fit. Your differentiators are repeatability (same face → same score), transparency, and no fake teaser scores. Competitors are weakest on exactly these.
- **Monetization:** Put a hard paywall *after* a genuinely useful free result. Free gets the overall band plus your top strength and top fixable weakness. Paid gets the full breakdown, plan, profile analysis, and re-scans. Price around $4.99/week and $29.99–$39.99/year, and test a $59.99 lifetime option. RevenueCat's State of Subscription Apps 2026 (March 2026; 115,000+ apps, $16B+ revenue) puts the Day-35 median at 10.7% for hard paywalls vs 2.1% for freemium, about 5x better, though hard-paywall conversion has slipped from 12.1% in 2025. But don't copy the category's fake-score and broken-referral tactics, which are what tank ratings.
- **Top risks:**
  - Biometric law: Illinois BIPA (active 2025–2026 suits against face-scanning beauty apps), Texas CUBI ($25,000 per violation), and Washington MHMDA (private right of action). Mitigate with on-device processing, explicit written consent, and no stored templates.
  - Minors: Texas's app-store age law has been live since June 2026, and the amended COPPA Rule covers facial templates. Launch 18+.
  - Harm and reputation: Jasmine Reese, M.D., who directs Johns Hopkins All Children's adolescent clinic, said in August 2026 that "we've seen a huge uptick in teens, even pre-teens, with eating disorders, with body dysmorphia," and she names AI rating apps as part of the trend. Exclude dangerous advice and frame findings constructively.

---

## Key Findings

1. **The category is lucrative but dominated by thin, aging products.** Umax founder Blake Anderson said the app "hit $6 million annual recurring revenue in just 3.5 months." Fortune (Alexandra Sternlicht, July 1, 2024) reported that Umax was "raking in about $500,000 in subscription revenue monthly, according to Blake Anderson," and added that the figure "could not be independently verified." Yet Umax's last US App Store update was June 2024 (4.56 stars, 51,646 ratings), and LooksMax AI's was April 2024 (4.52, 42,725), per Real World Appeal's October 2026 audit.
2. **Clavicular's app is a cautionary tale, and it also validates demand.** Face Harmony by Clavicular launched July 22, 2026. Its developer claims it hit the top 10 on day one, built as an MVP "in 3 days," and admitted "people rightly said it's mid." It sits at 2.3 stars. Reviews complain of a "fake score" before the paywall, $9.99/week pricing, and alleged sending of face-derived data to a server despite on-device claims.
3. **The weekly-subscription, paywall-after-scan model is universal.** 16 of the 19 App Store apps Real World Appeal reviewed list a weekly plan, and most show the full result only after payment or referrals. The model converts, but it is also the main source of 1-star reviews and press criticism.
4. **The science supports *some* of what the community measures, and contradicts some of it.** Raters agree strongly on who is attractive: r = .90 interrater reliability for adults and r = .94 cross-culturally (Langlois et al., 2000). But individual "private taste" is large: Leder et al. (2016) put it at "only about 40% of the meaningful variance" for faces, and Kramer et al. (2024) found it "explained approximately half of the variance." Geniole et al.'s 2015 PLOS ONE meta-analysis found *higher* FWHR is associated with *lower* rated attractiveness (k = 14, r = −.26, 95% CI −.40 to −.10), the opposite of community lore.
5. **Phone-camera geometry is a serious accuracy trap.** Ward, Ward, Fried & Paskhover (Rutgers–Stanford, JAMA Facial Plastic Surgery, 2018) found that a selfie taken at about 12 inches makes the nasal base look roughly 30% wider (30% in men, 29% in women) and the nasal tip about 7% wider than a photo taken at 5 feet. This explains the most common complaint ("same picture 3 times, different number"). Fixing it is your clearest technical moat.
6. **Distribution here is creator-driven.** Cal AI, from the same founder circle, grew from $30K in month one to $1M/month by month six. At TechCrunch Disrupt in October 2026, founder Zach Yadegari said influencer marketing, not UGC or ads, "really took us off." Cal AI's first paid story post (~$2,000) brought ~1,000 downloads in 2 days. MyFitnessPal acquired Cal AI in March 2026.

---

## 1. Recap and Decision Map

| Element | Your intent | Recommendation |
|---|---|---|
| Audience | looksmax.org users, Clavicular-style followers | Same, but 18+ at launch. Copy should also appeal to larger, less toxic "normie" self-improvers. |
| Platform | iPhone-first | Native Swift/SwiftUI; Android later |
| Capture | All angles, maybe body | v1: guided front + right profile (3/4 optional). Body in v2. |
| Output | 0–10 + breakdown + harmony metrics | 0–10 estimate with confidence band, a PSL-tier label, and per-metric cards with "evidence strength" badges |
| Principle | "Unbiased," "accurate" | Reframe as "consistent, transparent, calibrated." Publish test-retest and fairness numbers. |
| Advice | Tailored, linked to scan evidence | Rules engine keyed to findings + goals. LLM only phrases. Hard exclusions for dangerous practices. |

**Decisions to make, by area:**
- **Product:** score philosophy (hybrid recommended); scale (0–10 primary, PSL tier as label); sex-specific norms and age bands; ethnicity-aware reference ranges, never a penalty; how to display weak-evidence metrics; goal intake; re-scan cadence.
- **Science:** metric definitions, ideal ranges and their sources, evidence grades, calibration dataset and rater panel. The panel is the biggest open item.
- **Engineering:** capture gating, landmarking, normalization, scoring, LLM layer, backend, cost per scan.
- **Legal/platform:** App Store 5.1.1, 5.1.2(vi), 3.1.2, 4.3; age rating; biometric consent; retention; minors.
- **Monetization:** paywall position, free-tier depth, prices, trial, lifetime, upsells.
- **UX:** onboarding length, reveal, share cards, retention loops, avoiding dark patterns.
- **Marketing:** creator program, owned faceless accounts, forum seeding, ASO, later paid ads.

---

## 2. Domain Deep Dive

### 2.1 Community rating scales

The PSL scale is named for the forums PUAHate, SlutHate, and Lookism. It is deliberately harsh: "average" sits around 4–5, and tier boundaries differ by site. That inconsistency is itself useful: there is no canonical standard, so you can define and publish yours.

| PSL tier | Typical PSL range (varies) | Population share cited | ≈ "normie" 0–10 |
|---|---|---|---|
| Sub5 | < ~3.5 | bottom ~25% | 1–4 |
| LTN | ~3.5–4.5 | ~25th–40th pct | 4–5 |
| MTN | ~4.5–5.5 | middle | 5–6 |
| HTN | ~5.5–6.5 | top ~15–25% | 7 |
| Chadlite | ~6.5–7.5 | top ~5–10% | 8 |
| Chad/Gigachad | 7.5+ | top ~1% | 9–10 |

These percentages are community lore, not empirical data. **Recommendation:** define your 0–10 as a *percentile* against your own calibrated, sex-specific, age-banded reference panel, and display the PSL tier derived from that percentile.

### 2.2 Facial metric taxonomy

Evidence key: **Strong** means robust and replicated. **Moderate** means some replicated support. **Weak/Lore** means little or contrary evidence.

| Metric | Measurement | Commonly cited "ideal" | Phone-measurable? | Evidence |
|---|---|---|---|---|
| Averageness | Landmark distance from population mean shape | Closer = better | Yes, needs reference set | **Strong**, among the most replicated |
| Symmetry | Mirrored landmark deviation | Higher | Yes, but pose/expression noise often exceeds real asymmetry | **Moderate**, smaller than lore claims |
| Sexual dimorphism | Shape on a male–female axis | Men moderate-high masculinity; women femininity | Yes (shape model) | **Moderate** for women; **mixed** for men |
| Skin quality | Color homogeneity, texture, acne, redness | Clear, even | Partially; lighting-dependent | **Strong**, and most improvable |
| FWHR | Bizygomatic width ÷ upper face height | Community: ≥ ~1.9–2.0 | Yes, moderate reliability | **Contradicts lore.** Geniole et al. (2015): higher FWHR judged *less* attractive (r = −.26, k = 14), more threatening (r = .46), more dominant (r = .20), more masculine (r = .35); sex difference small (d = .11) |
| Facial thirds | Trichion–glabella–subnasale–menton | ~1:1:1 | Middle/lower yes; upper unreliable (hairline) | **Weak-moderate** clinical convention |
| Facial fifths | Width in eye-widths | Each ≈ one eye width | Yes | **Weak** |
| Midface ratio | IPD ÷ pupil-to-lip height | ~1.0 | Yes | **Lore** |
| Canthal tilt | Inner-to-outer canthus angle | Positive (~+4 to +8°) | Yes, after roll correction | **Weak-moderate**; ethnicity-dependent baseline |
| Eye spacing (ESR) | IPD ÷ bizygomatic width | ~0.45–0.47 | Yes | **Moderate** (ties to averageness) |
| Upper eyelid exposure / "hunter eyes" | Lid show, brow-lash distance | Low exposure | Partially (coarse eyelid landmarks) | **Lore/weak** |
| Gonial angle | Jaw-corner angle | ~115–125° men | Profile only; noisy with fat/beard | **Weak-moderate** |
| Bigonial ÷ bizygomatic | Jaw vs. cheek width | Men ~0.85–0.9+ | Yes; gonion noisy | **Moderate** (via dimorphism) |
| Chin-to-philtrum; chin projection | Chin height ÷ philtrum; projection in profile | ~2–2.25× (men) | Ratio yes; projection profile | **Weak-moderate** |
| Maxillary "forward growth" | Midface projection vs. forehead/chin | Community's top "bone" metric | Only crudely, even with depth (soft tissue masks bone) | **Weak as measured.** Midface deficiency is real clinically, but there is no validated phone measure |
| Zygomatic prominence | Cheekbone width/projection | High, wide | Width yes; projection needs 3/4 or depth | **Moderate** |
| Nasofrontal / nasolabial / mentolabial angles | Profile angles | ~115–135° / ~90–110° (sex-dependent) / ~120–130° | Profile | Clinical norms; **minor-moderate** effect |
| Facial convexity, E-line | Glabella–subnasale–pogonion; lip vs. nose-chin line | ~165–175°; lips slightly behind | Profile | **Moderate**; retruded-chin profiles rated lower in orthodontic studies; ethnicity-dependent |
| Cervicomental angle | Neck-chin angle | ~105–120° | Profile; pitch- and fat-sensitive | **Moderate**, and improvable via leanness |
| Hairline/density | Recession, density | Full | Partially (coarse Norwood) | **Strong** for men; actionable |
| Facial adiposity | Perceived facial fat | Lower, within health | Yes (learned) | **Strong**; improvable |
| Lips, teeth/smile | Fullness; alignment, color | ~1:1.6 lips; straight, white | Yes; smile photo needed | **Moderate-strong**; actionable |

**Design takeaways:**
- The **best-evidenced** drivers (averageness, skin, adiposity, hair, dimorphism, grooming) are also the **most improvable**.
- The community's favorite bone metrics (maxilla, gonial angle, canthal tilt, hunter eyes, FWHR) are the least validated, least photo-measurable, and least changeable. Show them because the audience demands them, but badge them "community metric, limited evidence" and keep their weight in the score low.
- Many "ideal ranges" online trace back to forum posts, not studies. Before launch, source each one to a clinical norm or label it as community convention.

### 2.3 Body metrics (v2)

| Metric | Photo-measurable? | Evidence |
|---|---|---|
| Body fat / leanness | Roughly; ± several % | Strong; most actionable lever |
| Shoulder-to-waist (men) | Yes with pose estimation, fitted clothing | Moderate-strong (V-taper preferred) |
| Waist-to-hip (women) | Yes, same caveats | Strong-moderate (~0.7 classic; BMI often explains as much) |
| Height | **No** from a single photo | Strong preference effect. Ask, don't estimate. |
| Posture | Yes from profile | Moderate; actionable |
| Neck, clavicle "frame" | Rough | Community emphasis (Clavicular's handle refers to clavicle width); weak evidence |

Keep body analysis for v2. Shirtless photos, often from teens, multiply privacy, moderation, and minors risk.

### 2.4 "Unbiased and accurate": what you can honestly claim

**How subjective is attractiveness?**
- **Consensus is real.** Langlois et al.'s (2000) meta-analysis found r = .90 adult interrater agreement and r = .94 cross-cultural agreement. A Scottish vs. Black South African comparison found cross-cultural agreement of r = 0.62.
- **Private taste is just as real.** Hönekopp (2006) found that stable private taste and shared taste contribute roughly equally. Leder et al. (2016) put private taste at ~40% of meaningful variance for faces. Kramer et al. (2024) found it explained about half the variance across response scales.
- **Implication:** the best possible model predicts the *average* rater, not any individual. Say "how the average stranger would likely rate this photo," with an error band.

**Datasets and their biases:**
- **SCUT-FBP5500** (the standard benchmark): 5,500 frontal faces, of which 2,000 are Asian female, 2,000 Asian male, 750 Caucasian female, and 750 Caucasian male. Ages 15–60, each rated 1–5 by 60 raters. Models reach Pearson ~0.87–0.90.
- **Its limits:** only two ethnic groups, Asian-heavy. Hamel et al. (2025) found models trained on SCUT-FBP5500 and MEBeauty show statistically significant ethnicity bias even from "seemingly balanced" sources. Annotators from different cultures systematically favor own-ethnicity aesthetics. **SCUT-FBP5500 is licensed for non-commercial research. Do not ship a model trained on it.**
- **Takeaway:** your own commercially licensed, diverse, rated calibration panel is the core long-term moat and the biggest open research item.

**Designing for consistency, calibration, fairness:**
1. **Consistency:** use a strict capture protocol, multi-frame and multi-capture averaging, and deterministic scoring (no LLM in the number). Target and publish a test-retest SD ≤ 0.2 points on the 10-point scale.
2. **Calibration:** map outputs to percentiles of a stratified reference panel with 20+ ratings per face, using sex-specific distributions.
3. **Fairness:** stratify faces and raters by ethnicity, sex, and age, and report error and score distributions per group. Never use ethnicity as a negative feature. Use ethnicity-aware *reference ranges* only where population variation is known (canthal tilt, nasal angles, E-line).
4. **UI honesty:** "Estimated 6.4 (likely range 5.9–6.9)," plus what drives it.

**Complaints about existing apps:**
- Inconsistent scores: "submitted the same picture 3 times, got a different number" is a recurring Umax complaint.
- Apps disagreeing with each other.
- Teaser or fake pre-paywall scores (Face Harmony).
- Paywalls that land after the upload.
- Referral unlocks that don't work: Fortune found Umax's "refer three friends" waiver failed.
- Generic advice.

### 2.5 Improvement strategies: evidence, safety, app policy

| Intervention | Addresses | Evidence / safety | Policy |
|---|---|---|---|
| Skincare basics (cleanser, moisturizer, SPF) | Skin evenness, redness | Strong, low risk | ✅ Personalized |
| OTC actives (adapalene 0.1%, benzoyl peroxide, azelaic acid, niacinamide) | Acne, texture, pigmentation | Strong for acne | ✅ With irritation guidance |
| Tretinoin, isotretinoin | Persistent acne, photoaging | Rx; isotretinoin has serious risks | ⚠️ "See a dermatologist." Never dose. |
| Haircut/hairstyle | Face shape, forehead, hairline | Strong practitioner consensus; zero risk | ✅ Core v1 value |
| Grooming (brows, beard to add jaw definition) | Weak jaw/chin, brows | Moderate | ✅ |
| Body-fat reduction | Facial adiposity, cervicomental angle, jaw visibility | Strong; reveals the jaw more than any "jaw exercise" | ✅ Sane rates only; eating-disorder safeguards |
| Resistance training, posture | V-taper, forward head | Strong / moderate | ✅ |
| Sleep, alcohol reduction | Under-eye, skin | Moderate | ✅ |
| Photo optimization (distance, lighting, angle) | Perceived nose size, photo symmetry | Strong (selfie study) | ✅ Easy dating-profile win |
| Whitening; orthodontics/aligners | Smile | Strong (dental) | ✅ Whitening; ortho → "see an orthodontist" |
| Topical minoxidil | Hair density | Strong; FDA-approved OTC | ✅ Mention + "consult a doctor"; no oral dosing |
| Finasteride | Male pattern hair loss | Strong efficacy; Rx; side-effect controversy | ⚠️ Inform + refer only |
| Fillers, Botox, rhinoplasty, genioplasty, implants, orthognathic surgery, canthoplasty | Chin, profile, etc. | Real effects; medical risk | ⚠️ "Options a board-certified surgeon may discuss." 18+ only, no clinic affiliate links |
| **Mewing** | "Forward growth" | **No adult evidence.** In a 23 May 2025 statement signed by President Dr Robbie Lawson, the British Orthodontic Society said: "There is no scientific evidence to suggest patients can change the shape of their face… by chewing or holding teeth and the tongue in a closed position." AAO warned similarly (March 2025). Mike Mew was erased from the UK dental register in November 2024. | ❌ Not a structural fix. Optional myth-busting card. |
| Bone smashing | — | Dangerous, no evidence | ❌ Exclude and warn |
| Steroids/SARMs, unregulated peptides, DNP, stimulant diet pills, black-market hormones | — | Serious harm. California's AB 2030 restricts minors' diet-pill purchases, citing looksmaxxing. | ❌ Exclude. Clavicular sells "research-grade peptides," so a partnership imports this risk. |
| GLP-1s for aesthetics | Adiposity | Effective Rx; misuse risk | ⚠️ Doctor only |
| Leg-lengthening | Height | Major surgery | ❌ Exclude |

**Linking recommendations to findings:**
- Each card is a rule: `trigger(finding, threshold, confidence) + goal_match + safety_tier + evidence_grade → card`.
- Example: *"Facial adiposity: high (confidence medium). Cervicomental angle: obtuse. Goal: 'sharper jawline.' → 'Your profile suggests a softer jaw-neck transition. The strongest evidence-backed lever is lowering body fat (~0.5–1% bodyweight/week)…' Evidence: Strong. [Profile overlay shows the angle.]"*
- The LLM rewrites wording only. It never invents interventions.

---

## 3. Competitive Landscape

US App Store ratings and prices below are from Real World Appeal's 17 Oct 2026 audit unless noted. Revenue is labeled as either a founder statement or a third-party estimate. Third-party estimates are often off by 2–5x.

| App | What it does | Rating (count) | Last update | Revenue/downloads | Likes / complaints |
|---|---|---|---|---|---|
| **Umax** (Improvement Tech; Blake Anderson) | Selfie → jawline, cheekbones, masculinity, skin, "potential"; partly powered by OpenAI tech (Fortune) | 4.56 (51,646) | June 2024 | Founder: $6M ARR in 3.5 months; Fortune ~$500K/mo (2024); founder later "350 to 400(k) a month." "7M downloads" unverified. | Fast, shareable default / inconsistent, weekly price, buggy, referral failed |
| **LooksMax AI** (Mnkybrain Labs) | Ratings + tips; one-off AI hairstyle pack; "mog battle" | 4.52 (42,725) | April 2024 | AppMagic ~$488K lifetime at its report; other estimates $15K–$55K/mo (low confidence) | Sample results up front / paywall before analysis, live "people just revealed" counter |
| **PSL – Looksmax & Ascend** (IQ Labs) | PSL-framed rating | 4.70 (11,997) | July 2026 | Est. ~$55K/mo (low confidence) | Maintained; uses community vocabulary |
| **Mogged**, **LooksLab** | Glow-up rating; credits | 4.73 (3,234); 4.68 (1,875) | July/Aug 2026 | n/a | — |
| Long tail: AscendMax, Lookist, Blackpill AI, RateByFresh, ModelMax, Pryme AI, GlowMax, MogMax, Areum, Potential AI, Glowvia, PSL AI-Morph, Appeal | Selfie → score → tips; image/haircut packs | 3.2–4.8, mostly < 1,000 ratings | 2026 | n/a | Clone saturation means low barriers and Apple 4.3 risk |
| **Face Harmony by Clavicular** (seller Nathan Kest; ID 6781068829) | Symmetry, jawline/midface, canthal tilt, side profile, history, suggestions | **2.3 (106–108)** | v1.1.2, July 28, 2026 | Developer: "top 10… first day" (unverified) | Fake pre-paywall score, $9.99/week, AI-generic look, privacy allegations, 4+ age rating |
| **Face Harmony: Face Rating** (Stuke Digital) | Clone launched April 2026 as "Clavicular – LooksMax AI." **Not Clavicular's.** | 4.6 (101) | 2026 | n/a | Name-squatting shows the value of creator association |
| **QOVES** (web) | Detailed "clinical" structure reports | n/a | — | $150/yr; add-ons to $435 in year one | Deep but expensive |
| **FaceIQ Labs** (web) | Partial free analysis | n/a | — | $24.99/mo | Cited by forum users as an incumbent |
| **Photofeeler** (web) | Real human votes | n/a | — | Free with voting | The only real-rater product; worth borrowing from |
| PrettyScale, SoftMaxx, Real World Appeal, many SEO sites (web) | Free scans, $5–$20 reports | n/a | — | Tiny (one site shows $85 in 30-day Stripe revenue, per TrustMRR) | Compete on "honesty" positioning |

The adjacent playbook comes from RizzGPT (Anderson's earlier app) and Cal AI: an AI camera app, weekly paywall, and a creator army.

### Why Face Harmony is considered bad (verified)

- **Rushed build:** the developer built the MVP "in 3 hours," and the app shipped "in 3 days."
- **Poor craft:** an indie founder called it "one of the worst app launches I've ever seen… clearly one-shotted with AI, horrible onboarding flow."
- **Bait pricing:** reviewers say it gives "a fake score, and then makes u pay to give u a real score." Prices are $9.99/week (≈$519/yr), $9.99/month, $19.99/month Pro, and $49.99 lifetime. An advertised trial was reportedly unavailable.
- **Privacy:** a review cites YouTuber "dzuma" intercepting traffic that showed face-derived data sent to `/saveAssessment` despite on-device claims. We have not verified this. "Foreign government" theories reported by IBTimes have no evidence.
- **Brand baggage:** press reports Clavicular's misogynistic language, Andrew Tate links, a since-dropped charge, a bootcamp tied to a missing-teen story, and peptide sales.
- **Lesson:** this audience downloads on hype, then publicly punishes quality, privacy, and honesty failures. A big creator is both a distribution lever and a liability.

### Gaps → your opportunity

| Incumbent gap | Your answer |
|---|---|
| Inconsistent scores | Guided capture, multi-frame averaging, published test-retest |
| Black-box numbers | Published methodology, evidence badges, confidence bands |
| Fake teasers, broken referrals | Real free result; referrals that work |
| Generic tips | Rules engine tied to findings and goals, with "why we think this" overlays |
| Weak profile analysis | Profile capture from day one |
| Stale apps | Monthly releases with a visible changelog |
| Privacy distrust | On-device geometry, no photo storage by default |
| Pseudoscience | Explicit anti-mewing, anti-bone-smashing, anti-peptide stance as a trust signal |

**Positioning:** *"The most consistent face analysis on the App Store. Same face, same score, and a plan that tells you what actually works."*

---

## 4. Pricing and Monetization

| App | Weekly | Monthly | Annual | Lifetime / one-off | Paywall mechanic |
|---|---|---|---|---|---|
| Umax | $3.99–$9.99 | $9.99–$24.99 | — | "You as a 10/10" $6.99 | Results locked after upload; "invite 3 friends" waiver |
| LooksMax AI | $3.99 | — | — | Boosts $2.99–$5.99; hairstyles $4.99 | Paywall before analysis + results paywall with live counter |
| PSL (IQ Labs) | $4.99 | $9.99–$29.99 | $19.99–$29.99 | $49.99; single scan $4.99–$9.99 | Subscriptions + pay-per-scan |
| Mogged | $3.99–$7.99 | — | $19.99–$39.99 | — | Score locked |
| LooksLab | $9.99 | $9.99 | $19.99–$49.99 | Credits $8.99–$17.99 | Sub + credits |
| Blackpill AI | $4.99 | $12.99 | $29.99 | — | — |
| RateByFresh | $4.99–$6.99 | $14.99 | $29.99–$59.99 | Tokens | Sub + tokens |
| Pryme AI | $9.99 | 3 mo $39.99 | — | Haircut/outfit packs $4.99 | — |
| MogMax | — | — | $49.99 | "Reveal your score" $0.99 | Micro-unlock |
| Face Harmony | $9.99 | $9.99; Pro $19.99 | — | $49.99 | Teaser score then paywall (reviews) |
| QOVES / FaceIQ (web) | — | — / $24.99 | $150 / — | Add-ons to $435 | Report-based / partial free |

Price ranges reflect price testing and regional variants shown on listings.

**What converts (2025–2026):**
- **Hard paywall vs. freemium:** RevenueCat's State of Subscription Apps 2026 (115,000+ apps, $16B revenue) reports median Day-35 conversion of **10.7% hard paywall vs. 2.1% freemium**. The top decile reaches 38.7%. Day-60 revenue per install is $3.09 vs. $0.38. One-year retention of annual subscribers is about equal (27% vs. 28%).
- **Hard paywalls are weakening:** hard-paywall conversion slipped from 12.1% in 2025, a sign users are learning to bounce.
- **Weekly plans:** they convert install-to-trial at up to 5.4x the rate of annual plans (9.8% vs. 1.8%, Adapty data), but reactivate poorly (7–10%).
- **AI apps:** they earn 41% more per payer but churn ~30% faster. A face score is a one-and-done curiosity unless you build reasons to return.
- **Crowding:** new subscription launches hit 14,700/month by January 2026. Only 17.3% of new apps reach $1K MRR.
- **Paywall-view conversion** is a different denominator: Adapty's 2026 medians are 4.85% (soft) vs. 3.34% (hard).

**Recommendation: a value-first hard paywall.**
- **Free:** a real overall band (e.g., "6.0–6.8, HTN"), the PSL tier, your top strength, and your most fixable weakness with one tip. Other metric cards are blurred but labeled, so users see what exists, with no fake numbers.
- **Pro:** all metric cards with overlays, profile analysis, the personalized evidence-graded plan, hairstyle recommendations, monthly re-scans with deltas, and photo optimization.
- **Launch price grid:**
  - **Weekly $4.99**, no trial.
  - **Annual $34.99** with a 3-day trial as the highlighted default.
  - **Lifetime $59.99** as an anchor and a trust signal against the "weekly tax."
- **Why not freemium:** 2.1% conversion and $0.38 RPI can't fund creator acquisition.
- **Why not pay-before-scan:** it's the category's main 1-star driver, and it's what you're positioning against.
- **Later upsells:** a hairstyle preview pack ($4.99–$9.99, a model proven by LooksMax AI and Pryme), a dating-photo audit, and expert reports ($29–$99).
- **Referral:** "give a friend a full report, get a free week," but only if it works end-to-end on day one.

---

## 5. UX, Flow, and Conversion

**Borrow:**
- **Quiz onboarding (8–15 screens):** goals, age, sex, self-rating, time budget.
- **Early sample output:** LooksMax AI opens with sample results.
- **A real landmark-tracing scan animation.**
- **A single big number + tier + 3 insight cards, then the paywall.**
- **Real social proof only.**
- **Share cards:** tier + one flattering metric + watermark. Umax spread through users screen-recording it in their own videos.
- **Retention loops:** monthly re-scans with deltas, plan-task streaks, reminders.

**Avoid (these cause refunds, 1-stars, or rejection):**
- Fake or teaser scores.
- Hidden or delayed close buttons.
- Confusing "$9.99/week vs $9.99/month" layouts. Guideline 3.1.2 requires clear subscription terms.
- Broken referrals.
- Fake live counters.
- Undisclosed face uploads.
- Degrading labels ("subhuman") in the app's own voice.

**Proposed v1 flow:**
1. **Splash:** "Same face, same score."
2. **Onboarding quiz (~10 screens):** sex, age (with Declared Age Range check), goals, current routine, self-rating, time budget.
3. **Biometric consent:** plain-English explanation, explicit tap-to-agree, logged with version and timestamp.
4. **Guided capture:**
   - **Front:** pose meter (yaw/pitch/roll within ±3°), distance check (flags too-close selfies), lighting check, neutral-expression prompt, auto-capture of ~10 frames.
   - **Right profile:** same gating.
   - **Optional:** 3/4 view and smile shot.
5. **Processing (5–10 s):** real overlay animation.
6. **Free reveal:** band, tier, top strength, fixable weakness + tip, blurred labeled cards.
7. **Paywall:** annual-with-trial highlighted, weekly and lifetime visible, clear terms, easy close.
8. **Pro results:** metric cards (value, reference range, evidence badge, overlay) and a "what drives your score" explainer.
9. **Plan:** 3–6 actions ranked by impact × evidence × goal, each with "why: [finding]," timeline, and difficulty, plus a separate "see a professional" section.
10. **Wrap-up:** share card, 30-day re-scan reminder, daily checklist.

---

## 6. Engineering

### 6.1 Capture and landmarking

| Option | Gives | Pros | Cons |
|---|---|---|---|
| Apple Vision face landmarks | 2D landmarks + pose | Free, on-device, any camera | Sparse; no gonion/trichion or profile points |
| ARKit TrueDepth | 3D face mesh (1,220 vertices), pose, blend shapes, depth | Metric 3D corrects perspective; great pose gating | Front camera only; template mesh smooths geometry; extra App Review scrutiny and 5.1.2(vi) limits |
| MediaPipe Face Landmarker | 478 landmarks incl. iris, blendshapes | Dense, cross-platform (helps Android) | Relative depth; frontal-biased |
| Profile landmarking | Custom contour/landmark model on segmented silhouette | Needed for convexity, nasolabial, cervicomental, chin | Label ~1–2K profile images |
| 3DMM reconstruction (FLAME-family) | Full 3D shape | Multi-view fusion, projection estimates | Research-grade, heavy, licensing varies; v2+ |

**v1 recommendation:**
- Use TrueDepth for frontal capture (all Face ID iPhones), with MediaPipe/Vision as fallback and for denser 2D points.
- Add a custom profile-contour model for the side view.
- Compute frontal metrics on de-rotated 3D landmarks to remove pose noise.

**Distance and distortion:** because of the ~30% nasal-width inflation at 12 inches:
- (a) Use TrueDepth metric distances where available.
- (b) Otherwise, enforce a minimum distance via face size in frame, or suggest the rear camera + timer at ~1–1.5 m.
- (c) Log capture distance as a calibration covariate.

**Lighting and expression:** reject blown highlights, strong side lighting, and non-neutral blendshapes. Report skin metrics only when stricter lighting checks pass.

**Body (v2):** Vision/MediaPipe pose keypoints + person segmentation. Present body fat as a range.

### 6.2 Rating model design

| Approach | Strength | Weakness | Competitor use |
|---|---|---|---|
| Landmark geometry | Deterministic, explainable, cheap | Weak alone (misses skin, adiposity, hair) | Ratio cards in most apps |
| Learned regressor (CNN/ViT) | ~0.87–0.90 correlation on SCUT benchmarks | Needs licensed diverse data; bias; black box | Unknown |
| Vision-LLM scoring | Rich descriptions | **Non-deterministic**, prompt-sensitive, sends images to a third party, cost | Umax is "powered partly by OpenAI's technology," consistent with drifting scores |

**Recommended hybrid:**
1. **On-device:** capture QA → landmarks/mesh → ~40 geometric features + small Core ML appearance heads (skin evenness, adiposity, hairline, beard).
2. **Score:** a calibrated model (gradient-boosted trees or small MLP) on geometry + appearance + sex + age band → predicted mean rating → percentile → 0–10 + PSL tier. Fully deterministic. Frame-to-frame SD sets the confidence band.
3. **Recommendations:** a deterministic rules engine.
4. **LLM (cloud, text-only):** receives only structured findings (no image), at temperature 0 with a strict schema, to phrase cards and answer follow-ups.

**Calibration data (critical path):**
- **Pre-launch:** have ~1,000–2,000 commercially licensed or consented faces each rated 20+ times by stratified raters on Prolific or similar.
- **Post-launch:** add an opt-in "contribute to calibration" option with separate consent, and later a Photofeeler-style peer rating mode.

### 6.3 On-device vs. cloud

| | On-device geometry + score | Cloud LLM (text only) | Cloud vision-LLM scoring |
|---|---|---|---|
| Cost/scan | ~$0 | ~$0.002–$0.02 | ~$0.01–$0.05+ |
| Latency | < 2 s | 2–6 s | 5–20 s |
| Privacy | Face stays on phone | Derived findings only | Face sent to third party |
| Consistency | Deterministic | Wording varies, numbers don't | Numbers drift |

Costs are planning estimates; check current model pricing. **Legal nuance:** derived landmark templates may themselves be "face geometry" under BIPA and CUBI, and a "facial template" under COPPA. Don't upload coordinates. Store server-side only coarse metric outputs, and only with opt-in cloud history.

### 6.4 Solo stack

- **Client:** Swift + SwiftUI (native ARKit/Vision/Core ML is the product), Core ML, MediaPipe iOS.
- **Backend:** Supabase or Firebase with Sign in with Apple, plus a serverless LLM proxy (e.g., Cloudflare Workers).
- **Payments:** RevenueCat + Superwall (or RevenueCat Paywalls) for remote paywall tests.
- **Analytics:** PostHog/Mixpanel with no face data. Add an attribution SDK only when you start paid ads.
- **Quality:** Sentry/Crashlytics, TestFlight.
- **ML:** PyTorch → coremltools.

### 6.5 v1 timeline (~12–15 hrs/week)

| Weeks | Milestone |
|---|---|
| 1–2 | Metric spec + evidence sourcing; ARKit/Vision capture prototype with gating |
| 3–4 | Frontal metrics on de-rotated 3D landmarks; test-retest harness |
| 5–6 | Profile pipeline; appearance heads v0 |
| 5–8 | Rater panel study → calibration model v1 |
| 7–8 | Rules engine + 60–100 recommendation cards + LLM proxy |
| 9–10 | Onboarding, reveal, paywall, share card, consent and age flows |
| 11–12 | Lawyer-reviewed policies, TestFlight with 50–100 users, MITM privacy audit |
| 13–14 | Submission + App Review buffer (TrueDepth questions are common) |

Expect **~3–3.5 months**. The calibration panel is the most likely item to slip.

---

## 7. Risks, Platform Rules, and Legal

### 7.1 Apple App Store

- **5.1.2(vi):** data from "depth and/or facial mapping tools (e.g. ARKit, Camera APIs, or Photo APIs) may not be used for marketing, advertising or use-based data mining, including by third parties." Never feed face data to ad SDKs.
- **TrueDepth:** requires a privacy policy, and App Review asks what TrueDepth data you collect and why. Developers report rejections when TrueDepth APIs ship without a visible feature or policy. Prepare a written explanation.
- **Health claims:** don't diagnose. Survivors carry a "for appearance, grooming, and self-improvement guidance only… not medical advice" disclaimer, as Face Harmony's listing does.
- **4.3 copycats:** in June 2026 Apple warned against "opportunistically creating variants of existing app categories or popular apps," adding it "may remove these apps… if they are not updated, improved, or do not attract customers." Real differentiation is also your review defense.
- **Age rating:** LooksMax AI is 18+ and Face Harmony is 4+. Answer the questionnaire to yield 18+.
- **Removal history:** we found no documented removal of a looksmaxxing app for rating appearance. Removal risk is more likely from privacy deception, minors' data, or 4.3. Apple removed Tea in October 2025 over privacy, moderation, and minors' data complaints. Deeper research on objectification-based rejections is still needed.

### 7.2 Biometric and privacy law

| Law | Trigger | Requirements | Exposure |
|---|---|---|---|
| **Illinois BIPA** | Any Illinois user's face geometry | Public retention policy; informed **written** consent before collection; no sale; consent before disclosure | Private right of action ($1,000 negligent / $5,000 reckless). A 2024 amendment limits recovery to one per person, applied retroactively (Seventh Circuit, April 2026). Active against beauty face-scan tools: Neutrogena Skin360 ($4.7M, 2026), Charlotte Tilbury try-on ($2.925M, 2025), MAC try-on (pending), xAI Grok selfie face scans (filed 2026). |
| **Texas CUBI** (§503.001) | "Record of face geometry" for a commercial purpose | Inform + consent before capture; no sale/disclosure except narrow exceptions; destroy within a reasonable time, ≤ 1 year after purpose expires | Up to **$25,000 per violation**, AG only. Meta $1.4B (July 30, 2024); Google $1.375B (announced May 9, 2025; finalized Oct 31, 2025). |
| **Washington MHMDA** | WA consumers; "consumer health data" expressly includes biometric data | Opt-in consent (unless necessary for the requested service), separate sharing consent, separate health-data privacy policy, 45-day deletion, signed authorization for any sale | **Private right of action** via the Consumer Protection Act. First suit (*Maxwell v. Amazon*, filed Feb 10, 2025) was voluntarily dismissed May 29, 2025, so there is no merits ruling yet. |
| **CCPA/CPRA + other state laws** | Thresholds vary | Biometrics = sensitive data; notice, opt-in or limit, deletion | Regulator enforcement |
| **GDPR** (if expanding) | EU/UK users | Article 9 explicit consent; DPIA | Up to 4% of global turnover |

**v1 compliance design:**
- On-device processing; no image or template upload by default.
- BIPA-grade consent before the first scan, logged.
- A public biometric policy with retention (deleted with the scan or app; any server data within 30 days of account deletion; never more than 1 year).
- Separate opt-in for cloud history.
- No third-party SDK touches face data. Verify with a MITM proxy before launch, because your users will.
- One-tap "Delete all my data."
- Privacy-lawyer review (budget ~$1,500–$5,000; get quotes).

### 7.3 Minors

- **Audience:** Fortune and clinicians describe the audience as largely teenage. Clavicular himself was born in December 2005.
- **COPPA (amended):** the rule now adds biometric identifiers, including facial templates and faceprints, to "personal information." Compliance deadline: **April 22, 2026**. Knowingly collecting from under-13s requires verifiable parental consent.
- **Texas SB 2420:** Apple applied it to new Texas accounts from **June 4, 2026**. Developers must rate the app and its in-app purchases by age tier (<13, 13–15, 16–17, 18+), consume Apple's **Declared Age Range API**, and honor parental consent for downloads, purchases, and significant changes. Utah is delayed to May 6, 2027; Louisiana and Alabama follow in 2027.
- **Recommendation: launch 18+ only.** Use the 18+ rating, Declared Age Range plus self-declared age, and block under-18 scanning. This forgoes some of the audience, but scanning teens' faces stacks COPPA, ASAA consent flows, BIPA optics, and "app rates teenagers' faces" headlines. A no-score teen mode is a v3 question for counsel.

### 7.4 Mental health and reputation

**The evidence:**
- A 2026 *Journal of Adolescent Health* paper urges clinicians to screen looksmaxxing adolescents for body dysmorphia, eating disorders, and steroid use.
- Johns Hopkins All Children's (August 2026) reports "a huge uptick in teens, even pre-teens, with eating disorders, with body dysmorphia" and names AI rating apps.
- A December 2025 *Facial Plastic Surgery & Aesthetic Medicine* commentary says tools that "measure facial proportions and highlight measurement differences… from the 'ideal'" fuel a body schema "reminiscent of body-dysmorphic disorder."
- Halpin et al. (2025) documented forum talk of bone smashing, black-market hormones, and leg lengthening.

**Harm-reduction design:**
- Lead with improvable findings, and frame structural traits neutrally ("a feature you can style around").
- Show ranges, and explain that about half of attraction judgments are personal taste.
- Phrase low tiers as "below the median in our panel."
- **Rate-limit full scans** (e.g., one per day). This curbs compulsive checking and saves cost.
- Distress triggers (many rescans, "surgery ASAP," very low self-rating) surface a gentle card with BDD information and 988.
- Enforce the exclusion list.
- Publish an "Our principles" page as a press asset.

### 7.5 Medical-adjacent liability

- Stay in the general wellness/cosmetic lane.
- For drugs and procedures, give information + "consult a licensed professional," with no dosing and no "you should take X."
- Phrase findings as aesthetic observations, not diagnoses.
- Have counsel review the ToS disclaimers, limitation of liability, and arbitration.
- Avoid clinic or Rx-telehealth affiliate links in v1.

---

## 8. Marketing and Virality

### 8.1 How the winners grew

**Umax:** organic TikTok, with users posting videos with Umax screenshots as backdrops. Anderson reused his RizzGPT formula.

**Cal AI:**
- **Influencers were the engine.** Yadegari says influencer marketing "took Cal AI off." His own early TikTok efforts "produced little."
- **The growth curve:** posts converted linearly, but creator recruiting grew exponentially for ~18 months. Revenue went $30K → $100K+ → $300K → $500K → $1M/month by month six.
- **A second creator army for ads:** creators making ad-specific content took revenue from $2M to ~$4M/month.
- **Roster size:** secondary reports cite 150–250 creators on retainers, driven by high-volume outbound DMs.
- **Outcome:** a reported $5.7M month in January 2026, then the March 2026 MyFitnessPal acquisition.

**Creator economics:**
- UGC creators average ~$212/video (PPC.io, January 2026).
- Small-creator posts typically run $100–$500.
- Structure deals as a flat fee + view bonus, or tracked per-download codes.

**Clavicular's ecosystem** runs a paid clipper Discord (Clipmaxer).

### 8.2 The niche ecosystem

- **Creators:** Clavicular (Braden Peters) dominates in 2026, with streams, a TMZ spotlight, a Paris Fashion Week runway, a $50/month "Clan," mentorship, Camp Looksmax, Face Harmony, peptides, and height insoles. His brand risk is high. **Deep-dive needed:** map the next tier of brand-safer glow-up and softmaxxing creators.
- **Communities:** looksmax.org (hardcore, skeptical, will audit you), r/truerateme and rate-me subs, looksmaxxing subreddits, Discords.
- **Receptiveness:** these communities are hostile to cash grabs and love technical depth. Your test-retest data *is* your forum marketing.
- **Viral formats:** celebrity/streamer ratings, before/after score deltas, mog comparisons, "I tested 5 looksmaxxing apps with the same face" (your consistency hook), "app vs. what women say" street interviews, myth-busting.

### 8.3 Solo GTM plan

| Phase | Weeks | Actions | Budget |
|---|---|---|---|
| Pre-launch | −8 to 0 | Build in public (show consistency tests); methodology posts on looksmax.org/subreddits (follow rules); recruit 100–300 TestFlight users; waitlist + long-tail SEO ("Umax alternative," "is mewing real"); 2–3 faceless accounts posting celebrity ratings and myth-busting daily | ~$0–$1K |
| Launch | 0–6 | 20–40 micro-creators (5K–100K followers) at ~$100–$300/post + view bonuses via high-volume outbound DMs; per-creator tracking; "same face, 10 scans" series; deep-linked share cards; working referral; ASO for "looksmax," "face rating," "PSL," "jawline," "glow up" | ~$2–5K |
| Scale | 7–26 | Retainers for winners; separate ad-creative creator pool; Spark/Meta ads only once trial→paid and Day-30 payback are proven; brand-safe creator rev-share deals with content standards (no peptides/bone smashing); "responsible looksmaxxing app" press angle; barbershop/skincare co-marketing; YouTube data videos | Reinvest 30–60% of revenue |

CAC and payback benchmarks for this niche are not public. Treat forum anecdotes as unverified.

---

## 9. Synthesis: v1, Roadmap, Work Plan

### 9.1 v1 scope

| Feature | v1 | Later |
|---|---|---|
| Guided front + profile capture with gating | ✅ | |
| ~30–40 metrics with overlays, ranges, evidence badges | ✅ | |
| Calibrated 0–10 + confidence band + PSL tier | ✅ | |
| Basic skin/adiposity/hair/beard analysis | ✅ | Better models v2 |
| Goal intake + evidence-graded plan | ✅ | |
| Hairstyle recommendations (text + references) | ✅ | Try-on v2 |
| Photo-optimization tips | ✅ | |
| Re-scan + basic progress history | ✅ | Rich timelines v2 |
| Share card, working referral, paywall, 18+ gating, consent | ✅ | |
| 3/4 view, smile/teeth | Optional | v2 |
| Body scan | | v2 |
| "Ascended you" simulations | | v2, styling-only framing (risk of fueling dysmorphia) |
| Peer rating mode | | v3 (also feeds calibration) |
| Expert reports, community, Android | | v3 |
| Teen mode (no score) | | Only after legal review |

### 9.2 Roadmap

- **v1.0 (months 0–3.5):** the core loop.
- **v1.x (months 4–6):** paywall/price tests, more cards, consistency gains, celebrity comparisons (after a right-of-publicity check).
- **v2 (months 6–10):** body scan, try-on, 3/4 + smile, standardized before/after, dating-photo audit.
- **v3 (months 10–18):** human ratings, expert reports, Android, localization.

### 9.3 Deeper research workstreams

| # | Workstream | Key questions | Sources/methods |
|---|---|---|---|
| R1 | Metric norms | Definition, landmark mapping, clinical norm by sex/ethnicity, citation per metric | Cephalometric/anthropometric norm papers (Farkas), PubMed |
| R2 | Attractiveness evidence | Effect sizes for male faces (averageness, symmetry, dimorphism, skin, adiposity, hair, eye area), 2020–2026 large samples | PubMed/PsyArXiv; Jones, DeBruine, Little, Rhodes, Kramer labs |
| R3 | Calibration panel | Rater cost, licensing, consent, sample size for target reliability, fairness metrics | Prolific; Kramer et al. 2024 psychometrics; counsel |
| R4 | Measurement reliability | Test-retest per metric across Vision/ARKit/MediaPipe; distance/pose sensitivity | Own experiments (20 subjects × 10 sessions) |
| R5 | Competitor teardown | Paid walkthroughs of top 8; paywall copy; same-face variance; network traffic | Hands-on + mitmproxy; review exports |
| R6 | Market sizing | 2026 downloads/revenue for Umax, LooksMax AI, PSL, Mogged, Face Harmony | Sensor Tower/Appfigures trials; founder interviews |
| R7 | Creator map | Top 50 creators: reach, audience age, rates, brand safety | Manual research, outreach |
| R8 | Legal | Whether derived metrics are biometric identifiers; consent language; ToS; publicity rights | Privacy attorney; FPF; IAPP |
| R9 | App Review | Rejections of face raters; TrueDepth Q&A | Developer forums |
| R10 | Harm reduction | Appropriate BDD screening items and escalation copy | BDD literature; clinician consult |

### 9.4 Build milestones

1. **M0, wk 2:** decisions locked, metric spec, capture prototype.
2. **M1, wk 4:** frontal metrics at test-retest SD ≤ 0.2 on key ratios.
3. **M2, wk 6:** profile pipeline + appearance heads.
4. **M3, wk 8:** calibration model v1 + per-group fairness report.
5. **M4, wk 10:** full UX, paywall, consent, age gating.
6. **M5, wk 12:** 100-user TestFlight, MITM audit, lawyer sign-off.
7. **M6, wk 14:** submit and launch.

### 9.5 Monetization experiments

Run these sequentially, ~2 weeks each, with ≥ ~1,000 installs per arm:
1. Paywall after free reveal vs. before scan.
2. Annual-trial vs. weekly as highlighted default.
3. Weekly price $3.99/$4.99/$6.99; annual price $29.99/$34.99/$49.99.
4. Lifetime on vs. off.
5. 1 vs. 3 free insights.
6. Referral on vs. off.

Track install→trial, trial→paid, Day-35 conversion, refunds, 1-star rate, and Day-30 retention. **Reject any variant that lifts conversion but raises refunds or 1-stars.**

### 9.6 First decisions and top risks

**Decide in week 1:**
1. 18+ only (recommended).
2. A deterministic hybrid score with published methodology (recommended) over LLM-generated scores.
3. On-device by default, with no image upload.
4. A micro-creator army over a single big creator deal.
5. A value-first hard paywall.
6. A calibration budget of ~$1,500–$4,000 for the first panel (estimate; validate with Prolific pricing).

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| BIPA/CUBI class or AG action | Medium | Severe | On-device, written consent, retention policy, no third-party face data |
| Minors → regulatory/press blowback | High | Severe | 18+ via Declared Age Range; no teen marketing |
| Inconsistent scores → review collapse | High if unmanaged | High | Gating, deterministic scoring, multi-frame averaging |
| 4.3 / TrueDepth rejection | Medium | Medium | Differentiation, TrueDepth explanation |
| Harmful-advice / BDD press story | Medium | High | Exclusion list, harm-reduction design, principles page |
| Distribution fails in a crowded category | Medium-High | High | Consistency content, forum credibility, creator volume |
| Calibration bias | Medium | Medium-High | Stratified panel, published fairness metrics |

---

## Caveats

- **Competitor numbers:** revenue and downloads are mostly third-party estimates or founder statements varying 2–5x (LooksMax AI estimates span $15K–$55K/month). Umax's figures date from 2024. Face Harmony's "top 10" claim is unverified.
- **Biased sources:** Real World Appeal and SoftMaxx sell competing tools (both disclose it). Their App Store snapshots are checkable; their judgments are not neutral.
- **Face Harmony allegations:** the data-leak claim comes from a user review citing a YouTuber and is unverified by us. The "foreign government" theories have no evidence.
- **Ideal ranges:** these blend clinical norms and forum lore. Source every displayed range (R1) before launch.
- **Legal:** these summaries are research, not legal advice. Counsel must decide whether derived measurements are biometric identifiers, how MHMDA applies to aesthetic scoring (no merits ruling yet), and how to track shifting state age laws.
- **Estimates:** costs, timelines, and creator rates are planning estimates.
- **No objective score is possible.** About half of meaningful variance in attractiveness judgments is individual taste. The honest claim is "a consistent, transparent estimate of how an average rater in our panel would score this photo." Make that claim, publish the numbers, and it becomes your brand.

## Sources

- [x](https://x.com/8teAPi/status/1780278714573693110?lang=en)
- [realworldappeal](https://realworldappeal.com/en/blog/looksmaxxing-apps-compared)
- [x](https://x.com/All4nDev/status/2080662497724404217)
- [softmaxx](https://softmaxx.io/blog/face-harmony-app-review)
- [apple](https://apps.apple.com/us/app/face-harmony-by-clavicular/id6781068829)
- [apple](https://apps.apple.com/us/app/6781068829?see-all=reviews&platform=iphone)
- [nih](https://pmc.ncbi.nlm.nih.gov/articles/PMC4640994/)
- [clinkbill](https://clinkbill.com/arr-leaderboard/calai)
- [looksmaxxers](https://looksmaxxers.com/pages/psl-scale-explained-the-looksmaxxing-rating-system)
- [moggedupapp](https://moggedupapp.com/guide/psl-scale)
- [fastshotai](https://fastshotai.com/guides/psl-scale-explained)
- [glowupformen](https://glowupformen.com/looksmaxxing-scale/)
- [pslscale](https://pslscale.net/blog/psl-rating-tiers-explained)
- [pslrating](https://pslrating.pro/blog/psl-scale-names-meaning)
- [realsmile](https://realsmile.online/psl-score-chart)
- [maxxing](https://maxxing.me/blog/psl-scale)
- [plos](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0132726)
- [Wikipedia](https://en.wikipedia.org/wiki/Clavicular_(influencer))
- [plos](https://journals.plos.org/plosone/article/file?type=printable&id=10.1371/journal.pone.0099629)
- [jonathanstray](https://jonathanstray.com/papers/Langlois.pdf)
- [nih](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4079334/)
- [frontiersin](https://public-pages-files-2025.frontiersin.org/journals/human-neuroscience/articles/10.3389/fnhum.2016.00155/xml/nlm)
- [gwern](https://gwern.net/doc/psychology/2006-honekopp.pdf)
- [whiterose](https://eprints.whiterose.ac.uk/id/eprint/219639/1/kramer-et-al-2024-the-psychometrics-of-rating-facial-attractiveness-using-different-response-scales.pdf)
- [researchgate](https://www.researchgate.net/publication/304293105_SCUT-FBP_A_Benchmark_Dataset_for_Facial_Beauty_Perception)
- [arxiv](https://arxiv.org/pdf/2509.23859)
- [sciencedirect](https://www.sciencedirect.com/science/article/pii/S0952197625020172)
- [emergentmind](https://www.emergentmind.com/topics/scut-fbp5500)
- [arxiv](https://arxiv.org/abs/2509.24138)
- [d-nb](https://d-nb.info/1251236901/34)
- [realworldappeal](https://realworldappeal.com/en/blog/best-free-looksmaxxing-app-no-paywall)
- [inkl](https://www.inkl.com/news/looksmaxxing-is-exacerbating-the-youth-mental-health-crisis-psychologists-say)
- [clavicular](https://www.clavicular.org/looksmaxx)
- [yahoo](https://www.yahoo.com/news/politics/articles/california-dieters-now-show-id-130000272.html)
- [whop](https://whop.com/blog/looksmaxxing-blake-anderson/)
- [screensdesign](https://screensdesign.com/apps/looksmax-ai/?ts=0&vt=1&id=1240&av=1254)
- [screensdesign](https://screensdesign.com/showcase/looksmax-ai)
- [appmagic](https://appmagic.rocks/blog/tiktok-trends-non-gaming-apps/?hl=en)
- [ibtimes](https://www.ibtimes.co.uk/privacy-concerns-clavicular-ai-face-rating-app-1810332)
- [apple](https://apps.apple.com/us/app/face-harmony-face-rating/id6762082467)
- [trustmrr](https://trustmrr.com/startup/looksmaxing-app)
- [x](https://x.com/alexoakdev/status/2080174911562174664)
- [revenuecat](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026)
- [saastr](https://saastr.com/the-top-10-learnings-from-revenuecats-state-of-subscription-apps-how-115000-mobile-apps-deliver-16b-in-revenue-whats-working-whats-quietly-killing-growth)
- [medium](https://chuvak-pavel.medium.com/state-of-app-monetization-2026-key-trends-from-revenuecat-and-adapty-8bdc23a4bb6f)
- [consumoteca](https://consumoteca.com.co/articles/en/revenuecat-recurring-subscriptions-explained-platform-pricing-and-2026-benchmarks)
- [buildmvpfast](https://www.buildmvpfast.com/blog/hard-paywall-vs-free-trial-revenuecat-indie-app-2026)
- [impactorigins](https://impactorigins.co/blog/app-paywall-conversion-rate)
- [apple](https://developer.apple.com/support/downloads/terms/app-review-guidelines/App-Review-Guidelines-English-UK.pdf)
- [unrealengine](https://forums.unrealengine.com/t/arkit-app-rejected-because-of-truedepth-apis-usage/422366)
- [TechCrunch](https://techcrunch.com/2026/06/09/apple-says-it-may-remove-apps-from-the-app-store-if-they-dont-attract-users/)
- [apple](https://apps.apple.com/us/app/looksmaxxing-psl-face-rating/id6477295133)
- [Wikipedia](https://en.wikipedia.org/wiki/Tea_(app))
- [topclassactions](https://topclassactions.com/lawsuit-settlements/open-lawsuit-settlements/4-7m-neutrogena-skin360-bipa-violation-class-action-settlement/)
- [openclassactions](https://openclassactions.com/lawsuits/mac-cosmetics-virtual-try-on-bipa-class-action-lawsuit.php)
- [sigmalawgroup](https://sigmalawgroup.com/blog/2026-09-09-meta-xai-bipa-ai-training-photos/)
- [legalhelp](https://legalhelp.us/biometric-privacy-lawsuit-news-largest-settlements-and-bipa-rulings/)
- [clavira](https://www.clavira.com/blog/texas-biometric-privacy-law)
- [verticomply](https://verticomply.com/blog/washington-my-health-my-data-act-apps)
- [facerating](https://facerating.ai/blog/umax-alternative-free)
- [privacyanddatasecurityinsight](https://www.privacyanddatasecurityinsight.com/2026/04/enforcement-begins-soon-for-significant-coppa-rule-amendments/)
- [privacylawmap](https://privacylawmap.com/blog/coppa-compliance-guide-2026)
- [wiley](https://www.wiley.law/alert-State-App-Store-Accountability-Acts-Introduce-New-Obligations-for-App-Developers)
- [mobileapplication](https://mobileapplication.ca/blog/app-store-age-verification-laws)
- [chatbotlaws](https://chatbotlaws.com/app-store-accountability-act/)
- [recordinglaw](https://www.recordinglaw.com/us-laws/age-verification-laws/app-store-age-verification-laws/)
- [jahonline](https://www.jahonline.org/article/S1054-139X(26)00358-7/fulltext)
- [neurosciencenews](https://neurosciencenews.com/looksmaxxing-body-dysmorphia-mental-health-32392/)
- [hopkinsmedicine](https://www.hopkinsmedicine.org/news/articles/2026/08/looksmaxxing-trend-poses-risks-for-boys-and-teens)
- [sagepub](https://journals.sagepub.com/doi/full/10.1177/26893614251409793)
- [lifestance](https://lifestance.com/blog/looksmaxxing/)
- [dealroom](https://app.dealroom.co/news/note/cal-ai-s-viral-playbook-from-one-influencer-story-post-to-a-10m-second-act)
- [getlatka](https://getlatka.com/companies/calai.app#customers)
- [stormy](https://stormy.ai/blog/cal-ai-tiktok-marketing-playbook-2026)
- [growthcurve](https://growthcurve.co/three-engines-and-an-exit-the-cal-ai-growth-playbook)
- [androguider](https://www.androguider.com/2026/10/how-cal-ai-turned-tiktok-influencer.html)
- [alici](https://alici.ai/blog/how-to-make-money-on-tiktok-with-ai-2026)
- [clavicular](https://www.clavicular.org/home)
- [x](https://x.com/i/trending/2114893678733099055)