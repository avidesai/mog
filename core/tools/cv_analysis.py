"""Spike-1 analysis: landmark dumps → per-metric reliability.

Input: a folder tree of capture_N.json files written by the app's Landmark dump screen,
one subfolder per session (e.g. captures/s1/, captures/s2/, captures/s3/).

For every metric:
  within-session CV   = sd / |mean| of the aggregated reading across captures in one session, averaged over sessions
  between-session CV  = sd / |mean| of per-session means
  frame CV            = mean over captures of (sd / |mean|) across the 10 frames inside a capture
  provisional tier    = A if between-session CV ≤ 2%, B if ≤ 5%, C if ≤ 10%, D otherwise
                        (eng doc, "Reliability tiers"; angles use absolute SD in degrees instead: A ≤ 1°, B ≤ 2.5°, C ≤ 5°)

Also prints the score reliability if the readings can be scored: SD of the 0–10 score across all
captures of the same person (the release gate is ≤ 0.2).

Usage:
  python core/tools/cv_analysis.py path/to/captures [--sex male] [--write-tiers]
  python core/tools/cv_analysis.py --selftest
"""

from __future__ import annotations

import argparse
import json
import math
import statistics as st
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from mogcore import load_registry  # noqa: E402
from mogcore.scoring import score, ScoreInput, MetricReading  # noqa: E402

ANGLE_UNITS = {"deg"}


def tier_for(metric_unit: str, between_cv: float, between_sd: float) -> str:
    if metric_unit in ANGLE_UNITS or metric_unit == "mm":
        return "A" if between_sd <= 1.0 else "B" if between_sd <= 2.5 else "C" if between_sd <= 5.0 else "D"
    return "A" if between_cv <= 0.02 else "B" if between_cv <= 0.05 else "C" if between_cv <= 0.10 else "D"


def load_sessions(root: Path) -> dict[str, list[dict]]:
    sessions: dict[str, list[dict]] = {}
    for f in sorted(root.rglob("capture_*.json")):
        with open(f, encoding="utf-8") as fh:
            d = json.load(fh)
        sessions.setdefault(d.get("session", f.parent.name), []).append(d)
    return sessions


def analyse(sessions: dict[str, list[dict]], reg, sex: str) -> tuple[dict[str, dict], list[float]]:
    metrics = sorted({k for caps in sessions.values() for c in caps for k in c["readings"]})
    out: dict[str, dict] = {}
    for m in metrics:
        unit = reg.metrics[m].unit if m in reg.metrics else "ratio"
        within, session_means, frame_cvs = [], [], []
        for caps in sessions.values():
            vals = [c["readings"][m]["value"] for c in caps if m in c["readings"]]
            if len(vals) >= 2:
                mu = st.mean(vals)
                within.append(st.pstdev(vals) / abs(mu) if mu else float("nan"))
                session_means.append(mu)
            for c in caps:
                fv = [fr["metrics"][m] for fr in c.get("frames", []) if m in fr.get("metrics", {})]
                if len(fv) >= 3 and st.mean(fv):
                    frame_cvs.append(st.pstdev(fv) / abs(st.mean(fv)))
        if len(session_means) >= 2:
            bmu = st.mean(session_means)
            between_sd = st.pstdev(session_means)
            between_cv = between_sd / abs(bmu) if bmu else float("nan")
        else:
            between_sd = between_cv = float("nan")
        out[m] = {
            "unit": unit, "n_sessions": len(session_means),
            "within_cv": st.mean(within) if within else float("nan"),
            "between_cv": between_cv, "between_sd": between_sd,
            "frame_cv": st.mean(frame_cvs) if frame_cvs else float("nan"),
            "tier": tier_for(unit, between_cv, between_sd) if len(session_means) >= 2 else "?",
        }
    # score reliability across every capture
    scores = []
    for caps in sessions.values():
        for c in caps:
            rd = {k: MetricReading(value=v["value"], confidence=v.get("confidence", 0.9), iqr=v.get("iqr", 0.0)) for k, v in c["readings"].items()}
            try:
                scores.append(score(ScoreInput(sex, "18-24", rd), reg).score)
            except Exception:
                pass
    return out, scores


