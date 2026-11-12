# Mog — v1 Engineering Design Doc

Nov 11, 2026 · @Avi

V1 is one loop: guided front and profile capture, on-device geometry, a deterministic calibrated score with a confidence band, and an evidence-graded improvement plan. Every architectural decision below serves three constraints — the same face must produce the same score, no face image or landmark template may leave the device, and no recommendation may exceed its evidence grade.

## Decision record — 11 November 2026

Decided since this document was written. Each is reflected in the 28-screen canvas and the design system; the sections below are unchanged and still correct except where this record says otherwise.

- **Rules-only scorer at launch.** The $400 build section is the plan. The calibrated model is v1.1, trained on peer ratings collected in-app with separate consent.
- **A habit layer ships in v1.** Today, a daily task list derived from the plan, a streak, an eight-week path with scans at weeks 4 and 8. This adds the data model below. It does **not** add XP, levels, badges or leagues — all were designed, then cut.
- **Profile capture stays in v1 for now**, pending spike 2. If the contour model isn't usable by week 3, it moves to v1.1 and the Profile screens are hidden behind a flag.
- **Onboarding collects three things**: goals, sex and age band, time budget. The self-rating is gone; the distress trigger uses results-open frequency and rescan attempts instead.
- **Scan rate limit is a product feature**, not just a cost control: the next scan unlocks at week 4 and week 8 of the plan, and Today counts down to it.

### Habit-layer data model

All of this is non-biometric and may be stored server-side under the existing opt-in history consent. None of it is needed for a scan; the app works without the backend.

```sql
plan_tasks        (id, plan_id, rule_id, title, finding_refs[], cadence,
                   opens_week, time_cost_min, sort_rank)
task_completions  (id, user_id, task_id, local_date, completed_at)
streaks           (user_id, current_days, longest_days, last_complete_date,
                   repairs_available, repair_used_month)
weeks             (user_id, week_index, days_complete, banked_at)
scan_windows      (user_id, week_index, opens_at, scan_id)
```

**Rules the code enforces, not the copy:**

- A day completes when every task with `cadence = daily` has a completion for that `local_date`. Weekly-cadence tasks (lifting 4×) count toward the week, not the day.
- A week banks at `days_complete >= 5`. A banked week never un-banks. A missed week stays open; it is not reset.
- The streak increments once per completed local day. A missed day offers one repair if `repair_used_month != current_month`; repairs are never granted by purchase and never exceed one.
- `scan_windows` open at week 4 and week 8 regardless of streak or banking. The lockout is about measurement validity, not reward, and the copy says so.
- The distress card triggers on `results_opens_today >= 10` or `rescan_attempts_in_window >= 3`, shows at most once per 14 days, and is never A/B tested.
- Nothing in this layer touches a score. Completing tasks cannot change a measurement, and the UI never implies it can.

**Local dates** are computed in the device's time zone at the moment of completion and stored as `YYYY-MM-DD`; a time-zone change does not retroactively break or create a streak.

## Scope and non-goals

V1 ships exactly one loop and nothing else: capture, measure, score, explain, recommend. A feature earns its place in v1 only if removing it would break that loop.

| In v1 | Deferred | Why deferred |
| --- | --- | --- |
| Guided front capture (TrueDepth) | 3/4 view | Adds a third gate and a fusion step for marginal metric gain |
| Guided right-profile capture | Left profile | Doubles capture time; asymmetry needs a separate validated method |
| \~35 geometric metrics | Full 3DMM reconstruction | Research-grade, heavy, licensing unclear |
| Skin, adiposity, hairline, beard heads | Smile and teeth analysis | Needs a fourth capture and dental reference data |
| Deterministic 0–10 score + confidence band | Peer rating mode | Needs a moderation system and a user base |
| PSL tier label | Body scan | Shirtless photos multiply privacy, moderation and minors risk |
| Evidence-graded plan with goal intake | Hairstyle try-on | Generative try-on is its own product surface |
| Re-scan with deltas | Rich progress timelines | One delta is enough to prove the loop |
| Share card, referral, paywall, consent, 18+ gate | Community, Android, expert reports | Post-PMF |

### The three constraints

**1. Determinism.** The same input must produce the same output, bit for bit. This is the product's differentiator, not a nice-to-have — the single most common complaint about Umax is that re-uploading one photo yields different numbers. Consequence: no language model, no sampling, and no non-deterministic kernel may sit anywhere on the path that produces a number. Floating-point reduction order gets pinned, and model inference runs with a fixed compute unit.

**2. Face data never leaves the device.** Not the image, not the mesh, not the 478 landmark coordinates. Derived landmark templates are plausibly "face geometry" under Illinois BIPA and a "record of face geometry" under Texas CUBI, and a facial template under the amended COPPA Rule. Consequence: all geometry and all appearance inference are on-device; the cloud sees only scalar metric outputs and only when the user opts into history.

**3. No recommendation exceeds its evidence grade.** Every piece of advice carries a grade and a safety tier assigned at authoring time, not at generation time. Consequence: recommendations come from a versioned rules table, never from a model's free generation.

### Explicit non-goals

V1 does not diagnose, does not estimate height from photos, does not compare the user against other users, and does not claim objective attractiveness. The score is defined as an estimate of how the calibration rater panel would rate this capture, with a stated interval.

## The $400 build

The budget for v1 is $300–400 total. Everything in this document that assumes paid data collection, licensed imagery, or professional services is the funded version, kept deliberately for when revenue exists. This section is the version that actually ships first, and nothing below it is a compromise on the three constraints — determinism, on-device processing, and evidence-graded advice all survive intact.

### Where the money goes

