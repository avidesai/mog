"""Recommendation engine: rules table → ranked plan + professional section.

Selection (eng doc, "Selection and ranking"):
    collect fired rules → filter by goal match and safety tier → de-duplicate
    via `excludes` → rank by impact × evidence × goal weight with an effort
    penalty → top N become the plan. Tier 3/4 never enter the ranked list.
    Tier X is never emitted under any circumstances (checked twice).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from .registry import Registry, Rule, Trigger, EVIDENCE_CAP
from .scoring import ScoreResult, MetricResult

PLAN_MIN = 3
PLAN_MAX = 6
EFFORT_PENALTY = {"low": 0.0, "medium": 0.10, "high": 0.20}
# A goal the user picked first weighs more than later picks; unpicked goals get
# a small floor so 'general' plans still get the foundational habits.
GOAL_WEIGHT_BY_RANK = (1.0, 0.85, 0.7)
GOAL_WEIGHT_UNPICKED = 0.25
TIME_BUDGET_MIN = {"5": 5, "15": 15, "30": 30}  # onboarding "time budget" answer → minutes/day


@dataclass(frozen=True)
class PlanInput:
    goals: tuple[str, ...]          # ordered as the user picked them; "general" alone is valid
    time_budget_min: int            # minutes per day the user said they have
    score: ScoreResult


@dataclass
class PlanCard:
    rule_id: str
    headline: str
    body: str
    why_this: str
    safety_tier: int | str
    evidence_grade: str
    effort: str
    timeline_weeks: tuple[int, int]
    finding_refs: list[str]        # metric ids that fired
    overlay: str | None
    is_info_card: bool
    rank_score: float


@dataclass
class PlanTask:
    task_id: str
    rule_id: str
    title: str
    cadence: str                   # daily / weekly / once
    weekly_target: int | None
    opens_week: int
    time_cost_min: int
    sort_rank: int
    finding_refs: list[str]


@dataclass
class PlanResult:
    plan: list[PlanCard]
    professional: list[PlanCard]
    info: list[PlanCard]
    tasks: list[PlanTask]
    excluded_by: dict[str, str] = field(default_factory=dict)   # rule → excluded by which rule
    daily_minutes: int = 0

    def to_dict(self) -> dict[str, Any]:
        return {
            "plan": [c.rule_id for c in self.plan],
            "professional": [c.rule_id for c in self.professional],
            "info": [c.rule_id for c in self.info],
            "tasks": [{"id": t.task_id, "rule": t.rule_id, "cadence": t.cadence, "opens_week": t.opens_week} for t in self.tasks],
            "excluded_by": self.excluded_by,
            "daily_minutes": self.daily_minutes,
        }


def _metric_by_id(score: ScoreResult) -> dict[str, MetricResult]:
    return {m.id: m for m in score.metrics}


def _trigger_fires(t: Trigger, metrics: dict[str, MetricResult], reg: Registry) -> bool:
    m = metrics.get(t.metric)
    if m is None or m.value is None or m.z is None:
        return False
    floor = t.min_confidence if t.min_confidence is not None else reg.metrics[t.metric].confidence_floor
    if m.confidence is None or not (m.confidence >= floor):
        return False
    if t.category is not None:
        return m.category == t.category
    v, x = m.value, float(t.value)  # type: ignore[arg-type]
    return {
        ">": v > x, ">=": v >= x, "<": v < x, "<=": v <= x, "==": v == x, "!=": v != x,
    }[t.op]  # type: ignore[index]


def _goal_weight(rule: Rule, goals: tuple[str, ...]) -> float:
    best = 0.0
    for i, g in enumerate(goals):
        if g in rule.goal_match:
            best = max(best, GOAL_WEIGHT_BY_RANK[min(i, len(GOAL_WEIGHT_BY_RANK) - 1)])
    if best == 0.0 and rule.goal_match:
        best = GOAL_WEIGHT_UNPICKED
    return best


def _rank(rule: Rule, goal_w: float) -> float:
    impact = 1.0 / rule.impact_rank
    evidence = EVIDENCE_CAP[rule.evidence_grade] if rule.evidence_grade != "contradicted" else 0.0
    return impact * (0.3 + evidence) * goal_w * (1.0 - EFFORT_PENALTY[rule.effort])


def _card(rule: Rule, refs: list[str], rank: float) -> PlanCard:
    return PlanCard(
        rule_id=rule.id, headline=rule.copy["headline"], body=rule.copy["body"], why_this=rule.copy["why_this"],
        safety_tier=rule.safety_tier, evidence_grade=rule.evidence_grade, effort=rule.effort,
        timeline_weeks=rule.expected_timeline_weeks, finding_refs=refs, overlay=rule.overlay,
        is_info_card=rule.is_info_card, rank_score=rank,
    )


def build_plan(inp: PlanInput, reg: Registry) -> PlanResult:
    goals = inp.goals or ("general",)
    for g in goals:
        if g not in reg.goals:
            raise ValueError(f"unknown goal {g}")
    metrics = _metric_by_id(inp.score)

    fired: list[tuple[Rule, list[str]]] = []
    for rid in reg.rule_order:
        rule = reg.rules[rid]
        if rule.safety_tier == "X":
            continue  # first check: tier X never fires
        # every rule, always_on included, must match at least one chosen goal
        if not any(g in rule.goal_match for g in goals):
            continue
        if rule.always_on and not rule.triggers:
            fired.append((rule, []))
            continue
        if rule.triggers and all(_trigger_fires(t, metrics, reg) for t in rule.triggers):
            fired.append((rule, [t.metric for t in rule.triggers]))

    # excludes: a fired rule suppresses the rules it names
    excluded_by: dict[str, str] = {}
    fired_ids = {r.id for r, _ in fired}
    for rule, _ in fired:
        for x in rule.excludes:
            if x in fired_ids and x not in excluded_by:
                excluded_by[x] = rule.id
    fired = [(r, refs) for r, refs in fired if r.id not in excluded_by]

    plan_cands: list[PlanCard] = []
    professional: list[PlanCard] = []
    info: list[PlanCard] = []
    for rule, refs in fired:
        if rule.safety_tier == "X":
            raise AssertionError("tier X reached ranking")  # second check
        card = _card(rule, refs, _rank(rule, _goal_weight(rule, goals)))
        if rule.is_professional:
            professional.append(card)
        elif rule.is_info_card:
            info.append(card)
        else:
            plan_cands.append(card)

    plan_cands.sort(key=lambda c: (-c.rank_score, c.rule_id))
    professional.sort(key=lambda c: (-c.rank_score, c.rule_id))
    info.sort(key=lambda c: (-c.rank_score, c.rule_id))

    # fit to time budget: take in rank order while daily minutes fit; always take at least PLAN_MIN
    plan: list[PlanCard] = []
    daily_minutes = 0
    for c in plan_cands:
        rule = reg.rules[c.rule_id]
        cost = rule.time_cost_min if rule.cadence == "daily" else 0
        if len(plan) >= PLAN_MAX:
            break
        if len(plan) >= PLAN_MIN and daily_minutes + cost > inp.time_budget_min:
            continue
        plan.append(c)
        daily_minutes += cost

    tasks: list[PlanTask] = []
    for i, c in enumerate(plan):
        rule = reg.rules[c.rule_id]
        if rule.task_title is None:
            continue
        tasks.append(PlanTask(
            task_id=f"task_{rule.id}", rule_id=rule.id, title=rule.task_title, cadence=rule.cadence,
            weekly_target=rule.weekly_target, opens_week=rule.opens_week, time_cost_min=rule.time_cost_min,
            sort_rank=i, finding_refs=c.finding_refs,
        ))

    return PlanResult(plan=plan, professional=professional, info=info, tasks=tasks,
                      excluded_by=excluded_by, daily_minutes=daily_minutes)
