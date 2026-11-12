import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from mogcore import load_registry, Denylist  # noqa: E402
from mogcore.scoring import MetricReading, ScoreInput  # noqa: E402


@pytest.fixture(scope="session")
def reg():
    return load_registry()


@pytest.fixture(scope="session")
def denylist(reg):
    return Denylist(reg.denylist_raw)


def typical_readings(reg, sex="male", *, conf=0.9, iqr_frac=0.05, profile=True, **overrides):
    """Every metric exactly at its reference mean with a small IQR, unless overridden
    with a z-score: overrides={'facial_adiposity': 1.5} puts that metric at +1.5 SD."""
    out = {}
    for mid, m in reg.metrics.items():
        if m.pose == "profile" and not profile:
            continue
        if m.unit == "category":
            # categorical heads: hairline stage 1, no beard
            val = {"hairline_stage": 1.0, "beard_presence": 0.0}[mid]
            out[mid] = MetricReading(value=val, confidence=conf, iqr=0.0)
            continue
        mean, sd = m.ref(sex)
        z = overrides.get(mid, 0.0)
        out[mid] = MetricReading(value=mean + z * sd, confidence=conf, iqr=iqr_frac * sd)
    for k, v in overrides.items():
        if reg.metrics[k].unit == "category":
            out[k] = MetricReading(value=float(v), confidence=conf, iqr=0.0)
    return out


@pytest.fixture
def mk_input(reg):
    def _mk(sex="male", age_band="18-24", profile=True, **overrides):
        return ScoreInput(sex=sex, age_band=age_band, profile_captured=profile,
                          readings=typical_readings(reg, sex, profile=profile, **overrides))
    return _mk