| Item | Cost | Note |
| --- | --- | --- |
| Apple Developer Program | $99/yr | Unavoidable, and a quarter of the budget |
| Domain | \~$15 | For the policy pages, which must be publicly hosted |
| LLM API | $0–50 | $0 if on-device phrasing works; see below |
| Supabase, RevenueCat, Superwall, PostHog | $0 | All have free tiers well above launch volume |
| Rater incentives | \~$100–150 | The only discretionary spend; see the bootstrap below |
| Reserve | \~$50 |  |

### What the budget removes, and what replaces it

| Funded plan | Cost | $400 substitute |
| --- | --- | --- |
| Calibration panel, 2,000 faces × 20 raters | $1,500–4,000 | Rules-only scorer at launch; peer-rating mode collects the panel for free afterwards |
| Commercially licensed face imagery | Variable, significant | None needed — no training set at launch |
| Profile labelling vendor, 2,000 images | $1,000–3,000 | Defer profile to v1.1, or self-label a few hundred images |
| Privacy attorney review | $1,500–5,000 | Architectural mitigation plus a conservative launch posture; see the residual risk below |
| Creator marketing | $2,000–5,000 | Organic owned accounts and founder-led content |

### The scorer, without a panel

V1 ships the rules-only scorer: metrics computed geometrically, compared against published anthropometric norms, combined into a score as an evidence-weighted deviation from those norms. This costs nothing, is perfectly deterministic, and is fully explainable. Its honest weakness is that the weighting is a considered judgement rather than something calibrated against real human ratings — which is also true of every competitor, none of whom say so.

The product's claim shrinks accordingly and must be worded precisely: not "how people would rate you," but a measured comparison against published population norms, weighted by evidence strength. That is a smaller claim than the funded version makes, and it is still a larger one than anyone else in the category can support.

### Bootstrapping the panel for free

The peer-rating mode was a v3 item in the original roadmap. Under this budget it moves to v1.1 and becomes the central mechanic, because it solves the data problem and a retention problem at once.

Users opt in, with separate explicit consent, to have their capture rated by other users and to rate others in return. Every rating is a labelled data point produced at zero marginal cost. Once enough accumulate, the calibrated model trains on it and ships as a visible, trust-building upgrade: the app announces that scores are now calibrated against real ratings, explains the change, and re-scores stored metric vectors locally.

Three things to get right. Stratification is not automatic, so rater demographics must be collected and the sample monitored, or the panel drifts toward whoever uses the app most. Moderation is required the moment users see each other's faces, which is a real cost in time. And the cold start is genuine — budget the \~$100–150 of rater incentive for a seed panel of friends, testers and small-scale recruits to validate the pipeline before public launch.

### The LLM for free

iOS 26 exposes on-device models through the Foundation Models framework. For a phrasing layer that only rewords structured findings, this is a strong fit: no API cost, no network, and nothing to send anywhere — which strengthens the privacy claim rather than straining it. Verify output quality and determinism during the spike window; keep a cheap cloud fallback behind a flag, and keep static copy as the floor.

### The legal gap, stated plainly

This is the one substitution that does not fully work, and it should not be papered over. Counsel review is the correct answer and is out of reach at this budget. What is available:

- **Architectural mitigation.** No images, no landmarks, no templates leave the device, and nothing biometric is retained server-side. This substantially narrows exposure under BIPA, CUBI and MHMDA, because much of what those statutes govern is collection, storage, disclosure and retention of biometric identifiers — but it does not eliminate exposure, since on-device extraction of face geometry may itself be covered.
- **BIPA-grade consent for everyone**, as specified earlier, which costs nothing.
- **A published retention and destruction policy**, which BIPA requires and which is free to write and host.
- **Consider excluding Illinois, Texas and Washington at launch.** The App Store cannot geofence by state, so this means in-app state attestation and blocking the scan. It is clumsy and costs users, but those three states carry the private rights of action and the largest penalties.
- **Revisit the moment revenue exists.** Counsel review should be the first expense the product funds — before marketing, before contractors, before anything.

Residual risk here is real and unquantified. It is a deliberate, informed decision to launch without review, not an oversight.

### What this does to the schedule

Removing the calibration panel removes the long pole. The profile model, if deferred, removes the second. A frontal-only, rules-scored v1 is roughly 10–12 weeks rather than 18 — and ships something real that can start funding the funded version.

## System architecture

&#91;embedded content: v1 architecture · on-device pipeline, cloud services, and the hard boundary between them\]

The scan path is entirely on-device and works offline. The cloud receives two things only: structured findings for the phrasing model, and scalar metric values for history when the user has opted in. Everything in the dashed box on the right is architecturally unreachable from the capture pipeline, which is what makes the privacy posture a property of the system rather than a promise in a policy.

## Capture subsystem

Capture is where score consistency is won or lost, so the app refuses to measure a capture it cannot trust rather than measuring it badly. Every gate below exists because a specific metric breaks without it.

### Why gating is non-negotiable

Ward, Ward, Fried and Paskhover (JAMA Facial Plastic Surgery, 2018) measured a selfie taken at roughly 12 inches against a portrait at 5 feet: the nasal base appears about 30% wider in men and 29% wider in women, the nasal tip about 7% wider. An ungated app therefore measures camera distance and calls it nose width. Pose is the same story — a few degrees of yaw changes every horizontal ratio on the face.

### Gates and thresholds

All gates run live at preview frame rate. The shutter is disabled until every gate for that pose passes, then ten frames auto-capture over roughly 400 ms.

