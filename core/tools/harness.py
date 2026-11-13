"""Week-9 consistency harness + fairness smoke (eng doc, "Consistency harness", "Fairness").

Layout:  captures/<person>/<session>/capture_N.json   (same files the Landmark dump writes)
         captures/people.json  = {"<person>": {"sex": "male"|"female", "tone": "I-II"|"III-IV"|"V-VI"}}

Per person:   score SD across all captures (the release gate: median ≤ 0.60, no person above 1.0),
              per-metric between-session CV (reuses cv_analysis), suppression rate per metric.
Per stratum:  by sex and by skin-tone group — mean score, mean skin_evenness, mean facial_adiposity,
              suppression rate. The smoke test flags a stratum whose mean skin_evenness differs from the
              pooled mean by more than 0.08, or whose suppression rate for any metric exceeds the pooled
              rate by more than 15 points. Those are the two ways the cheap appearance head could be
              unfair: a tone-dependent index, or a tone-dependent failure to measure.

This cannot prove fairness. Person-to-person variation in skin evenness is large (SD ≈ 0.12), so
with 4–6 testers per tone group the smoke only detects gross bias (≳ 0.15–0.2). It can catch the
obvious, it says when a stratum is too small to conclude anything, and it writes down what it saw.

Usage:  python core/tools/harness.py captures/ [--write-tiers]
        python core/tools/harness.py --selftest
"""

from __future__ import annotations

import argparse
import json
import statistics as st
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT)); sys.path.insert(0, str(ROOT / "tools"))
from mogcore import load_registry  # noqa: E402
from mogcore.scoring import score, ScoreInput, MetricReading  # noqa: E402
from cv_analysis import analyse, report, write_tiers  # noqa: E402

SCORE_SD_GATE = 0.60   # measured-noise gate (12 Nov revision); 1.2 under the provisional noise table
TONE_EVENNESS_FLAG = 0.08
SUPPRESSION_FLAG_PTS = 15.0


def load(root: Path) -> tuple[dict[str, dict[str, list[dict]]], dict[str, dict]]:
    people_meta = json.loads((root / "people.json").read_text()) if (root / "people.json").exists() else {}
    people: dict[str, dict[str, list[dict]]] = defaultdict(lambda: defaultdict(list))
    for f in sorted(root.rglob("capture_*.json")):
        rel = f.relative_to(root).parts
        person = rel[0] if len(rel) >= 3 else "person"
        session = rel[1] if len(rel) >= 3 else f.parent.name
        people[person][session].append(json.loads(f.read_text()))
    return people, people_meta


def run(people, meta, reg):
    out = {"people": {}, "strata": {}, "flags": []}
    pooled_scores, pooled_even, pooled_adip = [], [], []
    pooled_supp: dict[str, list[int]] = defaultdict(list)
    per_stratum = defaultdict(lambda: {"scores": [], "even": [], "adip": [], "supp": defaultdict(list)})

    for person, sessions in people.items():
        sex = meta.get(person, {}).get("sex", "male")
        tone = meta.get(person, {}).get("tone", "unknown")
        scores, even, adip = [], [], []
        supp: dict[str, list[int]] = defaultdict(list)
        for caps in sessions.values():
            for c in caps:
                rd = {k: MetricReading(v["value"], v.get("confidence", 0.9), v.get("iqr", 0.0)) for k, v in c["readings"].items()}
                try:
                    r = score(ScoreInput(sex, "18-24", rd), reg)
                except Exception:
                    continue
                scores.append(r.score)
                for m in r.metrics:
                    supp[m.id].append(1 if m.display == "suppressed" else 0)
                if "skin_evenness" in c["readings"]: even.append(c["readings"]["skin_evenness"]["value"])
                if "facial_adiposity" in c["readings"]: adip.append(c["readings"]["facial_adiposity"]["value"])
        res, _ = analyse(sessions, reg, sex)
        sd = st.pstdev(scores) if len(scores) >= 2 else float("nan")
        ab = sum(1 for r in res.values() if r["tier"] in ("A", "B"))
        out["people"][person] = {"sex": sex, "tone": tone, "n_captures": len(scores), "score_mean": st.mean(scores) if scores else None,
                                 "score_sd": sd, "tier_ab": ab, "metrics": res}
        if sd == sd and sd > SCORE_SD_GATE:
            out["flags"].append(f"{person}: score SD {sd:.3f} > {SCORE_SD_GATE} (release gate)")
        pooled_scores += scores; pooled_even += even; pooled_adip += adip
        for k, v in supp.items(): pooled_supp[k] += v
        for key in (("sex", sex), ("tone", tone)):
            s = per_stratum[key]; s["scores"] += scores; s["adip"] += adip
            if even: s["even"].append(st.mean(even))          # one value per PERSON, so one person cannot dominate
            s.setdefault("people", 0); s["people"] += 1
            for k, v in supp.items(): s["supp"][k] += v

    pe = st.mean(pooled_even) if pooled_even else None
    psupp = {k: 100 * st.mean(v) for k, v in pooled_supp.items() if v}
    tone_means = {k[1]: st.mean(v["even"]) for k, v in per_stratum.items() if k[0] == "tone" and v["even"] and v.get("people", 0) >= 2}
    for key, s in per_stratum.items():
        row = {"n": len(s["scores"]), "people": s.get("people", 0), "score_mean": st.mean(s["scores"]) if s["scores"] else None,
               "skin_evenness_mean": st.mean(s["even"]) if s["even"] else None,
               "adiposity_mean": st.mean(s["adip"]) if s["adip"] else None,
               "suppression_pct": {k: 100 * st.mean(v) for k, v in s["supp"].items() if v}}
        out["strata"][f"{key[0]}={key[1]}"] = row
        # tone smoke: this stratum's person-level mean vs the mean of the OTHER tone strata (≥2 people each)
        if key[0] == "tone" and key[1] in tone_means and len(tone_means) >= 2:
            centre = st.median(tone_means.values())      # robust: one biased stratum does not drag the comparison
            delta = tone_means[key[1]] - centre
            if abs(delta) > TONE_EVENNESS_FLAG:
                power = "" if s.get("people", 0) >= 5 else f" [only {s.get('people', 0)} people in this stratum — low power; recruit more before concluding]"
                out["flags"].append(f"tone={key[1]}: mean skin_evenness {tone_means[key[1]]:.3f} vs the median tone stratum {centre:.3f} (Δ {delta:+.3f} > {TONE_EVENNESS_FLAG}) — check the luma gate floor / the index, not the people{power}")
        for k, pct in row["suppression_pct"].items():
            if k in psupp and pct - psupp[k] > SUPPRESSION_FLAG_PTS:
                out["flags"].append(f"{key[0]}={key[1]}: {k} suppressed {pct:.0f}% vs pooled {psupp[k]:.0f}%")
    out["pooled"] = {"n": len(pooled_scores), "score_sd_pooled": st.pstdev(pooled_scores) if len(pooled_scores) >= 2 else None, "skin_evenness_mean": pe}
    return out


