"""Loads and validates the data tables. Fails loudly on any inconsistency so a
bad authoring change can never reach a build."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

DATA_DIR = Path(__file__).resolve().parent.parent / "data"

EVIDENCE_GRADES = ("strong", "moderate", "weak", "community", "contradicted")
# Score weight caps per evidence grade (eng doc, "Evidence grade is independent of reliability").
EVIDENCE_CAP = {"strong": 1.0, "moderate": 0.6, "weak": 0.1, "community": 0.02, "contradicted": 0.0}
# Nominal weight per reliability tier (eng doc, "Reliability tiers").
TIER_WEIGHT = {"A": 1.0, "B": 0.6, "C": 0.0, "D": 0.0}
DIRECTIONS = ("toward_mean", "higher_better", "lower_better", "none")
SAFETY_TIERS = (1, 2, 3, 4, "X")
SEXES = ("male", "female")
AGE_BANDS = ("18-24", "25-34", "35-44", "45+")


@dataclass(frozen=True)
class Metric:
    id: str
    name: str
    short: str
    unit: str
    pose: str
    direction: str
    evidence_grade: str
    reliability_tier: str
    confidence_floor: float
    reference: dict[str, Any]
    plain: str
    note: str = ""
    community_name: str | None = None
    modifiable: bool = False
    noise_sd: float = 0.0

    @property
    def weight_cap(self) -> float:
        return EVIDENCE_CAP[self.evidence_grade]

    @property
    def nominal_weight(self) -> float:
        """Tier gate only: A/B are eligible, C/D are not. The magnitude comes from `reliability()`."""
        return 1.0 if TIER_WEIGHT[self.reliability_tier] > 0 else 0.0

    def reliability(self, sex: str) -> float:
        """Attenuation factor r = var_true / (var_true + var_noise) = 1 / (1 + (noise_sd / pop_sd)^2).
        A metric measured to 2% CV but whose population spread is only 1.5% (symmetry) gets r ≈ 0.1;
        one measured to 2% with a 7% spread gets r ≈ 0.9. This is what 'reliable enough to score' means."""
        _, sd = self.ref(sex)
        if self.noise_sd <= 0:
            return 1.0
        return 1.0 / (1.0 + (self.noise_sd / sd) ** 2)

    @property
    def scorable(self) -> bool:
        return (
            self.direction != "none"
            and self.weight_cap > 0
            and self.nominal_weight > 0
            and self.unit != "category"
        )

    @property
    def weight(self) -> float:
        """Sex-independent part of the weight (evidence cap × tier gate). The scorer multiplies by reliability(sex)."""
        return self.nominal_weight * self.weight_cap if self.scorable else 0.0

    def weight_for(self, sex: str) -> float:
        return self.weight * self.reliability(sex)

    def ref(self, sex: str) -> tuple[float, float]:
        r = self.reference[sex]
        return float(r["mean"]), float(r["sd"])


@dataclass(frozen=True)
class Trigger:
    metric: str
    op: str | None = None
    value: float | None = None
    category: str | None = None
    min_confidence: float | None = None


@dataclass(frozen=True)
class Rule:
    id: str
    version: int
    triggers: tuple[Trigger, ...]
    goal_match: tuple[str, ...]
    safety_tier: int | str
    evidence_grade: str
    expected_timeline_weeks: tuple[int, int]
    effort: str
    impact_rank: int
    evidence_refs: tuple[str, ...]
    overlay: str | None
    excludes: tuple[str, ...]
    cadence: str
    time_cost_min: int
    opens_week: int
    task_title: str | None
    copy: dict[str, str]
    always_on: bool = False
    is_info_card: bool = False
    weekly_target: int | None = None

    @property
    def is_plan_eligible(self) -> bool:
        """Tier 1 and 2 enter the ranked plan; 3 and 4 go to the professional section; X never renders."""
        return self.safety_tier in (1, 2)

    @property
    def is_professional(self) -> bool:
        return self.safety_tier in (3, 4)


@dataclass
class Registry:
    metrics: dict[str, Metric]
    rules: dict[str, Rule]
    goals: dict[str, str]
    references: dict[str, dict[str, Any]]
    denylist_raw: dict[str, Any]
    metric_order: list[str] = field(default_factory=list)
    rule_order: list[str] = field(default_factory=list)
    versions: dict[str, int] = field(default_factory=dict)

    def validate(self) -> list[str]:
        errors: list[str] = []
        for m in self.metrics.values():
            if m.direction not in DIRECTIONS:
                errors.append(f"{m.id}: bad direction {m.direction}")
            if m.evidence_grade not in EVIDENCE_GRADES:
                errors.append(f"{m.id}: bad evidence grade {m.evidence_grade}")
            if m.reliability_tier not in TIER_WEIGHT:
                errors.append(f"{m.id}: bad reliability tier {m.reliability_tier}")
            for sex in SEXES:
                if sex not in m.reference:
                    errors.append(f"{m.id}: missing reference for {sex}")
                elif m.reference[sex]["sd"] <= 0:
                    errors.append(f"{m.id}: non-positive sd for {sex}")
            src = m.reference.get("source")
            if src not in self.references and src != "n/a":
                errors.append(f"{m.id}: unknown reference source {src!r}")
            if m.evidence_grade == "community" and self.references.get(src, {}).get("kind") not in ("community", None):
                errors.append(f"{m.id}: community grade must cite a community source")
        rule_ids = set(self.rules)
        for r in self.rules.values():
            if r.safety_tier not in SAFETY_TIERS:
                errors.append(f"{r.id}: bad safety tier {r.safety_tier}")
            if r.evidence_grade not in EVIDENCE_GRADES:
                errors.append(f"{r.id}: bad evidence grade")
            for t in r.triggers:
                if t.metric not in self.metrics:
                    errors.append(f"{r.id}: trigger on unknown metric {t.metric}")
                if (t.op is None) == (t.category is None):
                    errors.append(f"{r.id}: trigger must have exactly one of op/category")
            for g in r.goal_match:
                if g not in self.goals:
                    errors.append(f"{r.id}: unknown goal {g}")
            for x in r.excludes:
                if x not in rule_ids:
                    errors.append(f"{r.id}: excludes unknown rule {x}")
            for ref in r.evidence_refs:
                if ref not in self.references:
                    errors.append(f"{r.id}: unknown evidence ref {ref}")
            if r.safety_tier == "X" and r.goal_match:
                errors.append(f"{r.id}: tier X rule must have no goal match")
            if r.is_plan_eligible and r.cadence == "daily" and r.task_title is None and not r.is_info_card:
                errors.append(f"{r.id}: daily plan rule needs a task_title")
            if r.cadence == "weekly" and not r.weekly_target:
                errors.append(f"{r.id}: weekly rule needs weekly_target")
            if not r.triggers and not r.always_on:
                errors.append(f"{r.id}: rule with no triggers must be always_on")
            if r.is_professional and r.task_title is not None:
                errors.append(f"{r.id}: tier 3/4 rules never become tasks")
            for k in ("headline", "body", "why_this"):
                if k not in r.copy:
                    errors.append(f"{r.id}: copy missing {k}")
        return errors


def _load(name: str) -> dict[str, Any]:
    with open(DATA_DIR / name, encoding="utf-8") as f:
        return json.load(f)


def load_registry(data_dir: Path | None = None) -> Registry:
    global DATA_DIR
    if data_dir is not None:
        DATA_DIR = Path(data_dir)
    metrics_json = _load("metrics.json")
    rules_json = _load("rules.json")
    refs_json = _load("references.json")
    deny_json = _load("denylist.json")

    metrics: dict[str, Metric] = {}
    for m in metrics_json["metrics"]:
        metrics[m["id"]] = Metric(
            id=m["id"], name=m["name"], short=m["short"], unit=m["unit"], pose=m["pose"],
            direction=m["direction"], evidence_grade=m["evidence_grade"],
            reliability_tier=m["reliability_tier"], confidence_floor=float(m["confidence_floor"]),
            reference=m["reference"], plain=m["plain"], note=m.get("note", ""),
            community_name=m.get("community_name"), modifiable=bool(m.get("modifiable", False)),
            noise_sd=float(m.get("noise_sd", 0.0)),
        )

    rules: dict[str, Rule] = {}
    for r in rules_json["rules"]:
        trig = tuple(
            Trigger(metric=t["metric"], op=t.get("op"), value=t.get("value"),
                    category=t.get("category"), min_confidence=t.get("min_confidence"))
            for t in r.get("triggers", [])
        )
        rules[r["id"]] = Rule(
            id=r["id"], version=int(r["version"]), triggers=trig,
            goal_match=tuple(r.get("goal_match", [])), safety_tier=r["safety_tier"],
            evidence_grade=r["evidence_grade"],
            expected_timeline_weeks=tuple(r["expected_timeline_weeks"]),  # type: ignore[arg-type]
            effort=r["effort"], impact_rank=int(r["impact_rank"]),
            evidence_refs=tuple(r.get("evidence_refs", [])), overlay=r.get("overlay"),
            excludes=tuple(r.get("excludes", [])), cadence=r["cadence"],
            time_cost_min=int(r.get("time_cost_min", 0)), opens_week=int(r.get("opens_week", 1)),
            task_title=r.get("task_title"), copy=r["copy"], always_on=bool(r.get("always_on", False)),
            is_info_card=bool(r.get("is_info_card", False)), weekly_target=r.get("weekly_target"),
        )

    reg = Registry(
        metrics=metrics, rules=rules,
        goals={g["id"]: g["label"] for g in rules_json["goals"]},
        references=refs_json["refs"], denylist_raw=deny_json,
        metric_order=[m["id"] for m in metrics_json["metrics"]],
        rule_order=[r["id"] for r in rules_json["rules"]],
        versions={"metrics": metrics_json["$schema_version"], "rules": rules_json["$schema_version"]},
    )
    errors = reg.validate()
    if errors:
        raise ValueError("Registry validation failed:\n  " + "\n  ".join(errors))
    return reg
