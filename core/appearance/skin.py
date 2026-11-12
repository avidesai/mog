"""Skin evenness from the camera frame's Y / Cb / Cr planes inside a skin mask.

    evenness = 1 − clamp( w_t · texture + w_c · chroma_spread , 0, 1 )

texture        high-frequency energy of the ILLUMINATION-NORMALISED luma inside the mask:
               Y_norm = Y / blur_large(Y); texture = std(Y_norm − blur_small(Y_norm)). Dividing by a
               large-scale blur removes lighting gradients (a brighter left cheek is lighting, not skin),
               which is why the index is stable across the luma gate's allowed range.
chroma_spread  std of Cb and Cr inside the mask (the "skin colour homogeneity" of Fink et al.),
               after removing a large-scale chroma gradient the same way. Blotchiness, redness and
               hyperpigmentation all raise it; even skin of ANY tone keeps it low — the index is a
               spread, not a level, so it carries no skin-colour preference by construction.

Scaling constants were set so that a synthetic clean patch reads ≈0.9 and a heavily blotchy one
≈0.3; the harness (week 9) re-tunes them against the reference range in metrics.json.

Deterministic, no learned parameters. Works on a 64–128 px wide face crop; more is wasted.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

W_TEXTURE = 6.0         # texture term is ~0.01–0.10 after the sqrt-illumination scaling
W_CHROMA = 0.045        # chroma std is ~2–12 (8-bit units)
LARGE_SIGMA = 9.0       # illumination scale (px on a ~96 px face crop)
SMALL_SIGMA = 1.2       # pore/texture scale


@dataclass(frozen=True)
class SkinStats:
    texture: float
    chroma_spread: float
    evenness: float
    n_pixels: int


def _gauss1d(sigma: float) -> np.ndarray:
    r = int(3 * sigma + 0.5)
    x = np.arange(-r, r + 1, dtype=np.float64)
    k = np.exp(-0.5 * (x / sigma) ** 2)
    return k / k.sum()


def blur(img: np.ndarray, sigma: float) -> np.ndarray:
    """Separable Gaussian blur with edge replication. Same algorithm as the Swift port."""
    k = _gauss1d(sigma)
    r = len(k) // 2
    p = np.pad(img.astype(np.float64), r, mode="edge")
    tmp = np.zeros_like(p)
    for i, w in enumerate(k):
        tmp += w * np.roll(p, i - r, axis=1)
    out = np.zeros_like(p)
    for i, w in enumerate(k):
        out += w * np.roll(tmp, i - r, axis=0)
    return out[r:-r, r:-r]


def skin_evenness(y: np.ndarray, cb: np.ndarray, cr: np.ndarray, mask: np.ndarray) -> SkinStats:
    """y, cb, cr: 2-D float arrays in 8-bit units (0–255), same shape (chroma upsampled to luma).
    mask: boolean array, True on skin (cheeks + forehead; never eyes, brows, lips, hair)."""
    assert y.shape == cb.shape == cr.shape == mask.shape
    n = int(mask.sum())
    if n < 200:
        return SkinStats(float("nan"), float("nan"), float("nan"), n)
    yf = np.clip(y.astype(np.float64), 1.0, 255.0)
    illum = np.clip(blur(yf, LARGE_SIGMA), 1.0, None)
    y_norm = yf / illum                                  # ≈1.0 everywhere on flat skin (gradient removed)
    # High-pass in absolute units, then scaled by sqrt(illumination): real skin texture scales with
    # reflectance (would argue for a fully relative measure) while sensor noise is absolute (would
    # argue for an absolute one). The square root is the shot-noise compromise and keeps the index
    # within ~0.04 across the luma range the gate allows for the same physical perturbation.
    hp = (y_norm - blur(y_norm, SMALL_SIGMA)) * illum
    texture = float(np.std((hp / np.sqrt(illum / 128.0))[mask])) / 128.0

    def spread(c: np.ndarray) -> float:
        cf = c.astype(np.float64)
        resid = cf - blur(cf, LARGE_SIGMA)
        return float(np.std(resid[mask]))

    chroma = (spread(cb) + spread(cr)) / 2.0
    raw = W_TEXTURE * texture + W_CHROMA * chroma
    evenness = float(1.0 - min(1.0, max(0.0, raw)))
    return SkinStats(texture=texture, chroma_spread=chroma, evenness=evenness, n_pixels=n)
