"""Command line: run the whole deterministic pipeline on a readings JSON.

    python -m mogcore.cli score  fixtures/example_scan.json
    python -m mogcore.cli plan   fixtures/example_scan.json --goals sharper_jawline better_skin --minutes 15
    python -m mogcore.cli check  "some generated text to scan against the denylist"
    python -m mogcore.cli catalog

The readings JSON shape is the same as a fixture case:
    {"sex": "male", "age_band": "18-24", "profile_captured": true,
     "readings": {"canthal_tilt_deg": {"value": 5.1, "confidence": 0.91, "iqr": 0.3}, ...}}
"""

from __future__ import annotations

import argparse
import json
import sys

from . import load_registry, Denylist
from .scoring import score, ScoreInput, MetricReading
from .planner import build_plan, PlanInput
from .registry import EVIDENCE_CAP

BADGE = {
    "strong": "Well supported by research", "moderate": "Reasonable support", "weak": "Limited evidence",
    "community": "Community metric, little evidence", "contradicted": "Research points the other way",
}


def _load_scan(path: str) -> ScoreInput:
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    rd = {k: MetricReading(**{kk: vv for kk, vv in v.items() if kk in ("value", "confidence", "iqr", "occluded")})
          for k, v in d["readings"].items()}
    return ScoreInput(d["sex"], d["age_band"], rd, d.get("profile_captured", True))


def cmd_score(args: argparse.Namespace) -> None:
    reg = load_registry()
    inp = _load_scan(args.scan)
    sex = inp.sex
    r = score(inp, reg)
    if args.json:
        print(json.dumps(r.to_dict(), indent=1))
        return
    print(f"{r.score:.1f}  ·  likely {r.score_low:.1f}–{r.score_high:.1f}  ·  {r.tier}")
    print(f"{r.tier_long} · roughly the {r.percentile:.0f}th percentile of the {sex} reference distribution")
    print(f"model {r.model_version} · {r.n_scored} metrics scored\n")
    for m in r.metrics:
        meta = reg.metrics[m.id]
        if m.display == "suppressed":
            print(f"  {meta.short:22s} —  suppressed: {m.suppressed_reason}")
            continue
        val = f"{m.value:.3g}{'°' if meta.unit == 'deg' else ''}"
        if m.display == "category":
            val = f"{m.category}"
        line = f"  {meta.short:22s} {val:>10s}   typical {meta.ref(sex)[0]:.3g}±{meta.ref(sex)[1]:.2g}   [{BADGE[meta.evidence_grade]}]"
        print(line)
    print(f"\n  top strength: {r.top_strength}\n  most improvable: {r.most_improvable}")


def cmd_plan(args: argparse.Namespace) -> None:
    reg = load_registry()
    s = score(_load_scan(args.scan), reg)
    p = build_plan(PlanInput(tuple(args.goals), args.minutes, s), reg)
    if args.json:
        print(json.dumps(p.to_dict(), indent=1))
        return
    print(f"Plan ({len(p.plan)} cards, {p.daily_minutes} min/day)\n")
    for i, c in enumerate(p.plan, 1):
        print(f"{i}. {c.headline}   [{BADGE[c.evidence_grade]} · {c.effort} effort · {c.timeline_weeks[0]}–{c.timeline_weeks[1]} wks]")
        print(f"   {c.body}")
        print(f"   Why this: {c.why_this}")
        if c.finding_refs:
            print(f"   Based on: {', '.join(c.finding_refs)}")
        print()
    if p.info:
        print("Worth knowing\n")
        for c in p.info:
            print(f"· {c.headline}\n  {c.body}\n")
    if p.professional:
        print("To discuss with a professional\n")
        for c in p.professional:
            print(f"· {c.headline}  (tier {c.safety_tier})\n  {c.body}\n")
    print("Daily tasks:")
    for t in p.tasks:
        print(f"  [{t.cadence:6s} wk{t.opens_week}] {t.title}")
    if p.excluded_by:
        print(f"\nexcluded: {p.excluded_by}")


def cmd_check(args: argparse.Namespace) -> None:
    reg = load_registry()
    hits = Denylist(reg.denylist_raw).scan(args.text, info_card=args.info)
    if not hits:
        print("clean")
        return
    for h in hits:
        print(f"HIT  '{h.match}'  ({h.reason})")
    sys.exit(1)


def cmd_catalog(args: argparse.Namespace) -> None:
    reg = load_registry()
    print(f"{'metric':32s} {'pose':8s} {'tier':4s} {'evidence':12s} {'weight':6s}")
    for mid in reg.metric_order:
        m = reg.metrics[mid]
        print(f"{mid:32s} {m.pose:8s} {m.reliability_tier:4s} {m.evidence_grade:12s} {m.weight:0.3f}")
    print(f"\n{len(reg.rules)} rules; tiers:", {t: sum(1 for r in reg.rules.values() if r.safety_tier == t) for t in (1, 2, 3, 4, 'X')})
    print("evidence caps:", EVIDENCE_CAP)


def main(argv: list[str] | None = None) -> None:
    ap = argparse.ArgumentParser(prog="mogcore")
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("score"); a.add_argument("scan"); a.add_argument("--json", action="store_true"); a.set_defaults(fn=cmd_score)
    b = sub.add_parser("plan"); b.add_argument("scan"); b.add_argument("--goals", nargs="+", default=["general"]); b.add_argument("--minutes", type=int, default=15); b.add_argument("--json", action="store_true"); b.set_defaults(fn=cmd_plan)
    c = sub.add_parser("check"); c.add_argument("text"); c.add_argument("--info", action="store_true"); c.set_defaults(fn=cmd_check)
    d = sub.add_parser("catalog"); d.set_defaults(fn=cmd_catalog)
    args = ap.parse_args(argv)
    args.fn(args)


if __name__ == "__main__":
    main()
