import json
from pathlib import Path

import pytest

from mogcore.progress import compare
from mogcore.scoring import MetricReading, ScoreInput

FIXTURES = Path(__file__).resolve().parent.parent / "fixtures"


def _inp(scan):
    return ScoreInput(scan["sex"], scan["age_band"], {k: MetricReading(**v) for k, v in scan["readings"].items()}, scan["profile_captured"])


def test_golden_progress_fixtures(reg):
    """Cross-language fixtures for scan-to-scan change. Ports reproduce the flags exactly and the deltas to 1e-6."""
    with open(FIXTURES / "progress_cases.json", encoding="utf-8") as f:
        cases = json.load(f)
    assert cases
    for case in cases:
        c = compare(_inp(case["before"]), _inp(case["after"]), reg)
        exp = case["expected"]
        assert c.comparable == exp["comparable"], case["name"]
        assert c.score_delta == pytest.approx(exp["score_delta"], abs=1e-6), case["name"]
        assert c.score_within_noise == exp["score_within_noise"], case["name"]
        assert [(m.id, m.within_noise, m.better) for m in c.metrics] == [(m["id"], m["within_noise"], m["better"]) for m in exp["metrics"]], case["name"]
        for got, want in zip(c.metrics, exp["metrics"]):
            assert got.delta == pytest.approx(want["delta"], abs=1e-6), case["name"]


def test_identical_scans_report_no_change(reg, mk_input):
    c = compare(mk_input(), mk_input(), reg)
    assert c.score_delta == 0 and c.score_within_noise
    assert c.metrics and all(m.within_noise and m.delta == 0 for m in c.metrics)


def test_only_modifiable_metrics_are_listed(reg, mk_input):
    c = compare(mk_input(lower_third_split=2.0), mk_input(lower_third_split=-2.0), reg)
    assert all(reg.metrics[m.id].modifiable for m in c.metrics)
    assert "lower_third_split" not in [m.id for m in c.metrics]


def test_a_clear_change_is_better_or_worse_by_direction(reg, mk_input):
    c = compare(mk_input(facial_adiposity=1.8, skin_evenness=0.5), mk_input(facial_adiposity=0.4, skin_evenness=-1.5), reg)
    by = {m.id: m for m in c.metrics}
    assert not by["facial_adiposity"].within_noise and by["facial_adiposity"].better
    assert not by["skin_evenness"].within_noise and not by["skin_evenness"].better
    assert [m.within_noise for m in c.metrics] == sorted(m.within_noise for m in c.metrics)


def test_a_small_change_stays_inside_the_noise(reg, mk_input):
    c = compare(mk_input(skin_evenness=-1.0), mk_input(skin_evenness=-0.9), reg)
    assert {m.id: m for m in c.metrics}["skin_evenness"].within_noise
