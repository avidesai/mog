"""Regenerates fixtures/scoring_cases.json from a fixed set of synthetic faces.
Run only when the scoring model version changes, and bump SCORING_MODEL_VERSION."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tests"))

from mogcore import load_registry  # noqa: E402
from mogcore.scoring import score, ScoreInput, MetricReading, SCORING_MODEL_VERSION  # noqa: E402
from conftest import typical_readings  # noqa: E402

CASES = [
    ("average_male_full", "male", "18-24", True, {}),
    ("average_female_full", "female", "25-34", True, {}),
    ("average_male_frontal_only", "male", "18-24", False, {}),
    ("high_adiposity_soft_neck", "male", "18-24", True, {"facial_adiposity": 1.8, "cervicomental_angle_deg": 2.0, "bigonial_to_bizygomatic": -1.3}),
    ("uneven_skin_good_structure", "male", "25-34", True, {"skin_evenness": -1.7, "symmetry_index": 0.8, "canthal_tilt_deg": 1.2}),
    ("lean_sharp_profile", "male", "18-24", True, {"facial_adiposity": -1.5, "cervicomental_angle_deg": -1.4, "facial_convexity_deg": 0.3}),
    ("retruded_chin_convex", "male", "18-24", True, {"chin_projection_eline_mm": -2.5, "facial_convexity_deg": -2.2, "mentolabial_angle_deg": 1.2}),
    ("female_wide_set_eyes_full_lips", "female", "18-24", True, {"intercanthal_to_width_ratio": 1.6, "lip_ratio_upper_lower": 0.2, "canthal_tilt_deg": 0.9}),
    ("extreme_everything_bad", "male", "35-44", True, {m: 2.8 for m in ("facial_adiposity", "cervicomental_angle_deg", "nasal_width_to_intercanthal", "face_height_to_width", "bigonial_to_bizygomatic")} | {"skin_evenness": -2.8, "symmetry_index": -2.8, "canthal_tilt_deg": -2.8}),
    ("bearded_low_conf", "male", "25-34", True, {"beard_presence": 2, "bigonial_to_bizygomatic": -1.0}),
]


def sampled_readings(reg, sex, seed, profile=True, **overrides):
    """A realistic face: every metric drawn from the reference distribution (fixed seed), then
    the named overrides applied as z-scores. Mean-faces are a mathematical corner, not a fixture."""
    import random
    rng = random.Random(seed)
    base = typical_readings(reg, sex, profile=profile)
    out = {}
    for mid, r in base.items():
        m = reg.metrics[mid]
        if m.unit == "category":
            out[mid] = r
            continue
        mean, sd = m.ref(sex)
        z = overrides.get(mid, rng.gauss(0.0, 1.0))
        out[mid] = MetricReading(value=round(mean + z * sd, 6), confidence=0.9, iqr=round(0.08 * sd, 6))
    for k, v in overrides.items():
        if reg.metrics[k].unit == "category":
            out[k] = MetricReading(value=float(v), confidence=0.9, iqr=0.0)
    return out


def main() -> None:
    reg = load_registry()
    out = []
    for i, (name, sex, age, profile, ov) in enumerate(CASES):
        rd = sampled_readings(reg, sex, seed=1000 + i, profile=profile, **ov)
        r = score(ScoreInput(sex, age, rd, profile), reg)
        out.append({
            "name": name, "model_version": SCORING_MODEL_VERSION, "sex": sex, "age_band": age,
            "profile_captured": profile,
            "readings": {k: {"value": v.value, "confidence": v.confidence, "iqr": v.iqr, "occluded": v.occluded} for k, v in rd.items()},
            "expected": {"composite_std": round(r.composite_std, 9), "percentile": round(r.percentile, 4),
                         "score": round(r.score, 2), "score_low": round(r.score_low, 2),
                         "score_high": round(r.score_high, 2), "tier": r.tier, "n_scored": r.n_scored},
        })
        print(f"{name:34s} {r.score:4.2f} [{r.score_low:4.2f}–{r.score_high:4.2f}] {r.tier:8s} n={r.n_scored}")
    (ROOT / "fixtures").mkdir(exist_ok=True)
    with open(ROOT / "fixtures" / "scoring_cases.json", "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)


if __name__ == "__main__":
    main()