def print_report(out) -> None:
    print(f"{'person':14s} {'sex':6s} {'tone':7s} {'n':>3s} {'score':>6s} {'SD':>6s} {'A/B':>4s}")
    for p, r in out["people"].items():
        print(f"{p:14s} {r['sex']:6s} {r['tone']:7s} {r['n_captures']:3d} {r['score_mean'] or 0:6.2f} {r['score_sd']:6.3f} {r['tier_ab']:4d}")
    print("\nstrata:")
    for k, r in out["strata"].items():
        ev = f"{r['skin_evenness_mean']:.3f}" if r["skin_evenness_mean"] is not None else "   -  "
        print(f"  {k:14s} n={r['n']:3d} score {r['score_mean'] or 0:5.2f}  skin_evenness {ev}")
    print("\nflags:" if out["flags"] else "\nno flags.")
    for f in out["flags"]: print("  !", f)
    worst = max((r["score_sd"] for r in out["people"].values() if r["score_sd"] == r["score_sd"]), default=float("nan"))
    print(f"\nworst per-person score SD {worst:.3f} — gate {SCORE_SD_GATE}: {'PASS' if worst <= SCORE_SD_GATE else 'FAIL'}")


def selftest() -> None:
    import random
    rng = random.Random(4)
    reg = load_registry()
    people, meta = {}, {}
    # 6 people per tone group and a gross planted bias (−0.25): the smoke has little power below that
    # with the handful of testers week 9 will have, and the self-test should not pretend otherwise.
    plan = [(sex, tone, shift) for tone, shift in (("I-II", 0), ("III-IV", 0), ("V-VI", -0.25)) for sex in ("male", "female", "male", "female", "male", "female")]
    for i, (sex, tone, even_shift) in enumerate(plan):
        pid = f"p{i}"; meta[pid] = {"sex": sex, "tone": tone}
        base = {m.id: rng.gauss(0, 1) for m in reg.metrics.values() if m.unit != "category"}
        sessions = {}
        for s in range(3):
            caps = []
            for c in range(6):
                readings = {}
                for m in reg.metrics.values():
                    if m.unit == "category":
                        readings[m.id] = {"value": 1.0 if m.id == "hairline_stage" else 0.0, "confidence": 0.9, "iqr": 0}; continue
                    mean, sd = m.ref(sex)
                    z = base[m.id] + rng.gauss(0, 0.08)
                    v = mean + z * sd
                    if m.id == "skin_evenness": v = min(1, max(0, v + even_shift))   # the planted tone bias
                    readings[m.id] = {"value": v, "confidence": 0.9, "iqr": 0.05 * sd}
                caps.append({"session": f"s{s}", "capture": c, "frames": [], "readings": readings})
            sessions[f"s{s}"] = caps
        people[pid] = sessions
    out = run(people, meta, reg)
    print_report(out)
    assert any("tone=V-VI" in f and "skin_evenness" in f for f in out["flags"]), "planted tone bias not flagged"
    assert all(r["score_sd"] < 1.5 for r in out["people"].values())
    assert not any("tone=I-II" in f and "skin_evenness" in f for f in out["flags"]), "unbiased stratum flagged"
    print("selftest ok")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("captures", nargs="?"); ap.add_argument("--selftest", action="store_true"); ap.add_argument("--write-tiers", action="store_true")
    ap.add_argument("--json", help="write the full report here")
    a = ap.parse_args()
    if a.selftest: selftest(); return
    if not a.captures: ap.error("captures folder required")
    reg = load_registry()
    people, meta = load(Path(a.captures))
    out = run(people, meta, reg)
    print_report(out)
    if a.json: Path(a.json).write_text(json.dumps(out, indent=1, default=str))
    if a.write_tiers:
        # tiers from the pooled per-metric analysis across all people
        merged = {f"{p}/{s}": caps for p, sess in people.items() for s, caps in sess.items()}
        res, _ = analyse(merged, reg, "male")
        write_tiers(res)


if __name__ == "__main__":
    main()
