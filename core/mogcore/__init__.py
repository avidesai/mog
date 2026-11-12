"""mog-core — deterministic reference implementation of the Mog scoring,
recommendation and habit engines.

This is the specification the iOS app (Swift) follows. Everything here is
pure, deterministic, and free of any learned component. The JSON files in
../data are the single source of truth shared by both implementations; the
fixtures in ../fixtures are the cross-language determinism tests.
"""

from .registry import Registry, load_registry
from .scoring import ScoreInput, ScoreResult, MetricReading, score
from .planner import PlanInput, PlanResult, build_plan
from .habit import HabitState, HabitEngine, DistressSignals
from .denylist import Denylist

__all__ = [
    "Registry", "load_registry",
    "ScoreInput", "ScoreResult", "MetricReading", "score",
    "PlanInput", "PlanResult", "build_plan",
    "HabitState", "HabitEngine", "DistressSignals",
    "Denylist",
]

__version__ = "0.1.0"
