"""Appearance heads — the cheap, deterministic path (spike 5).

Two indices feed metrics.json's `skin_evenness` and `facial_adiposity` without any trained
model: simple, documented image and geometry statistics, normalised so they are stable under
the capture gates. They are honest proxies, labelled as such, and are what ships in v1 if the
trained heads are not affordable. The Swift port is ios/Mog/Geometry/Appearance.swift.
"""

from .skin import skin_evenness, SkinStats
from .adiposity import adiposity_proxy

__all__ = ["skin_evenness", "SkinStats", "adiposity_proxy"]
