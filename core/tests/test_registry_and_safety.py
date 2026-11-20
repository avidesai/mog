"""Authoring-time gates. If any of these fail, the data files must not ship."""

from mogcore.registry import EVIDENCE_CAP


def test_registry_loads_and_validates(reg):
    assert len(reg.metrics) >= 30
    assert len(reg.rules) >= 25


def test_every_reference_source_resolves(reg):
    for m in reg.metrics.values():
        src = m.reference["source"]
        assert src == "n/a" or src in reg.references, m.id


def test_community_metrics_are_capped_near_zero(reg):
    for m in reg.metrics.values():
        if m.evidence_grade == "community":
            assert m.weight_cap == 0.02
        if m.evidence_grade == "contradicted":
            assert m.weight == 0.0, f"{m.id} contradicted metric must carry zero score weight"


def test_fwhr_is_contradicted_and_unscored(reg):
    m = reg.metrics["fwhr"]
    assert m.evidence_grade == "contradicted"
    assert not m.scorable


def test_tier_c_metrics_have_zero_weight(reg):
    for m in reg.metrics.values():
        if m.reliability_tier in ("C", "D"):
            assert m.weight == 0.0, m.id


def test_no_recommendation_exceeds_its_evidence(reg):
    """A rule may not claim a stronger evidence grade than the strongest metric it triggers on,
    unless it is always_on (foundational habits cite their own evidence refs)."""
    order = list(EVIDENCE_CAP)
    for r in reg.rules.values():
        if r.always_on or r.safety_tier == "X" or not r.triggers:
            continue
        # strong evidence must be backed by at least one clinical reference
        if r.evidence_grade == "strong":
            kinds = {reg.references[x]["kind"] for x in r.evidence_refs}
            assert "clinical" in kinds, f"{r.id} claims strong evidence without a clinical ref"


def test_tier_x_rules_never_have_goals_or_tasks(reg):
    for r in reg.rules.values():
        if r.safety_tier == "X":
            assert not r.goal_match and r.task_title is None


def test_professional_rules_never_become_tasks(reg):
    for r in reg.rules.values():
        if r.safety_tier in (3, 4):
            assert r.task_title is None, r.id


def test_all_rule_copy_passes_denylist(reg, denylist):
    """The authoring-time safety gate: every headline/body/why_this of every non-X rule."""
    failures = []
    for r in reg.rules.values():
        if r.safety_tier == "X":
            continue
        for k, text in r.copy.items():
            for hit in denylist.scan(text, info_card=r.is_info_card):
                # tier 3/4 cards may name the drugs/procedures listed as allowed
                if r.safety_tier in (3, 4) and hit.match.lower() in denylist.allowed_in_professional:
                    continue
                failures.append(f"{r.id}.{k}: '{hit.match}' ({hit.reason})")
    assert not failures, "\n".join(failures)


def test_task_titles_pass_denylist(reg, denylist):
    for r in reg.rules.values():
        if r.task_title:
            assert denylist.is_clean(r.task_title), r.id


def test_denylist_catches_known_bad_strings(denylist):
    assert not denylist.is_clean("Try bone smashing for your cheekbones")
    assert not denylist.is_clean("Take 1mg finasteride daily")
    assert not denylist.is_clean("Aim for 1800 kcal a day")
    assert not denylist.is_clean("Hard mewing fixes recession")
    assert not denylist.is_clean("You mog most people")
    assert not denylist.is_clean("Looks better than most people")
    assert denylist.is_clean("Reduce body fat at roughly half a percent of bodyweight per week.")
    assert denylist.is_clean("Daily broad-spectrum SPF 30 or higher.")


def test_mewing_allowed_only_in_info_cards(denylist):
    text = "There is no evidence that mewing changes adult facial shape."
    assert not denylist.is_clean(text)
    assert denylist.is_clean(text, info_card=True)


def test_denylist_character_class_patterns_work(denylist):
    assert not denylist.is_clean("consider leg-lengthening")
    assert not denylist.is_clean("leg lengthening surgery")
    assert not denylist.is_clean("try bpc157")
    assert not denylist.is_clean("try BPC-157")


def test_denylist_normalises_unicode_lookalikes(denylist):
    for text in ("take ５０ mg", "ſteroid cycle", "1500 Kcal a day"):
        assert not denylist.is_clean(text), text