| Gate | Threshold | Signal source | Breaks without it |
| --- | --- | --- | --- |
| Yaw | ± 3° | ARKit face transform, Vision fallback | Every bilateral width ratio |
| Pitch | ± 3° | Same | Facial thirds, midface ratio |
| Roll | ± 2° | Same | Canthal tilt, which is an angle |
| Distance | 45–75 cm | TrueDepth metric depth; face-height-in-frame fallback | Nose and lower-third widths |
| Lighting uniformity | left/right mean luma ratio within 0.80–1.25 | Luma histogram over face region | Skin metrics, perceived asymmetry |
| Clipping | < 2% of face pixels at 0 or 255 | Same | Skin texture, adiposity |
| Neutral expression | all expression blendshapes < 0.15 | ARKit blendShapes, MediaPipe equivalents | Mouth, jaw and eye-area metrics |
| Occlusion | no hand, hair or glasses over landmark regions | Segmentation + landmark confidence | Whichever region is covered |
| Sharpness | variance of Laplacian above a device-calibrated floor | Luma channel | All fine landmarks |

Stricter lighting rules apply to skin metrics than to geometry: geometry survives mediocre light, skin does not. If the lighting gate passes for geometry but fails the tighter skin threshold, the scan proceeds and skin cards are suppressed with a stated reason.

### Profile capture

Profile cannot use TrueDepth, which is front-camera-only and conforms a generic model that smooths exactly the contours the profile metrics need. Profile is therefore a rear-camera capture with a different gate set: head yaw at 90° ± 5° verified by ear-and-eye visibility rather than by a face transform, Frankfort horizontal approximated from tragus and infraorbital landmarks, and a plain background preferred for silhouette segmentation. The UI uses a timer and a distance prompt because the user cannot hold the phone at arm's length and face sideways at once.

### Frame selection and aggregation

Of the ten captured frames, the pipeline discards any that drifted outside gate tolerance, computes metrics on each surviving frame independently, and takes the per-metric median. The interquartile range across frames becomes that metric's capture-noise estimate, which propagates into the score's confidence band. Fewer than six surviving frames aborts the capture and asks the user to retake, naming the gate that failed.

### Re-scan determinism

Raw captures are retained on device only until metrics are computed, then discarded. But the metric vector is retained, so a re-scan compares against the stored vector rather than re-deriving it. A "recompute" path exists for model upgrades: when the scoring model version changes, stored metric vectors are re-scored locally and the user is told their score moved because the model changed, not because their face did. This is the single most important trust mechanic in the app.

## Geometry pipeline

Three landmark sources feed the pipeline, each chosen for what it is actually good at. None of them alone is sufficient.

| Source | Returns | Used for | Known limitation |
| --- | --- | --- | --- |
| ARKit `ARFaceAnchor` | 1,220-vertex mesh, 52 blendshapes, eye transforms, metric scale | Pose, metric distance, expression gating, depth-corrected horizontal ratios | Apple documents it as a coarse mesh conformed to a generic model — it smooths real bone detail |
| MediaPipe Face Landmarker | 478 landmarks including 10 iris points, 52 ARKit-compatible blendshapes | Dense 2D ratios, iris-based scale reference, eye-region detail | Relative depth only; frontal-biased |
| Custom profile contour model | Profile silhouette keypoints | Convexity, nasolabial, mentolabial, cervicomental, chin projection | Must be trained; no off-the-shelf option |

The design rule: **ARKit for pose and scale, MediaPipe for position, the custom model for profile.** ARKit's metric depth is trusted for *where the head is*; MediaPipe's dense landmarks are trusted for *where the features are*. Taking bone contours from ARKit's conformed mesh would be measuring Apple's template rather than the user's face.

### Normalization, in order

1. **Pose de-rotation.** Back-project MediaPipe landmarks using ARKit's depth, then rotate into a canonical frontal frame using the head transform. Horizontal ratios are measured in this frame, not in image space, which removes residual yaw within the gate tolerance.
2. **Perspective correction.** With TrueDepth metric distance, apply a pinhole correction to each landmark for its own depth. Without it, apply a distance estimate from iris diameter, which is the most stable biological constant available — adult horizontal iris diameter varies little across people.
3. **Scale normalization.** Convert to millimetres using ARKit metric scale where available, otherwise express every metric as a dimensionless ratio. No metric is ever reported in pixels.
4. **Frankfort alignment.** Rotate the profile into Frankfort horizontal before computing any profile angle, since those angles are defined against that plane.
5. **Temporal smoothing.** MediaPipe's streaming path applies a OneEuro filter by default. The pipeline disables it for measurement and instead aggregates raw per-frame landmarks, because a smoothing filter tuned for visual stability introduces a lag that biases a still measurement.

### The profile contour model

This is the only component with no off-the-shelf answer, and it is on the critical path. Approach: person segmentation to isolate the silhouette, then a small heatmap keypoint regressor over roughly 20 profile landmarks — glabella, nasion, pronasale, subnasale, labrale superius and inferius, stomion, sulcus mentolabialis, pogonion, menton, cervical point, tragus, and the lid and brow points visible in profile.

Training data is the constraint. Target roughly 1,500 to 2,500 labelled profile images spanning sex, ethnicity, age and facial-hair presence. Label in-house or via a labelling vendor, and license images commercially — academic face datasets almost universally prohibit commercial use.

### Confidence propagation

Every landmark carries a confidence, every metric carries a propagated confidence plus its cross-frame interquartile range, and a metric below its confidence floor is suppressed rather than shown with a caveat. A visibly uncertain number invites exactly the re-scan-until-it-changes behaviour the product exists to eliminate.

## Metric layer

The metric layer turns normalized landmarks into roughly 35 named scalars. Each metric is a pure function with a declared input set, a reliability tier, an evidence grade, and a reference distribution. Metrics are versioned: changing a definition bumps the metric version and forces a recompute, never a silent change.

### The metric record

