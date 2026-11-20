# Scoring: settled

- Rules-only at launch; no learned component before peer-rating data exists (11 Nov).
- Never train on SCUT-FBP5500 (non-commercial, biased).
- CV is not a reliability measure; noise relative to population spread is (12 Nov). Do not reintroduce fixed tier weights.
- The band includes between-session noise. A narrower, prettier band is not a design option.
- Release gate: median per-person SD ≤ 0.6 on measured noise, no person above 1.0, coverage ≈ 68% (12 Nov; replaced 0.2).
- Percentile is against the published-norm reference distribution, never against other users.
- No colour ever encodes score quality.
- rules-1.2.0 (20 Nov, owner delegated the call): v1 scores the frontal panel only (`PANEL_POSE`). Profile readings, including the angles MogGeometry derives from the front mesh, are suppressed as `pose_missing` and never scored. A profile capture would be a new model version with its own reference; scans never mix panels within a version.
- rules-1.2.0: the reference table is built from noisy readings (true z plus N(0, noise_sd/sd)), so a typical capture lands at the median. Rebuild it when Spike 1 writes measured noise_sd.
- No "potential" score and no per-task score claims. A tier ladder shows the band across the tier marks, never the distance to the next tier.

## Revisit
- MODEL_SIGMA_STD = 0.10 is a judgement; revisit once peer ratings exist.
- Independence assumption in the reference table; replace with an empirical table in v1.1.