def report(res: dict[str, dict], scores: list[float], reg) -> None:
    print(f"{'metric':32s} {'unit':6s} {'sess':4s} {'frameCV':>8s} {'withinCV':>9s} {'betweenCV':>10s} {'betweenSD':>10s}  tier  (current)")
    for m, r in sorted(res.items(), key=lambda kv: kv[1]["tier"]):
        cur = reg.metrics[m].reliability_tier if m in reg.metrics else "-"
        print(f"{m:32s} {r['unit']:6s} {r['n_sessions']:4d} {r['frame_cv']:8.3%} {r['within_cv']:9.3%} {r['between_cv']:10.3%} {r['between_sd']:10.4f}  {r['tier']:4s}  ({cur})")
    ab = sum(1 for r in res.values() if r["tier"] in ("A", "B"))
    print(f"\n{ab} metrics at tier A/B of {len(res)} measured. Go/no-go threshold: ≥ 6 → go, < 4 → re-scope.")
    if len(scores) >= 2:
        print(f"score across {len(scores)} captures: mean {st.mean(scores):.2f}, SD {st.pstdev(scores):.3f}  (release gate ≤ 0.200)")


def write_tiers(res: dict[str, dict]) -> None:
    p = ROOT / "data" / "metrics.json"
    with open(p, encoding="utf-8") as f:
        d = json.load(f)
    changed = 0
    for m in d["metrics"]:
        r = res.get(m["id"])
        if r and r["tier"] in ("A", "B", "C", "D") and r["tier"] != m["reliability_tier"]:
            m["reliability_tier"] = r["tier"]; changed += 1
    with open(p, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
    print(f"updated {changed} reliability tiers in {p}. Now: python tools/build_reference.py && python tools/make_fixtures.py, bump SCORING_MODEL_VERSION.")


def selftest() -> None:
    """Synthetic dumps with known noise; checks tiers come out as designed."""
    import random
    rng = random.Random(1)
    sessions: dict[str, list[dict]] = {}
    truth = {"intercanthal_to_width_ratio": (0.228, 0.002), "canthal_tilt_deg": (4.1, 0.6), "gonial_angle_deg": (122.0, 4.0), "symmetry_index": (0.955, 0.004)}
    for s in range(3):
        caps = []
        for c in range(10):
            readings = {}
            merged = [{"metrics": {}} for _ in range(10)]
            for m, (mu, sd) in truth.items():
                vals = [rng.gauss(mu + (s - 1) * sd * 0.3, sd) for _ in range(10)]
                for k, v in enumerate(vals):
                    merged[k]["metrics"][m] = v
                q = st.quantiles(vals, n=4)
                readings[m] = {"value": st.median(vals), "confidence": 0.9, "iqr": q[2] - q[0]}
            caps.append({"session": f"s{s}", "capture": c, "frames": merged, "readings": readings})
        sessions[f"s{s}"] = caps
    reg = load_registry()
    res, scores = analyse(sessions, reg, "male")
    report(res, scores, reg)
    assert res["intercanthal_to_width_ratio"]["tier"] == "A", res["intercanthal_to_width_ratio"]
    assert all(r["tier"] in ("A", "B", "C", "D") for r in res.values())
    assert res["canthal_tilt_deg"]["between_sd"] < 1.0  # median-of-10 tames 0.6° frame noise
    print("selftest ok")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("captures", nargs="?")
    ap.add_argument("--sex", default="male")
    ap.add_argument("--write-tiers", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        selftest(); return
    if not a.captures:
        ap.error("captures folder required")
    reg = load_registry()
    sessions = load_sessions(Path(a.captures))
    if not sessions:
        sys.exit("no capture_*.json found")
    res, scores = analyse(sessions, reg, a.sex)
    report(res, scores, reg)
    if a.write_tiers:
        write_tiers(res)


if __name__ == "__main__":
    main()