```json
{
  "id": "canthal_tilt_deg",
  "version": 3,
  "inputs": ["canthus_inner_l", "canthus_outer_l", "canthus_inner_r", "canthus_outer_r"],
  "requires_pose": "frontal",
  "reliability_tier": "B",
  "evidence_grade": "weak-moderate",
  "reference": { "stratify_by": ["sex", "ancestry_group", "age_band"] },
  "confidence_floor": 0.72,
  "score_weight_cap": 0.02
}
```

### Reliability tiers

Tier is measured, not asserted — it comes from the test-retest harness, not from judgement.

| Tier | Test-retest criterion | Treatment |
| --- | --- | --- |
| A | Coefficient of variation under 2% across sessions | Full score weight, shown with a point value |
| B | 2–5% | Reduced weight, shown as a band not a point |
| C | 5–10% | Zero score weight, shown as a qualitative category only |
| D | Above 10%, or confidence floor regularly missed | Not shipped |

Any metric that cannot reach tier C is cut, regardless of how much the community cares about it. This is the mechanism that keeps forum demand from degrading the product.

### Evidence grade is independent of reliability

These two axes are orthogonal and the distinction matters commercially. A metric can be measured precisely and still predict almost nothing. Facial width-to-height ratio is the clearest case: it is reliably measurable, and Geniole et al.'s 2015 meta-analysis in PLOS ONE found that higher FWHR is associated with *lower* rated attractiveness, r = −.26 across 14 samples — the opposite of what the community asserts.

The product's answer is to show the measurement, state the reference range, and attach a badge that tells the truth about the evidence. Community metrics are displayed because the audience expects them; their score weight is capped near zero because the evidence does not support more.

| Evidence grade | Score weight cap | Badge copy |
| --- | --- | --- |
| Strong | uncapped | Well supported by research |
| Moderate | 0.6 of nominal | Reasonable support |
| Weak | 0.1 of nominal | Limited evidence |
| Community | 0.02 | Community metric, little evidence |
| Contradicted | 0 | Research points the other way |

Every displayed reference range must cite either a clinical anthropometric norm or be explicitly labelled a community convention. A range sourced from a forum post and presented as clinical is the fastest way to lose the credibility the whole positioning rests on.

### Suppression

A metric is suppressed when its confidence is below floor, its required pose was not captured, or its region was occluded. Suppressed metrics show the reason and the retake action — never a guess, never a dash.

## Scoring and calibration

### What the score claims

The score is defined precisely, and the definition appears in the app: *an estimate of the mean rating this capture would receive from the calibration panel, expressed as a percentile against a sex-matched, age-banded reference distribution.* It is not a claim about objective attractiveness, and the app never implies otherwise.

That restraint is forced by the research. Raters agree strongly in aggregate — Langlois et al. (2000) found interrater reliability around r = .90 for adults and r = .94 cross-culturally. But individual taste is roughly as large as shared taste: Leder et al. (2016) attribute about 40% of meaningful variance in face ratings to private taste, and Kramer et al. (2024) found it explained approximately half. No model can predict the half that is personal. Claiming otherwise is both false and the thing that gets an app mocked on the forums it is trying to win.

### Architecture

A three-stage deterministic pipeline, with no learned component on the path from metrics to the displayed number other than the calibrated regressor itself.

1. **Feature assembly.** The \~35 metrics, plus sex, age band, and the appearance-head outputs (skin evenness, facial adiposity, hairline stage, beard presence), with evidence-grade weight caps applied.
2. **Calibrated regressor.** Gradient-boosted trees or a small MLP predicting the panel mean rating. Deliberately not a deep CNN over raw pixels: a pixel model is a black box that cannot produce the per-metric explanations the product sells, and it is far more prone to the ethnicity bias documented below.
3. **Percentile mapping.** Predicted mean maps to a percentile of the sex-matched reference distribution, then to the 0–10 display scale and the PSL tier label.

The confidence band comes from two sources combined: capture noise, propagated from the cross-frame interquartile ranges, and model uncertainty, from quantile regression or an ensemble. A typical band should be roughly ± 0.4 to 0.6 points. If it is narrower than that, the model is overconfident and is lying.

### The calibration panel

This is the long pole of the entire project, the main cash cost, and the real long-term moat.

| Parameter | Target | Note |
| --- | --- | --- |
| Faces | 1,500–2,500 | Commercially licensed or explicitly consented |
| Ratings per face | 20+ | Below this the panel mean is too noisy to fit against |
| Rater stratification | Sex, age, ethnicity | Raters favour own-ethnicity aesthetics, so an unstratified panel bakes that in |
| Face stratification | Sex, ancestry group, age band, facial hair | Sparse cells produce exactly the bias the fairness report must catch |
| Capture conditions | Matched to the app's gates | A panel of studio portraits cannot calibrate phone captures |
| Platform | Prolific or equivalent | Budget roughly $1,500–$4,000 for round one; verify against current pricing |

**Do not train on SCUT-FBP5500.** It is licensed for non-commercial research only. It is also only 5,500 faces across two ethnic groups, Asian-heavy at 4,000 of 5,500, and Hamel et al. (2025) found that models trained on it and on MEBeauty show statistically significant ethnicity bias even from apparently balanced sources. It is acceptable only as an offline sanity check that the pipeline runs end to end.

### Fairness, as an engineering requirement

The fairness report is a release gate, not a document. For each stratum — sex × ancestry group × age band — the build emits mean absolute error against panel mean, score distribution, and calibration curve. Release requires that no stratum's mean score deviates from the global mean by more than a set threshold once true panel means are controlled for, and that no stratum's error exceeds the global error by more than a set ratio.

Ancestry group is used only to select a reference range where population variation is documented — canthal tilt, nasal angles, the E-line — and never as a feature that can move a score down. Where ancestry is uncertain, the pooled reference is used and the band widens.

### Determinism controls

