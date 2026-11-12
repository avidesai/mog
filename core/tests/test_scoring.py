import json
from pathlib import Path

import pytest

from mogcore.scoring import score, MetricReading, ScoreInput, tier_for_percentile, percentile_from_std
from .conftest import typical_readings

FIXTURES = Path(__file__).resolve().parent.parent / "fixtures"


def _sampled_population(reg, n=2000, seed=7, sex="male"):
    import random
    rng = random.Random(seed)
    out = []
    for _ in range(n):
        rd = {}
        for mid, m in reg.metrics.items():
            if m.unit == "category":
                rd[mid] = MetricReading(1.0 if mid == "hairline_stage" else 0.0, 0.9, 0.0)
                continue
            mean, sd = m.ref(sex)
            rd[mid] = MetricReading(mean + rng.gauss(0, 1) * sd, 0.9, 0.08 * sd)
        out.append(score(ScoreInput(sex, "18-24", rd), reg))
    return out


def test_reference_population_is_calibrated_to_its_own_median(reg):
    """Faces sampled from the published norms must land at a median of 5.0 and fill the
    tier bands in their published proportions. This is the product's central calibration claim."""
    pop = _sampled_population(reg)
    scores = sorted(r.score for r in pop)
    median = scores[len(scores) // 2]
    assert 4.7 <= median <= 5.3, median
    tiers = {}
    for r in pop:
        tiers[r.tier] = tiers.get(r.tier, 0) + 1
    n = len(pop)
    assert 0.40 <= tiers["LTN"] / n <= 0.50
    assert 0.15 <= tiers["MTN"] / n <= 0.25
    assert 0.15 <= tiers["HTN"] / n <= 0.25
    assert 0.08 <= tiers["Chadlite"] / n <= 0.16
    assert 0.01 <= tiers.get("Chad", 0) / n <= 0.05


def test_typical_band_half_width_is_honest(reg):
    pop = _sampled_population(reg, n=600)
    halves = sorted((r.score_high - r.score_low) / 2 for r in pop)
    median_half = halves[len(halves) // 2]
    assert 0.3 <= median_half <= 0.6, median_half
    assert min(r.score_high - r.score_low for r in pop) >= 0.15 - 1e-9  # the floor (clamped at the scale ends)


def test_perfectly_average_face_is_an_outlier_by_design(reg, mk_input):
    """Every metric exactly at the mean maximises every toward_mean term at once. No real face
    does this; it is a mathematical corner, not a calibration target. Documented in Methodology."""
    r = score(mk_input(), reg)
    assert r.score > 9.0
    assert r.score_low < r.score <= r.score_high


def test_deterministic_bit_for_bit(reg, mk_input):
    a = score(mk_input(facial_adiposity=0.7, canthal_tilt_deg=-0.5), reg)
    b = score(mk_input(facial_adiposity=0.7, canthal_tilt_deg=-0.5), reg)
    assert a.to_dict() == b.to_dict()
    assert a.composite == b.composite


def test_order_of_readings_does_not_matter(reg):
    base = typical_readings(reg, facial_adiposity=1.2)
    reversed_order = dict(reversed(list(base.items())))
    a = score(ScoreInput("male", "18-24", base), reg)
    b = score(ScoreInput("male", "18-24", reversed_order), reg)
    assert a.composite == b.composite


def test_more_capture_noise_widens_band(reg):
    # a face with scatter (so it sits mid-scale where the band is informative)
    import random
    rng = random.Random(3)
    ov = {m.id: rng.gauss(0, 1) for m in reg.metrics.values() if m.unit != "category"}
    quiet = typical_readings(reg, iqr_frac=0.02, **ov)
    noisy = typical_readings(reg, iqr_frac=0.30, **ov)
    rq = score(ScoreInput("male", "18-24", quiet), reg)
    rn = score(ScoreInput("male", "18-24", noisy), reg)
    assert 1.0 < rq.score < 9.0  # mid-scale, where the band is informative
    assert (rn.score_high - rn.score_low) > (rq.score_high - rq.score_low)


def test_adiposity_high_lowers_score_and_low_does_not_raise_it(reg, mk_input):
    mid = score(mk_input(), reg).score
    high = score(mk_input(facial_adiposity=2.0), reg).score
    low = score(mk_input(facial_adiposity=-2.5), reg).score
    assert high < mid
    assert low <= mid + 0.4  # flat region: never rewards very low adiposity beyond -1sd


def test_fwhr_never_moves_the_score(reg, mk_input):
    a = score(mk_input(fwhr=0.0), reg).composite
    b = score(mk_input(fwhr=3.0), reg).composite
    assert a == b


def test_community_metric_barely_moves_score(reg, mk_input):
    a = score(mk_input(midface_ratio=0.0), reg).score
    b = score(mk_input(midface_ratio=2.5), reg).score
    assert abs(a - b) < 0.15


def test_low_confidence_suppresses(reg):
    rd = typical_readings(reg)
    rd["canthal_tilt_deg"] = MetricReading(value=4.1, confidence=0.3, iqr=0.1)
    r = score(ScoreInput("male", "18-24", rd), reg)
    m = next(x for x in r.metrics if x.id == "canthal_tilt_deg")
    assert m.display == "suppressed" and m.suppressed_reason == "low_confidence"


def test_profile_missing_marks_pose_missing_not_a_guess(reg, mk_input):
    r = score(mk_input(profile=False), reg)
    for m in r.metrics:
        if m.pose == "profile":
            assert m.display == "suppressed" and m.suppressed_reason == "pose_missing"
    assert r.n_scored > 0


def test_frontal_only_scan_is_comparable(reg, mk_input):
    full = score(mk_input(), reg).score
    frontal = score(mk_input(profile=False), reg).score
    assert abs(full - frontal) < 0.6


def test_beard_reduces_jaw_confidence(reg):
    rd = typical_readings(reg, conf=0.75, beard_presence=2)
    r = score(ScoreInput("male", "18-24", rd), reg)
    m = next(x for x in r.metrics if x.id == "bigonial_to_bizygomatic")
    assert m.confidence == pytest.approx(0.6)


def test_tier_bands(reg):
    assert tier_for_percentile(10)[0] == "LTN"
    assert tier_for_percentile(41)[0] == "LTN"
    assert tier_for_percentile(50)[0] == "MTN"
    assert tier_for_percentile(68)[0] == "HTN"
    assert tier_for_percentile(90)[0] == "Chadlite"
    assert tier_for_percentile(99)[0] == "Chad"


def test_percentile_interpolation_monotonic():
    table = [i / 100.0 for i in range(1001)]
    last = -1.0
    for s in [x / 50.0 for x in range(0, 500)]:
        p = percentile_from_std(s, table)
        assert p >= last
        last = p


def test_tier_c_metrics_display_as_category_only(reg, mk_input):
    r = score(mk_input(), reg)
    for m in r.metrics:
        if m.reliability_tier == "C" and m.display != "suppressed":
            assert m.display == "category" and m.weight == 0.0


def test_no_scorable_metrics_raises(reg):
    rd = {"fwhr": MetricReading(1.9, 0.9, 0.0)}
    with pytest.raises(ValueError):
        score(ScoreInput("male", "18-24", rd), reg)


def test_golden_fixtures(reg):
    """Cross-language determinism fixtures. The Swift port must reproduce these to 1e-6
    on composite_std and exactly on tier."""
    with open(FIXTURES / "scoring_cases.json", encoding="utf-8") as f:
        cases = json.load(f)
    for case in cases:
        rd = {k: MetricReading(**v) for k, v in case["readings"].items()}
        r = score(ScoreInput(case["sex"], case["age_band"], rd, case.get("profile_captured", True)), reg)
        exp = case["expected"]
        assert r.composite_std == pytest.approx(exp["composite_std"], abs=1e-6), case["name"]
        assert round(r.score, 2) == exp["score"], case["name"]
        assert r.tier == exp["tier"], case["name"]
