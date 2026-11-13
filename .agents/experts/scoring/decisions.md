# Scoring — settled

- Rules-only at launch; no learned component before peer-rating data exists (11 Nov).
- Never train on SCUT-FBP5500 (non-commercial, biased).
- CV is not a reliability measure; noise relative to population spread is (12 Nov). Do not reintroduce fixed tier weights.
- The band includes between-session noise. A narrower, prettier band is not a design option.
- Release gate: median per-person SD ≤ 0.6 on measured noise, no person above 1.0, coverage ≈ 68% (12 Nov; replaced 0.2).
- Percentile is against the published-norm reference distribution, never against other users.
- No colour ever encodes score quality.

## Revisit
- MODEL_SIGMA_STD = 0.10 is a judgement; revisit once peer ratings exist.
- Independence assumption in the reference table; replace with an empirical table in v1.1.
