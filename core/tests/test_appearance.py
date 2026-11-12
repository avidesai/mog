import numpy as np
import pytest

from appearance.skin import skin_evenness, blur
from appearance.adiposity import adiposity_proxy


def _patch(seed=0, blotch=0.0, texture=0.0, gradient=0.0, size=96, tone=(150, 110, 150)):
    """Synthetic skin crop: base tone (Y, Cb, Cr), optional blotches (chroma + luma spots),
    optional fine texture noise, optional left→right lighting gradient (multiplicative on Y)."""
    rng = np.random.default_rng(seed)
    y = np.full((size, size), float(tone[0]))
    cb = np.full((size, size), float(tone[1]))
    cr = np.full((size, size), float(tone[2]))
    if texture > 0:
        y += rng.normal(0, texture, y.shape)
    if blotch > 0:
        for _ in range(12):
            cx, cy, r = rng.integers(10, size - 10), rng.integers(10, size - 10), rng.integers(4, 9)
            yy, xx = np.ogrid[:size, :size]
            m = (xx - cx) ** 2 + (yy - cy) ** 2 < r * r
            y[m] -= blotch * 25
            cr[m] += blotch * 14
            cb[m] -= blotch * 6
    if gradient > 0:
        ramp = np.linspace(1 - gradient, 1 + gradient, size)[None, :]
        y = y * ramp
    mask = np.ones((size, size), bool)
    return np.clip(y, 0, 255), np.clip(cb, 0, 255), np.clip(cr, 0, 255), mask


def test_clean_skin_reads_high_and_blotchy_reads_low():
    clean = skin_evenness(*_patch(texture=1.0)).evenness
    blotchy = skin_evenness(*_patch(texture=1.0, blotch=1.0)).evenness
    rough = skin_evenness(*_patch(texture=9.0)).evenness
    assert clean > 0.8, clean
    assert blotchy < clean - 0.25, (clean, blotchy)
    assert rough < clean - 0.15, (clean, rough)


def test_lighting_gradient_barely_moves_the_index():
    """A 30% left-to-right brightness ramp is lighting, not skin. The illumination normalisation
    must make the index insensitive to it — this is the property the luma gate relies on."""
    flat = skin_evenness(*_patch(seed=3, texture=2.0, blotch=0.4)).evenness
    lit = skin_evenness(*_patch(seed=3, texture=2.0, blotch=0.4, gradient=0.30)).evenness
    assert abs(flat - lit) < 0.04, (flat, lit)


def test_index_is_tone_invariant():
    """Same spread, different base tone → same index. The measure is a spread, not a level."""
    light = skin_evenness(*_patch(seed=5, texture=2.0, blotch=0.5, tone=(200, 115, 140))).evenness
    deep = skin_evenness(*_patch(seed=5, texture=2.0, blotch=0.5, tone=(80, 125, 150))).evenness  # 80 ≈ the luma gate floor (0.30)
    # Residual ≈0.05 across the full luma range the gate allows, for an identical ABSOLUTE perturbation.
    # Known, documented, and measured for real in the week-9 fairness smoke (stratified by skin tone).
    # If it is real on real faces, the fix is the luma gate floor (0.30 → 0.35), not the index.
    assert abs(light - deep) < 0.06, (light, deep)


def test_too_few_pixels_is_nan():
    y, cb, cr, mask = _patch()
    mask[:] = False
    mask[:10, :10] = True
    assert np.isnan(skin_evenness(y, cb, cr, mask).evenness)


def test_blur_preserves_mean():
    img = np.random.default_rng(1).uniform(50, 200, (64, 64))
    assert abs(blur(img, 4.0).mean() - img.mean()) < 0.5


def _points(lower_scale=1.0):
    return {
        "zygion_l": (0.070, 0.010, -0.010), "zygion_r": (-0.070, 0.010, -0.010),
        "gonion_l": (0.052 * lower_scale, -0.060, -0.030), "gonion_r": (-0.052 * lower_scale, -0.060, -0.030),
        "stomion": (0.0, -0.040, 0.015), "menton": (0.0, -0.085, 0.000), "pogonion": (0.0, -0.075, 0.010),
        "nasion": (0.0, 0.040, 0.010),
        "chin_lateral_l": (0.025 * lower_scale, -0.070, 0.004), "chin_lateral_r": (-0.025 * lower_scale, -0.070, 0.004),
    }


def test_wider_lower_face_reads_more_adipose():
    lean, _ = adiposity_proxy(_points(0.85))
    full, _ = adiposity_proxy(_points(1.25))
    assert lean is not None and full is not None
    assert full > lean + 0.1, (lean, full)
    assert 0.0 <= lean <= 1.0 and 0.0 <= full <= 1.0


def test_missing_points_returns_none():
    idx, terms = adiposity_proxy({"stomion": (0, 0, 0)})
    assert idx is None and terms == {}


def test_mesh_terms_are_used_when_available():
    pts = _points()
    rng = np.random.default_rng(2)
    # a cheek "surface" that bulges forward on both sides, and a submental bulge
    mesh = []
    for _ in range(400):
        x = rng.uniform(-0.07, 0.07); y = rng.uniform(-0.06, 0.01)
        z = 0.012 if 0.03 < abs(x) < 0.065 else -0.01
        mesh.append((x, y, z))
    mesh += [(rng.uniform(-0.01, 0.01), -0.095, 0.016) for _ in range(10)]
    idx, terms = adiposity_proxy(pts, mesh)
    assert {"lower_face_width", "cheek_fullness", "submental_bulge"} <= set(terms)
    assert idx is not None and idx > 0.5