Fixed model version pinned per build; fixed Core ML compute unit, since the Neural Engine and GPU can differ in the last bits; fixed floating-point reduction order; no sampling anywhere; scoring model version stamped on every stored result. A score that changes must always be explainable by a named version bump.

## Public datasets: what they can and cannot do

Open face datasets are useful for most of this build and useless for its most important component. Two independent blockers keep them out of the shipping scorer.

**Licensing.** The attractiveness-rated sets — SCUT-FBP5500, MEBeauty and relatives — are released for non-commercial research. Most academic landmark corpora carry the same restriction.

**Fitness for purpose.** No public dataset was captured under this app's gates. A corpus of studio portraits or web photos cannot calibrate captures taken at 45–75 cm with ± 3° pose tolerance and neutral expression, because the systematic distortion the gates exist to control is baked into the public images at unknown and varying magnitude. Even with unlimited licensing, the calibration panel would still have to be collected.

There is a third consideration specific to this product. Several widely used face corpora were assembled by scraping without subject consent, and some have been withdrawn for it. For an app whose positioning rests on privacy credibility, with an audience that will point a proxy at the binary, training on scraped faces is an avoidable liability.

### Where they do earn their place

| Dataset class | Use | License posture |
| --- | --- | --- |
| Attractiveness-rated (SCUT-FBP5500, MEBeauty) | Offline pipeline smoke tests; replicating the published bias findings against your own architecture before spending on the panel | Research only — never in a shipped model |
| Landmark corpora with pose variation (WFLW, AFLW-family, 300W-LP) | Pretraining the profile contour model before fine-tuning on licensed, labelled profiles | Mostly research only; check each individually |
| Morphable models and 3D head scans (FLAME-family, FaceScape) | Synthetic validation: render a known head at controlled distances and poses to test perspective correction against perfect ground truth | Non-commercial for the models themselves; commercial terms usually exist separately |
| Published anthropometric and cephalometric norms (Farkas and the clinical literature) | Sourcing every displayed reference range, stratified by sex and ancestry | Published literature — cite it |
| Commercially licensed, model-released imagery | Profile-model training data and appearance-head labels | Purchasable; budget for it |

The fourth row is the one to act on first and the cheapest by far. It is not images at all — it is the population norms that let the app state "typical range 115–125° for adult males" with a citation rather than a forum convention. That single sourcing decision does more for the credibility positioning than any model choice in this document.

### Synthetic data, used narrowly

Synthetic renders are appropriate for validating geometry — testing that perspective correction recovers a known ground-truth ratio across simulated capture distances. They are not appropriate for calibration, because synthetic faces have no real human ratings and inherit the aesthetic priors of whatever generated them.

### The one real shortcut

Collect and rate in a single pass. Recruit on Prolific, have participants capture themselves through a stripped-down build of the app's own capture flow, obtain explicit commercial-use and retention consent at collection, then have a separate stratified rater panel rate those captures. This yields images captured under the production gates, with consent, with ratings, and commercially usable — which no public dataset offers on any of the four.

## Recommendation engine

Recommendations come from a versioned, human-authored rules table. A model never decides what to recommend — only how to word it. This is a safety architecture as much as a quality one: it makes the set of things the app can ever say finite, reviewable, and auditable.

### Rule schema

```json
{
  "id": "adiposity_high_cervicomental_obtuse",
  "version": 2,
  "triggers": [
    { "metric": "facial_adiposity", "op": ">", "value": 0.68, "min_confidence": 0.75 },
    { "metric": "cervicomental_angle_deg", "op": ">", "value": 126, "min_confidence": 0.70 }
  ],
  "goal_match": ["sharper_jawline", "look_leaner", "general"],
  "safety_tier": 1,
  "evidence_grade": "strong",
  "expected_timeline_weeks": [8, 24],
  "effort": "high",
  "impact_rank": 1,
  "evidence_refs": ["ref_adiposity_attractiveness", "ref_cervicomental_fat"],
  "overlay": "profile_cervicomental",
  "excludes": ["jaw_exercise_devices"]
}
```

`excludes` matters more than it looks: it is how the engine prevents a plausible-sounding but useless recommendation from appearing alongside the real one. A user with a soft jaw-neck transition should be told about body fat, and specifically should not be sold jaw exercisers.

### Safety tiers

| Tier | Meaning | Engine behaviour |
| --- | --- | --- |
| 1 | Low-risk, self-directed (skincare basics, haircut, training, sleep, photo technique) | Full personalized instruction |
| 2 | OTC actives and products with real irritation or side-effect profiles | Recommend with usage and irritation guidance |
| 3 | Prescription or clinician territory (tretinoin, finasteride, orthodontics, dermatology referral) | Inform that the option exists, state that it requires a professional, never dose |
| 4 | Surgical and procedural | Name only as something a board-certified surgeon may discuss, 18+, no clinic links, no affiliate relationships in v1 |
| X | Excluded entirely | Never emitted under any trigger, goal or phrasing |

### The exclusion list, enforced in code

Tier X is a hard-coded denylist checked at authoring time and again at render time. Nothing in it can be emitted, even if a rule is misauthored or a phrasing model is manipulated.

- Bone smashing and any self-inflicted facial trauma
- Mewing as a structural jaw or midface fix. The British Orthodontic Society's May 2025 statement, signed by president Dr Robbie Lawson, is explicit that there is no scientific evidence that patients can change facial shape this way, and the AAO warned similarly in March 2025. An optional myth-busting card is allowed; a recommendation is not.
- Steroids, SARMs, unregulated peptides, DNP, stimulant diet pills, black-market hormones
- Leg-lengthening surgery
- Any specific drug dosing, including minoxidil and finasteride, which may be named but never dosed
- Any caloric target, deficit figure, or goal weight. Rate guidance only, phrased as a range, with disordered-eating safeguards
- Any recommendation framed as comparison against another person

