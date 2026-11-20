"""What changed between two scans of the same person.

The score moves a little between sessions with no real change, so a difference is only
reported as a change when it clears the noise:
  - Score: the difference must exceed the wider of the two scans' upper half-bands.
  - Metric: the difference must exceed 1.96 standard deviations of a difference of two
    readings, each with the noise the scorer already uses (the larger of that capture's
    cross-frame IQR and the between-session noise_sd).
Only modifiable metrics are compared. Bone does not change, so it is never listed.
Scans on different model versions are not comparable.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any

from .registry import Registry
from .scoring import IQR_TO_SD, ScoreInput, quality_from_z, score

Z95 = 1.96


@dataclass(frozen=True)
class MetricChange:
    id: str
    before: float
    after: float
    delta: float
    within_noise: bool
    better: bool        # the reading moved the way its direction rewards


@dataclass(frozen=True)
class ScanChange:
    comparable: bool
    score_before: float
    score_after: float
    score_delta: float
    score_within_noise: bool
    metrics: list[MetricChange]     # clear changes first, then by size in reference SDs


def _reading_sd(inp: ScoreInput, mid: str, noise_sd: float) -> float:
    iqr = inp.readings[mid].iqr
    return max((iqr / IQR_TO_SD) if iqr > 0 else 0.0, noise_sd)


def compare(before: ScoreInput, after: ScoreInput, reg: Registry, reference: dict[str, Any] | None = None) -> ScanChange:
    a = score(before, reg, reference)
    b = score(after, reg, reference)
    delta = b.score - a.score
    noise = max(b.score_high - b.score, a.score_high - a.score)
    am = {m.id: m for m in a.metrics}
    rows: list[tuple[bool, float, MetricChange]] = []
    for mb in b.metrics:
        m = reg.metrics[mb.id]
        ma = am.get(mb.id)
        if not m.modifiable or not m.scorable or ma is None or ma.value is None or mb.value is None:
            continue
        d = mb.value - ma.value
        sd = math.hypot(_reading_sd(before, m.id, m.noise_sd), _reading_sd(after, m.id, m.noise_sd))
        within = abs(d) < Z95 * sd
        better = quality_from_z(mb.z, m.direction) > quality_from_z(ma.z, m.direction)
        rows.append((within, -abs(mb.z - ma.z), MetricChange(m.id, ma.value, mb.value, d, within, better)))
    rows.sort(key=lambda r: (r[0], r[1], r[2].id))
    return ScanChange(
        comparable=a.model_version == b.model_version,
        score_before=a.score, score_after=b.score, score_delta=delta,
        score_within_noise=abs(delta) < noise,
        metrics=[r[2] for r in rows],
    )
