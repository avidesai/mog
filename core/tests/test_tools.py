"""The Spike-1 analysis tools are what turn real captures into noise_sd and tiers. Their self-tests run here."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))

import cv_analysis  # noqa: E402
import harness  # noqa: E402


def test_cv_analysis_recovers_single_capture_noise_and_grades_on_r():
    cv_analysis.selftest(quiet=True)


def test_components_needs_two_sessions():
    import math
    assert all(math.isnan(x) for x in cv_analysis.components([[1.0, 1.1, 0.9]]))


def test_harness_pools_people_without_folding_their_spread_into_noise():
    harness.selftest(quiet=True)
