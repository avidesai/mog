import json
from pathlib import Path

COPY = Path(__file__).resolve().parent.parent / "copy" / "strings.json"


def _walk(d, prefix=""):
    for k, v in d.items():
        if k.startswith("$"):
            continue
        if isinstance(v, dict):
            yield from _walk(v, f"{prefix}{k}.")
        else:
            yield f"{prefix}{k}", v


def test_all_ui_strings_pass_denylist(denylist):
    with open(COPY, encoding="utf-8") as f:
        strings = json.load(f)
    failures = []
    for key, text in _walk(strings):
        info = key.startswith("metric_detail.fwhr") or key.startswith("methodology")
        for hit in denylist.scan(text, info_card=info):
            failures.append(f"{key}: '{hit.match}' ({hit.reason})")
    assert not failures, "\n".join(failures)


def test_no_exclamation_marks_or_your_score_is():
    with open(COPY, encoding="utf-8") as f:
        strings = json.load(f)
    for key, text in _walk(strings):
        assert "!" not in text, key
        assert "your score is" not in text.lower(), key
        assert "unlock your" not in text.lower(), key


def test_evidence_badge_strings_are_exact():
    with open(COPY, encoding="utf-8") as f:
        c = json.load(f)["common"]
    assert c["evidence_strong"] == "Well supported by research"
    assert c["evidence_moderate"] == "Reasonable support"
    assert c["evidence_weak"] == "Limited evidence"
    assert c["evidence_community"] == "Community metric, little evidence"
    assert c["evidence_contradicted"] == "Research points the other way"
