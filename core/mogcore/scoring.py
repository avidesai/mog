"""Rules-only deterministic scorer.

Score definition (shown in-app, Methodology screen):
    "A measured comparison against published population norms, weighted by
    evidence strength, expressed as a percentile of a sex-matched reference
    distribution." 0–10 is percentile / 10. The PSL tier is a named band of
    that percentile.

Pipeline (eng doc, "Scoring and calibration", $400 variant):
    1. per-metric z against the sex-matched reference (mean, sd)
    2. per-metric quality q from z and the metric's direction, clamped
    3. weight = reliability nominal × evidence cap
    4. composite = Σ w q / Σ w over AVAILABLE, non-suppressed, scorable metrics
    5. standardise composite against its analytic reference moments (so a
       scan with suppressed metrics is still comparable)
    6. map through the stored reference quantile table → percentile
    7. confidence band = capture noise (cross-frame IQR, propagated) ⊕ a
       fixed model-uncertainty term, mapped through the same table

No randomness, no learned component, no floating-point reduction-order
ambiguity: metrics are always iterated in registry order.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .registry import Metric, Registry, DATA_DIR

Q_CLAMP = 3.0
# For lower_better metrics the quality term is flat below (mean - FLAT_BELOW_SD)·sd,
# so the engine never rewards e.g. very low adiposity. (metrics.json note on facial_adiposity)
FLAT_BELOW_SD = 1.0
# Fixed model-uncertainty term in standardised composite units. The rules-only
# weighting is a considered judgement, not a calibration; this is the honest
# floor on how narrow the band may be. Tuned so a typical scan lands ~±0.5 pts.
MODEL_SIGMA_STD = 0.10
BAND_K = 1.0  # ±1σ → "likely" band (≈68%)
MIN_BAND_HALF_PTS = 0.15  # never display a band narrower than ±0.15 points
IQR_TO_SD = 1.349
BEARD_CONFIDENCE_FACTOR = 0.8
BEARD_AFFECTED = (
    "bigonial_to_bizygomatic", "chin_width_to_mouth", "gonial_angle_deg", "ramus_to_mandible_ratio",
    "cervicomental_angle_deg", "chin_projection_eline_mm", "mentolabial_angle_deg",
)

# Percentile → PSL tier. Published in Methodology. Nothing below LTN by design.
TIERS: tuple[tuple[float, str, str], ...] = (
    (45.0, "LTN", "Low-tier normie"),
    (65.0, "MTN", "Mid-tier normie"),
    (85.0, "HTN", "High-tier normie"),
    (97.0, "Chadlite", "Chadlite"),
    (100.1, "Chad", "Chad"),
)

SCORING_MODEL_VERSION = "rules-1.1.0"


def tier_for_percentile(p: float) -> tuple[str, str]:
    for upper, short, long in TIERS:
        if p < upper:
            return short, long
    return TIERS[-1][1], TIERS[-1][2]


@dataclass(frozen=True)
class MetricReading:
    """One metric as produced by the geometry/appearance layer: cross-frame median,
    landmark confidence in [0,1], and cross-frame interquartile range in metric units."""
    value: float
    confidence: float
    iqr: float = 0.0
    occluded: bool = False


@dataclass(frozen=True)
class ScoreInput:
    sex: str
    age_band: str
    readings: dict[str, MetricReading]
    profile_captured: bool = True


@dataclass
class MetricResult:
    id: str
    value: float | None
    z: float | None
    category: str | None            # low / typical / high
    quality: float | None           # signed, clamped
    weight: float
    display: str                    # point / band / category / suppressed
    suppressed_reason: str | None
    confidence: float | None
    ref_mean: float
    ref_sd: float
    evidence_grade: str
    reliability_tier: str
    direction: str
    pose: str


@dataclass
class ScoreResult:
    model_version: str
    percentile: float
    score: float
    score_low: float
    score_high: float
    tier: str
    tier_long: str
    composite: float
    composite_std: float
    sigma_capture_std: float
    sigma_total_std: float
    metrics: list[MetricResult]
    top_strength: str | None
    most_improvable: str | None
    n_scored: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "model_version": self.model_version,
            "percentile": round(self.percentile, 4),
            "score": round(self.score, 2),
            "score_low": round(self.score_low, 2),
            "score_high": round(self.score_high, 2),
            "tier": self.tier,
            "composite_std": round(self.composite_std, 6),
            "sigma_total_std": round(self.sigma_total_std, 6),
            "n_scored": self.n_scored,
            "top_strength": self.top_strength,
            "most_improvable": self.most_improvable,
            "metrics": {
                m.id: {
                    "value": None if m.value is None else round(m.value, 4),
                    "z": None if m.z is None else round(m.z, 4),
                    "category": m.category, "display": m.display,
                    "suppressed_reason": m.suppressed_reason,
                    "weight": round(m.weight, 4),
                }
                for m in self.metrics
            },
        }


# ---------------------------------------------------------------- reference

_REF_CACHE: dict[str, Any] | None = None


def load_composite_reference(path: Path | None = None) -> dict[str, Any]:
    global _REF_CACHE
    if _REF_CACHE is None or path is not None:
        p = path or (DATA_DIR / "composite_reference.json")
        with open(p, encoding="utf-8") as f:
            _REF_CACHE = json.load(f)
    return _REF_CACHE


def quality_from_z(z: float, direction: str) -> float:
    if direction == "toward_mean":
        q = -abs(z)
    elif direction == "higher_better":
        q = z
    elif direction == "lower_better":
        q = -z
        q = min(q, FLAT_BELOW_SD)  # flat below mean - 1sd
    else:
        raise ValueError(direction)
    return max(-Q_CLAMP, min(Q_CLAMP, q))


def quality_slope(z: float, direction: str) -> float:
    """|dq/dz| at z — used to propagate capture noise. Zero in clamped/flat regions."""
    if abs(z) >= Q_CLAMP:
        return 0.0
    if direction == "lower_better" and -z >= FLAT_BELOW_SD:
        return 0.0
    return 1.0


def category_from_z(z: float) -> str:
    if z < -1.0:
        return "low"
    if z > 1.0:
        return "high"
    return "typical"


def percentile_from_std(s: float, table: list[float]) -> float:
    """Linear interpolation into a sorted table of 1001 standardised-composite
    quantiles (table[i] is the i/10-th percentile)."""
    n = len(table) - 1
    if s <= table[0]:
        return 0.0
    if s >= table[-1]:
        return 100.0
    # binary search
    lo, hi = 0, n
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if table[mid] <= s:
            lo = mid
        else:
            hi = mid
    a, b = table[lo], table[hi]
    frac = 0.0 if b == a else (s - a) / (b - a)
    return (lo + frac) * (100.0 / n)


def _display_mode(m: Metric) -> str:
    return {"A": "point", "B": "band", "C": "category", "D": "suppressed"}[m.reliability_tier]


def score(inp: ScoreInput, reg: Registry, reference: dict[str, Any] | None = None) -> ScoreResult:
    ref = reference or load_composite_reference()
    sex = inp.sex
    if sex not in ("male", "female"):
        raise ValueError("sex must be 'male' or 'female'")
    table: list[float] = ref["quantiles_std"][sex]
    moments: dict[str, dict[str, float]] = ref["q_moments"][sex]

    beard = inp.readings.get("beard_presence")
    beard_present = beard is not None and beard.value >= 1

    results: list[MetricResult] = []
    sum_w = 0.0
    sum_wq = 0.0
    sum_w_mu = 0.0
    var_ref = 0.0
    var_cap = 0.0

    for mid in reg.metric_order:
        m = reg.metrics[mid]
        mean, sd = m.ref(sex)
        r = inp.readings.get(mid)
        base = dict(id=mid, ref_mean=mean, ref_sd=sd, evidence_grade=m.evidence_grade,
                    reliability_tier=m.reliability_tier, direction=m.direction, pose=m.pose,
                    weight=0.0, quality=None)

        if r is None:
            reason = "pose_missing" if (m.pose == "profile" and not inp.profile_captured) else "not_measured"
            results.append(MetricResult(value=None, z=None, category=None, display="suppressed",
                                        suppressed_reason=reason, confidence=None, **base))
            continue

        conf = r.confidence
        if beard_present and mid in BEARD_AFFECTED:
            conf *= BEARD_CONFIDENCE_FACTOR
        if r.occluded:
            results.append(MetricResult(value=None, z=None, category=None, display="suppressed",
                                        suppressed_reason="occluded", confidence=conf, **base))
            continue
        if conf < m.confidence_floor:
            results.append(MetricResult(value=None, z=None, category=None, display="suppressed",
                                        suppressed_reason="low_confidence", confidence=conf, **base))
            continue
        if m.reliability_tier == "D":
            results.append(MetricResult(value=None, z=None, category=None, display="suppressed",
                                        suppressed_reason="not_shipped", confidence=conf, **base))
            continue

        z = (r.value - mean) / sd
        cat = category_from_z(z)
        display = _display_mode(m)
        q = None
        w = 0.0
        if m.scorable:
            q = quality_from_z(z, m.direction)
            w = m.weight_for(sex)
            mo = moments[mid]
            sum_w += w
            sum_wq += w * q
            sum_w_mu += w * mo["mean"]
            var_ref += (w * mo["sd"]) ** 2
            # capture noise: the larger of the cross-frame IQR (this capture) and the between-session
            # noise_sd (what the harness measured), in z units, through the quality slope
            z_sd = max((r.iqr / IQR_TO_SD) if r.iqr > 0 else 0.0, m.noise_sd) / sd
            var_cap += (w * z_sd * quality_slope(z, m.direction)) ** 2
        base["weight"] = w
        base["quality"] = q
        results.append(MetricResult(value=r.value, z=z, category=cat, display=display,
                                    suppressed_reason=None, confidence=conf, **base))

    if sum_w <= 0:
        raise ValueError("No scorable metrics available — capture must be retaken")

    composite = sum_wq / sum_w
    ref_mean = sum_w_mu / sum_w
    ref_sd = math.sqrt(var_ref) / sum_w
    composite_std = (composite - ref_mean) / ref_sd
    sigma_capture_std = (math.sqrt(var_cap) / sum_w) / ref_sd
    sigma_total = math.sqrt(sigma_capture_std ** 2 + MODEL_SIGMA_STD ** 2)

    pct = percentile_from_std(composite_std, table)
    pct_lo = percentile_from_std(composite_std - BAND_K * sigma_total, table)
    pct_hi = percentile_from_std(composite_std + BAND_K * sigma_total, table)
    # Percentiles saturate in the tails, which would display a 9.99 with a ±0.00 band —
    # false precision. Enforce a minimum half-width in score points, clamped to the scale.
    pct_lo = min(pct_lo, pct - MIN_BAND_HALF_PTS * 10.0)
    pct_hi = max(pct_hi, pct + MIN_BAND_HALF_PTS * 10.0)
    pct_lo, pct_hi = max(0.0, pct_lo), min(100.0, pct_hi)
    tier, tier_long = tier_for_percentile(pct)

    scored = [x for x in results if x.quality is not None and x.weight > 0]
    # strength: best weighted quality. improvable: worst quality among metrics flagged
    # `modifiable` (soft tissue / skin — things a tier-1/2 rule can move). Bone is never
    # called improvable. None when nothing modifiable reads below typical.
    top_strength = max(scored, key=lambda x: (x.quality * x.weight, x.id)).id if scored else None
    improvable_pool = [x for x in scored if reg.metrics[x.id].modifiable and x.quality < 0]
    most_improvable = min(improvable_pool, key=lambda x: (x.quality, x.id)).id if improvable_pool else None

    return ScoreResult(
        model_version=SCORING_MODEL_VERSION,
        percentile=pct, score=pct / 10.0, score_low=pct_lo / 10.0, score_high=pct_hi / 10.0,
        tier=tier, tier_long=tier_long, composite=composite, composite_std=composite_std,
        sigma_capture_std=sigma_capture_std, sigma_total_std=sigma_total,
        metrics=results, top_strength=top_strength, most_improvable=most_improvable,
        n_scored=len(scored),
    )