### Selection and ranking

All rules whose triggers fire are collected, filtered by goal match and safety tier, de-duplicated via `excludes`, then ranked by impact × evidence grade × goal weight, with an effort penalty. The top three to six become the plan. Tier 3 and 4 items never enter that ranked list — they appear in a separate, visually distinct "things to discuss with a professional" section, so that the plan the user acts on alone contains only things they can safely do alone.

Every card renders with its triggering finding attached: the metric, its value, and the overlay that shows it on the user's own capture. That link from evidence to advice is the product's core value proposition, and the generic-tips complaint is the single most common criticism of every competitor.

### Distress safeguards

Triggered by excessive re-scanning, a very low self-rating in onboarding paired with a low computed score, or goal text requesting surgery urgently. The response is one calm, non-clinical card offering body-dysmorphia information and the 988 line, shown at most once per fortnight. It is never a modal, never blocks the product, and is never A/B tested for conversion.

## LLM phrasing layer

The language model has one job: turn structured findings into natural second-person prose. It is text-only, it never sees a face, and it cannot introduce a recommendation.

This is the deliberate inverse of how competitors appear to work. Fortune reported that Umax is powered partly by OpenAI's technology, which is consistent with its most-complained-about behaviour — scores that drift between identical uploads. A model asked to produce a number will produce a different number next time.

### What it receives

```json
{
  "sex": "male",
  "age_band": "18-24",
  "goals": ["sharper_jawline", "better_skin"],
  "findings": [
    { "metric": "facial_adiposity", "category": "high", "confidence": "medium" },
    { "metric": "cervicomental_angle_deg", "category": "obtuse", "confidence": "high" }
  ],
  "selected_rules": ["adiposity_high_cervicomental_obtuse", "spf_daily"],
  "tone": "direct_constructive"
}
```

No image. No landmarks. No raw coordinates. No score. The score is rendered by the client from the deterministic pipeline and never passes through the model, so the model cannot restate, round, or contradict it.

### Hard constraints

- Temperature 0, fixed model version, strict JSON schema response, one output object per rule id
- The output schema contains only `headline`, `body`, and `why_this` — there is no field in which a new recommendation could appear
- Any rule id in the output that was not in `selected_rules` fails validation and the turn falls back to the rule's static copy
- A tier-X term denylist runs over generated text as a second line of defence; a hit discards the generation and uses static copy
- Every rule ships with static fallback copy, so the product degrades to slightly stiffer prose rather than to an error when the API is down, slow, or returns something invalid

### Why the model is in the product at all

Only for register. The rules table holds roughly 60 to 100 cards; the model's value is making a card read as though written for this specific person's combination of findings and goals rather than as a template. Per-scan cost lands in the fractions of a cent, latency is a couple of seconds, and it sits off the critical path — the score and the metric cards render immediately while plan copy streams in behind them.

### Follow-up questions

The one place the model is user-facing is a bounded Q&A on the plan: the user can ask why a card was recommended. Context is the same findings payload plus the evidence references. The system prompt forbids new recommendations, forbids discussing anything on the exclusion list, and routes medical questions to the professional-referral copy. Rate-limited, and logged without any user content attached to an identity.

## Backend and data model

The backend is deliberately small. It handles identity, entitlements, opt-in history, and an LLM proxy. It is not in the scan path, so the app works fully offline for a scan, and a backend outage cannot corrupt a score.

### Stack

| Component | Choice | Reason |
| --- | --- | --- |
| Client | Swift + SwiftUI, iOS 18 minimum | ARKit, Vision and Core ML are the product; a cross-platform wrapper fights all three. iOS 18 is the floor for the modern Vision API |
| Auth | Sign in with Apple only | No password surface, no email store, and an Apple-relay address |
| Backend | Supabase (Postgres, RLS, Edge Functions) | Row-level security maps cleanly to a one-user-one-row model; Postgres is easy to audit |
| LLM proxy | Edge Function | Keeps the API key off-device and enforces the schema server-side |
| Payments | RevenueCat + Superwall | Entitlements and remote paywall tests without an app release |
| Analytics | PostHog, strict event allowlist | Self-hostable, and an allowlist prevents accidental face-adjacent telemetry |

### Schema

```sql
users            (id, apple_sub, created_at, age_attested_at, deleted_at)
consents         (id, user_id, kind, policy_version, granted_at, revoked_at, ip_country)
entitlements     (user_id, product, status, expires_at, source)
scans            (id, user_id, created_at, model_version, metric_version,
                  score_point, score_low, score_high, tier,
                  capture_quality_json, metrics_json, suppressed_json)
plans            (id, scan_id, rule_ids[], goals[], generated_at)
rules            (id, version, trigger_json, safety_tier, evidence_grade, copy_json)
reference_dists  (id, model_version, sex, ancestry_group, age_band, quantiles_json)
```

`metrics_json` holds scalar metric values only — named numbers such as `canthal_tilt_deg: 4.2`. It holds no coordinates, no mesh, no descriptor vector, and nothing from which a face could be reconstructed or matched. The row exists at all only if the user opted into cloud history.

### What is never stored server-side

Images, landmark coordinates, the ARKit mesh, face embeddings, depth maps, any biometric template, and any raw capture frame. On-device, raw frames are discarded the moment metrics are computed; the metric vector persists in an encrypted local store with the app's data-protection class set to complete.

### Deletion

One tap deletes everything: local store wiped immediately, server rows hard-deleted within 30 days, Apple sub tombstoned so a re-sign-in creates a fresh identity. Deletion is tested in CI against the actual schema — an untested deletion path is the compliance failure everyone discovers in litigation.

### Offline and failure behaviour

Scan, score, metric cards and static plan copy all work with no network. Only LLM phrasing, history sync and entitlement refresh need the backend, and each degrades to a usable state rather than an error.

