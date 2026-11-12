from mogcore.scoring import score, ScoreInput
from mogcore.planner import build_plan, PlanInput, PLAN_MIN, PLAN_MAX
from .conftest import typical_readings


def _plan(reg, goals, minutes=15, **overrides):
    rd = typical_readings(reg, **overrides)
    s = score(ScoreInput("male", "18-24", rd), reg)
    return build_plan(PlanInput(tuple(goals), minutes, s), reg), s


def test_plan_size_bounds(reg):
    for goals in (["general"], ["sharper_jawline", "better_skin"], ["better_photos"]):
        p, _ = _plan(reg, goals)
        assert PLAN_MIN <= len(p.plan) <= PLAN_MAX, goals


def test_tier_x_never_appears(reg):
    # bigonial low fires the tier-X placeholder's trigger; it must never surface anywhere
    p, _ = _plan(reg, ["sharper_jawline"], bigonial_to_bizygomatic=-2.0, beard_presence=0)
    everything = [c.rule_id for c in p.plan + p.professional + p.info]
    assert "jaw_exercise_devices" not in everything
    assert "jaw_exercise_devices" not in {t.rule_id for t in p.tasks}


def test_adiposity_rule_excludes_the_weaker_duplicate(reg):
    p, _ = _plan(reg, ["sharper_jawline"], facial_adiposity=1.8, cervicomental_angle_deg=2.0)
    ids = [c.rule_id for c in p.plan]
    assert "adiposity_high_cervicomental_obtuse" in ids
    assert "adiposity_moderate_general" not in ids
    assert p.excluded_by["adiposity_moderate_general"] == "adiposity_high_cervicomental_obtuse"


def test_professional_section_is_separate_from_plan(reg):
    p, _ = _plan(reg, ["hair"], hairline_stage=4)
    assert "hairline_recession_referral" in [c.rule_id for c in p.professional]
    assert "hairline_recession_referral" not in [c.rule_id for c in p.plan]
    assert all(c.safety_tier in (1, 2) for c in p.plan)
    assert all(c.safety_tier in (3, 4) for c in p.professional)


def test_professional_cards_never_create_tasks(reg):
    p, _ = _plan(reg, ["sharper_jawline", "general"], chin_projection_eline_mm=-3.0, facial_convexity_deg=-2.5)
    pro_ids = {c.rule_id for c in p.professional}
    assert pro_ids
    assert not pro_ids & {t.rule_id for t in p.tasks}


def test_mewing_myth_card_is_info_not_plan(reg):
    p, _ = _plan(reg, ["sharper_jawline"], facial_convexity_deg=-1.5)
    assert "mewing_myth" in [c.rule_id for c in p.info]
    assert "mewing_myth" not in [c.rule_id for c in p.plan]


def test_goal_match_gates_rules(reg):
    p, _ = _plan(reg, ["better_photos"])
    ids = [c.rule_id for c in p.plan]
    assert "photo_distance_lens" in ids
    assert "adiposity_moderate_general" not in ids


def test_each_card_carries_its_findings(reg):
    p, _ = _plan(reg, ["better_skin"], skin_evenness=-1.6)
    card = next(c for c in p.plan if c.rule_id == "skin_evenness_low_cleanse_moisturise")
    assert card.finding_refs == ["skin_evenness"]


def test_time_budget_respected_beyond_minimum(reg):
    p5, _ = _plan(reg, ["sharper_jawline", "better_skin"], minutes=5, facial_adiposity=1.8, skin_evenness=-1.6)
    p30, _ = _plan(reg, ["sharper_jawline", "better_skin"], minutes=30, facial_adiposity=1.8, skin_evenness=-1.6)
    assert p5.daily_minutes <= max(5, p5.daily_minutes if len(p5.plan) == PLAN_MIN else 5)
    assert len(p30.plan) >= len(p5.plan)


def test_week_one_is_not_overwhelming(reg):
    p, _ = _plan(reg, ["sharper_jawline", "better_skin"], facial_adiposity=1.8, skin_evenness=-1.6)
    week1_daily = [t for t in p.tasks if t.cadence == "daily" and t.opens_week == 1]
    assert 1 <= len(week1_daily) <= 4


def test_plan_is_deterministic(reg):
    a, _ = _plan(reg, ["general"], facial_adiposity=1.1)
    b, _ = _plan(reg, ["general"], facial_adiposity=1.1)
    assert a.to_dict() == b.to_dict()


def test_every_goal_produces_a_plan_for_a_typical_face(reg):
    for g in reg.goals:
        p, _ = _plan(reg, [g])
        assert len(p.plan) >= PLAN_MIN, g
        assert any(t.cadence == "daily" for t in p.tasks), f"{g}: a plan needs at least one daily task or the streak has nothing to count"
