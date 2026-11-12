"""Facial adiposity proxy from mesh geometry alone.

Perceived facial adiposity tracks three things a pose-normalised 3-D mesh shows directly
(Coetzee 2009; Re & Rule 2016; the eng doc's "adiposity head" covariates):

    lower_face_width   width of the face at the level midway between stomion and menton,
                       relative to bizygomatic width (soft tissue over the mandible)
    cheek_fullness     how far the cheek surface sits in FRONT of the zygion–gonion line
                       (z-prominence of the malar soft tissue), relative to face height
    jaw_softness       1 − (bigonial / bizygomatic)·k is NOT used — bigonial is already a metric;
                       instead: the chin–neck fold, approximated by how much the submental
                       surface below menton bulges forward relative to pogonion (only when the
                       mesh reaches below menton; otherwise omitted)

    index = sigmoid( mean of available z-terms )  ∈ (0, 1)

Reference moments for each term are provisional and tuned by the week-9 harness, exactly like the
metric reference ranges. This is a geometric proxy and is labelled as such in the metric card.
Direction `lower_better` is applied by the scorer only down to mean − 1 SD (flat below), so the
proxy can never reward a gaunt face.
"""

from __future__ import annotations

import math
from typing import Mapping, Sequence

Point = Sequence[float]  # (x, y, z) metres in the face anchor frame

# provisional reference (mean, sd) per term, from eyeballing Farkas soft-tissue norms — the harness replaces these
REF = {
    "lower_face_width": (0.68, 0.05),
    "cheek_fullness": (0.055, 0.015),
    "submental_bulge": (0.0, 0.004),
}


def _dist_xy(a: Point, b: Point) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def adiposity_proxy(p: Mapping[str, Point], mesh: Sequence[Point] | None = None) -> tuple[float | None, dict[str, float]]:
    """p: anatomical points (zygion_l/r, gonion_l/r, stomion, menton, pogonion, chin_lateral_l/r).
    mesh: optional full vertex list for the cheek-fullness and submental terms.
    Returns (index in (0,1) or None if nothing could be computed, the raw terms)."""
    terms: dict[str, float] = {}
    try:
        bizyg = _dist_xy(p["zygion_l"], p["zygion_r"])
    except KeyError:
        return None, terms
    if bizyg <= 0:
        return None, terms

    # lower face width: lateral extent of the mesh at the mid-chin level, else chin_lateral points
    if "stomion" in p and "menton" in p:
        level = (p["stomion"][1] + p["menton"][1]) / 2
        if mesh is not None:
            band = [v for v in mesh if abs(v[1] - level) < 0.004]
            if len(band) >= 6:
                xs = [v[0] for v in band]
                terms["lower_face_width"] = (max(xs) - min(xs)) / bizyg
        if "lower_face_width" not in terms and "chin_lateral_l" in p and "chin_lateral_r" in p:
            terms["lower_face_width"] = _dist_xy(p["chin_lateral_l"], p["chin_lateral_r"]) / bizyg * 1.35

    # cheek fullness: max z of mesh in the cheek box, measured forward of the zygion–gonion chord
    if mesh is not None and all(k in p for k in ("gonion_l", "gonion_r", "nasion", "menton")):
        face_h = abs(p["nasion"][1] - p["menton"][1])
        vals = []
        for side, zy, go in (("l", p["zygion_l"], p["gonion_l"]), ("r", p["zygion_r"], p["gonion_r"])):
            sign = 1 if zy[0] >= 0 else -1
            box = [v for v in mesh if v[0] * sign > abs(zy[0]) * 0.45 and v[0] * sign < abs(zy[0]) * 0.95 and v[1] < zy[1] and v[1] > go[1]]
            if len(box) >= 10 and face_h > 0:
                chord_z = (zy[2] + go[2]) / 2
                vals.append((max(v[2] for v in box) - chord_z) / face_h)
        if vals:
            terms["cheek_fullness"] = sum(vals) / len(vals)

    # submental bulge: vertices below menton (if the mesh has any) — forward of pogonion means a soft chin-neck
    if mesh is not None and "menton" in p and "pogonion" in p:
        below = [v for v in mesh if v[1] < p["menton"][1] - 0.003 and abs(v[0]) < 0.015]
        if len(below) >= 6:
            terms["submental_bulge"] = max(v[2] for v in below) - p["pogonion"][2]

    if not terms:
        return None, terms
    zs = [(terms[k] - REF[k][0]) / REF[k][1] for k in terms]
    z = sum(zs) / len(zs)
    index = 1.0 / (1.0 + math.exp(-0.9 * z))
    # map so the reference mean lands at 0.45 (metrics.json facial_adiposity mean)
    index = 0.45 + (index - 0.5) * 0.9
    return max(0.0, min(1.0, index)), terms