## Privacy and consent implementation

The architecture above is the compliance strategy. On-device processing is not a feature choice that happens to help with privacy — it is the control that makes the rest of the exposure manageable.

This section is engineering research, not legal advice. A privacy attorney must review the consent language, the retention schedule, and the question of whether derived scalar metrics constitute biometric identifiers before launch.

### The exposure

| Law | What triggers it | What it demands | Teeth |
| --- | --- | --- | --- |
| Illinois BIPA | Collecting face geometry from an Illinois user | Public retention policy, informed **written** consent before collection, no sale, consent before disclosure | Private right of action. Active 2025–2026 settlements against face-scanning beauty tools: Neutrogena Skin360 at $4.7M, Charlotte Tilbury try-on at $2.925M |
| Texas CUBI | A record of face geometry captured for commercial purposes | Inform and obtain consent before capture, destroy within a reasonable time | Up to $25,000 per violation, AG-enforced. Meta settled at $1.4B; Google at $1.375B, finalized October 2025 |
| Washington MHMDA | Washington consumers; biometric data is expressly consumer health data | Opt-in consent, separate sharing consent, a separate health-data privacy policy, 45-day deletion | Private right of action via the Consumer Protection Act. No merits ruling yet |
| CCPA/CPRA and state analogues | Thresholds vary | Biometrics are sensitive data: notice, opt-in or limit, deletion | Regulator enforcement |

### Consent flow

BIPA-grade by default for every user, because geofencing consent quality is fragile and the strict version costs one screen.

1. Shown before the first capture, after onboarding, never bundled with the paywall or the terms of service
2. Plain English: what is captured, that it is processed on the device, that it is not uploaded, what is retained, for how long, and how to delete it
3. An explicit affirmative action — a tap on a labelled consent control, not a continue button, and not a pre-checked box
4. Recorded in `consents` with policy version and timestamp; a policy version bump re-prompts
5. Separate, independently revocable consent for cloud history, and a third for any future calibration contribution

### SDK isolation

App Store Review Guideline 5.1.2(vi) prohibits using data from depth and facial-mapping tools for marketing, advertising, or use-based data mining, including by third parties. The engineering control: face data never crosses a module boundary into any SDK. Analytics receives a strict event allowlist with no face-derived payloads; no attribution SDK ships in v1 at all, and one is added only when paid acquisition starts, with an audit at that point.

### Verification before launch

Run a MITM proxy against the app and confirm that no capture, mesh, landmark set, or image leaves the device on any path, including crash reports and analytics batches. Do this as an explicit release gate with the trace saved.

This is not theoretical. Face Harmony's App Store reviews cite a YouTuber intercepting traffic that allegedly showed face-derived data posted to a server endpoint despite on-device claims — unverified, but it is now part of why that app sits at 2.3 stars. This audience will point a proxy at the app. The correct posture is to assume they already have and to be able to publish the trace.

### Minors

Launch 18+. The audience skews young, which is precisely why.

- The amended COPPA Rule adds biometric identifiers including facial templates to personal information, with an April 22, 2026 compliance deadline
- Texas SB 2420 has applied to new Texas accounts since June 4, 2026: developers must rate the app by age tier and consume Apple's Declared Age Range API. Utah follows in May 2027, with Louisiana and Alabama after
- Implementation: 18+ App Store age rating, Declared Age Range API consumed at launch, self-attested date of birth, and capture blocked for under-18 signals. Store the attestation timestamp, never the date of birth itself
- No marketing to minors, and creator partners contractually required to have adult-majority audiences

## Payments, paywall, and remote config

### Entitlement model

One entitlement, `pro`, unlocks everything paid. Resolution order is RevenueCat cache, then server, then a grace period on failure — a network error must never present a paying user with a paywall. StoreKit 2 transactions verify server-side via RevenueCat webhooks into `entitlements`.

Products at launch: `weekly_499`, `annual_3499_trial3d`, `lifetime_5999`. Price testing runs through RevenueCat Offerings, so a price change does not need an app release.

### Free versus Pro, in code

The free tier must deliver a real, honest result. This is both the strategy and the thing that separates the app from the category.

| Free | Pro |
| --- | --- |
| Overall score band and PSL tier | Point estimate with full confidence band |
| Top strength, named with its metric | All \~35 metric cards with values and reference ranges |
| Most fixable weakness plus one action | Measurement overlays on the user's own capture |
|  | Full profile analysis |
|  | Complete evidence-graded plan |
|  | Re-scan with deltas and history |

Locked cards render with their real labels and a blurred value — the user sees exactly what exists and what they would get. They never see a fabricated number.

The negative requirement is as important as the positive one: **the free score is the real score.** Face Harmony's reviews center on the opposite — users report a teaser score before the paywall and a different one after, alongside $9.99/week pricing. That single decision is most of why it sits at 2.3 stars against a category that otherwise clears 4.5.

### Paywall placement

After the free reveal, never before the scan. RevenueCat's State of Subscription Apps 2026, covering 115,000+ apps and $16B in revenue, puts median Day-35 conversion at 10.7% for hard paywalls against 2.1% for freemium, with Day-60 revenue per install at $3.09 against $0.38. But hard-paywall conversion has already slipped from 12.1% a year earlier, which is what a market full of pay-before-you-see-anything apps produces. The value-first hard paywall is an attempt to capture hard-paywall economics without the resentment.

### Guideline 3.1.2 compliance

Price, period, and renewal terms on the paywall itself, not behind a link. Links to terms and privacy policy. A close control visible from the first frame with no delay and no decoy. Restore purchases on every paywall. These are App Review requirements, and they are also what keeps refund rate and one-star reviews down.

### Remote config

Superwall drives paywall layout and copy experiments; RevenueCat Offerings drive price. Anything that could affect a score, a metric, a recommendation, or a safety tier is **never** remotely configurable — those ship in the binary, versioned and reviewable. The blast radius of a bad remote config should be a worse paywall, never a wrong number or an unsafe recommendation.

## Telemetry and quality gates

### The consistency harness

The product's central claim needs a number behind it, published.

Protocol: 20 subjects spanning sex, ancestry group, age band and facial hair, each captured 10 times across separate sessions on separate days, with varied lighting and clothing inside gate tolerance. Measure per-metric coefficient of variation — which assigns reliability tiers — and the standard deviation of the final score across sessions.

**Release gate: score SD ≤ 0.2 points on the 10-point scale.** No build ships above it. A second harness runs on every CI build against a fixed set of stored captures and fails the build on any score change not explained by a declared version bump. That second one catches the silent regressions that would otherwise reach users as "the app changed my score overnight."

### Release gates

| Gate | Criterion |
| --- | --- |
| Consistency | Score SD ≤ 0.2 across sessions |
| Determinism | Byte-identical scores on repeated runs of stored captures |
| Fairness | No stratum mean deviates beyond threshold; no stratum error exceeds the global error ratio |
| Privacy | MITM trace shows zero face-derived egress |
| Safety | Zero tier-X terms across the full generated corpus for all rule combinations |
| Deletion | Automated test confirms local wipe and server hard-delete |
| Paywall | Terms visible, close control present, restore works, on every variant |

### Analytics, with an allowlist

Events are enumerated in code and anything not on the list cannot be emitted. The list covers funnel steps, capture gate failures by gate type, scan completion, paywall view and outcome, plan card engagement, re-scan, and share. Gate-failure telemetry is the most operationally useful signal in the app: a gate that fails constantly is a capture-UX bug, and it will show up as score complaints long before anyone describes it as a capture problem.

Never emitted: any score tied to an identity in a third-party tool, any metric value, any image or derivative, any goal text.

### Watching for harm signals

Aggregate, never individual: re-scan frequency distribution, time-on-results distribution, and the rate at which the distress card triggers. These exist to inform rate-limiting and copy changes. Scan rate-limiting — one full scan per day — is itself a harm-reduction control as much as a cost control, and it should never be relaxed as a growth lever.

## Build order

&#91;embedded content: v1 build order · 11 workstreams, roughly 18 weeks to submission\]

The sequencing is driven by two things. The calibration panel starts early and runs long because it is the only workstream with an external dependency and a hard floor on elapsed time — recruiting and rating cannot be compressed by working more hours. And the spikes run first because spikes 1 and 2 can invalidate the schedule that follows them: if metric reliability or profile landmarking fails, the right response is to re-scope v1, not to push through.

Workstreams overlap deliberately. While the panel is being collected and rated, the geometry and profile work proceeds; while counsel reviews, TestFlight runs. The critical path is spikes to geometry to scoring to UX to submission, with the panel joining at scoring.

About 18 weeks to submission at 12–15 hours a week, which is longer than the 14 weeks in the original research note. The difference is the profile model and the fairness work, both of which were underestimated there. Treat App Review as a two-week buffer rather than a date — TrueDepth usage reliably draws questions.

## Open technical risks and spikes

Each of these is unresolved and resolvable only by building something small. Run the first three in week one, before committing to the full schedule — any of them could change the plan.

| # | Risk | Spike | Resolves by |
| --- | --- | --- | --- |
| 1 | Measurement reliability may not reach tier A or B for enough metrics to support a credible score | Capture one subject 10 times across sessions, compute candidate metrics from all three landmark sources, measure coefficient of variation per metric | Week 2. If most metrics land in tier C, the metric set shrinks and the score leans harder on appearance heads |
| 2 | Profile landmarking has no off-the-shelf solution and sits on the critical path | Label 100 profile images, fine-tune a small keypoint regressor, measure landmark error against held-out labels | Week 3. If error is too high, v1 ships frontal-only and profile moves to v1.1 |
| 3 | Calibration panel cost and licensing may be worse than estimated | Price a 200-face, 20-rater pilot on Prolific; get quotes for commercially licensed, consented face imagery | Week 2. This determines whether the budget estimate holds |
| 4 | Perspective correction without TrueDepth may be too noisy on the profile capture, which is rear-camera | Compare iris-diameter distance estimation against known ground-truth distances across devices | Week 4 |
| 5 | Appearance heads (skin, adiposity, hairline) need their own labelled data | Assess whether a small labelled set plus a pretrained backbone clears a usable accuracy bar, or whether these ship as coarse three-category outputs | Week 6 |
| 6 | App Review may question TrueDepth usage or flag the category under Guideline 4.3 | Prepare the written TrueDepth justification early; submit a TestFlight build well before the target date to surface objections | Week 11 |
| 7 | Whether derived scalar metrics are biometric identifiers under BIPA, CUBI and MHMDA | Privacy counsel review, with the architecture doc as the input | Before launch, non-negotiable |
| 8 | Core ML output may differ across compute units, breaking determinism | Run the same model on CPU, GPU and Neural Engine across device generations; compare bit-for-bit | Week 5. If they differ, pin the compute unit and accept the latency |

### The decision that gates everything else

Spikes 1 and 2 together determine whether the product thesis is buildable as specified. If metrics cannot be measured reliably enough from phone captures, then "the consistent one" is not a defensible position, and the product should be re-scoped around the things that *are* reliably measurable and most improvable — skin, adiposity, hair, grooming and photo technique — with bone metrics shown as context rather than as the core.

That fallback is not a failure case. It is arguably a better product for most users, and it maps directly onto the strongest evidence. It is simply a worse match for what the forum audience says it wants, which is a positioning and marketing problem rather than an engineering one.
