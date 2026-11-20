"""Spike-1 analysis: landmark dumps from one person, several sessions, to per-metric reliability.

Input: a folder tree of capture_N.json files written by the app's landmark dump, one subfolder
per session (captures/s1/, captures/s2/, captures/s3/).

The app scores one capture at a time, so the noise that matters is how far a single capture
lands from the person's true value on another day. Per metric, from a one-way variance split:
  within_sd   capture-to-capture SD inside a session (pooled, n-1)
  between_sd  session-to-session SD of the true value, with the within part removed
  retest_sd   sqrt(within_sd^2 + between_sd^2): a single capture's between-session noise.
              This is what metrics.json calls noise_sd.
  r           1 / (1 + (retest_sd / pop_sd)^2), the attenuation the scorer weights by
  tier        A if r >= 0.90, B if >= 0.75, C if >= 0.50, D otherwise (decisions: grade on r, not CV)

The score is computed on a fixed panel: "frontal" (the default, pose != profile, scored as
front-only) or "all". Mesh-derived profile angles are reported apart so their r can be judged.
Score reliability: SD of the score across captures (gate: 0.6), how often two captures land in
the same tier, and how often a capture's band holds the person's mean score.

Usage:
  python core/tools/cv_analysis.py path/to/captures [--sex male] [--panel frontal|all] [--write]
  python core/tools/cv_analysis.py --selftest
"""

from __future__ import annotations

import argparse
import itertools
import json
import math
import statistics as st
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from mogcore import load_registry  # noqa: E402
from mogcore.scoring import score, ScoreInput, MetricReading  # noqa: E402

SCORE_SD_GATE = 0.60      # decisions.md: median per-person score SD on measured noise
GO_AB = 6                 # go/no-go: at least 6 frontal metrics at A/B is go, fewer than 4 is re-scope
RESCOPE_AB = 4


def tier_for_r(r: float) -> str:
    if not math.isfinite(r):
        return "?"
    return "A" if r >= 0.90 else "B" if r >= 0.75 else "C" if r >= 0.50 else "D"


def components(groups: list[list[float]]) -> tuple[float, float, float]:
    """(within_sd, between_sd, retest_sd) from captures grouped by session; nan when it can't be told."""
    groups = [g for g in groups if len(g) >= 1]
    multi = [g for g in groups if len(g) >= 2]
    if len(groups) < 2 or not multi:
        return math.nan, math.nan, math.nan
    ss = sum(sum((x - st.mean(g)) ** 2 for x in g) for g in multi)
    dof = sum(len(g) - 1 for g in multi)
    var_w = ss / dof
    means = [st.mean(g) for g in groups]
    n_bar = len(groups) / sum(1 / len(g) for g in groups)          # harmonic mean of session sizes
    var_b = max(0.0, st.variance(means) - var_w / n_bar)
    return math.sqrt(var_w), math.sqrt(var_b), math.sqrt(var_w + var_b)


def load_sessions(root: Path) -> dict[str, list[dict]]:
    sessions: dict[str, list[dict]] = {}
    for f in sorted(root.rglob("capture_*.json")):
        with open(f, encoding="utf-8") as fh:
            d = json.load(fh)
        sessions.setdefault(d.get("session", f.parent.name), []).append(d)
    return sessions


def panel_input(readings: dict, reg, sex: str, panel: str) -> ScoreInput:
    rd = {k: MetricReading(value=v["value"], confidence=v.get("confidence", 0.9), iqr=v.get("iqr", 0.0))
          for k, v in readings.items() if k in reg.metrics and (panel == "all" or reg.metrics[k].pose != "profile")}
    return ScoreInput(sex, "18-24", rd, profile_captured=(panel == "all"))


def analyse(sessions: dict[str, list[dict]], reg, sex: str, panel: str = "frontal") -> tuple[dict[str, dict], dict]:
    metrics = sorted({k for caps in sessions.values() for c in caps for k in c["readings"] if k in reg.metrics})
    out: dict[str, dict] = {}
    for m in metrics:
        meta = reg.metrics[m]
        groups = [[c["readings"][m]["value"] for c in caps if m in c["readings"]] for caps in sessions.values()]
        w, b, rt = components(groups)
        frame_cvs = []
        for caps in sessions.values():
            for c in caps:
                fv = [fr["metrics"][m] for fr in c.get("frames", []) if m in fr.get("metrics", {})]
                if len(fv) >= 3 and st.mean(fv):
                    frame_cvs.append(st.stdev(fv) / abs(st.mean(fv)))
        pop_sd = meta.ref(sex)[1]
        r = 1.0 / (1.0 + (rt / pop_sd) ** 2) if math.isfinite(rt) and pop_sd > 0 else math.nan
        out[m] = {
            "unit": meta.unit, "pose": meta.pose, "n_sessions": sum(1 for g in groups if g),
            "frame_cv": st.mean(frame_cvs) if frame_cvs else math.nan,
            "within_sd": w, "between_sd": b, "retest_sd": rt, "pop_sd": pop_sd, "r": r,
            "tier": tier_for_r(r) if meta.unit != "category" else "?",
        }
    results = []
    for caps in sessions.values():
        for c in caps:
            try:
                results.append(score(panel_input(c["readings"], reg, sex, panel), reg))
            except ValueError:
                pass
    stats = {"panel": panel, "n": len(results)}
    if len(results) >= 2:
        scores = [x.score for x in results]
        mean = st.mean(scores)
        pairs = list(itertools.combinations(results, 2))
        stats.update({
            "mean": mean, "sd": st.stdev(scores),
            "tier_agreement": sum(a.tier == b.tier for a, b in pairs) / len(pairs),
            "band_coverage": sum(x.score_low <= mean <= x.score_high for x in results) / len(results),
        })
    return out, stats


def report(res: dict[str, dict], stats: dict, reg) -> None:
    def rows(title, items):
        print(f"\n{title}")
        print(f"  {'metric':32s} {'sess':>4s} {'withinSD':>9s} {'betweenSD':>10s} {'retestSD':>9s} {'popSD':>8s} {'r':>5s}  tier  (current)")
        for m, r in sorted(items, key=lambda kv: (kv[1]["tier"], kv[0])):
            cur = reg.metrics[m].reliability_tier
            print(f"  {m:32s} {r['n_sessions']:4d} {r['within_sd']:9.4f} {r['between_sd']:10.4f} {r['retest_sd']:9.4f} {r['pop_sd']:8.4f} {r['r']:5.2f}  {r['tier']:4s}  ({cur})")
    front = [(m, r) for m, r in res.items() if r["pose"] != "profile"]
    prof = [(m, r) for m, r in res.items() if r["pose"] == "profile"]
    rows("frontal panel", front)
    if prof:
        rows("profile angles (from the front mesh unless a profile capture was taken)", prof)
    ab = sum(1 for _, r in front if r["tier"] in ("A", "B"))
    verdict = "go" if ab >= GO_AB else "re-scope" if ab < RESCOPE_AB else "borderline"
    print(f"\n{ab} frontal metrics at A/B (r >= 0.75). Go/no-go: >= {GO_AB} go, < {RESCOPE_AB} re-scope. Verdict: {verdict}")
    if stats.get("n", 0) >= 2:
        print(f"score on the {stats['panel']} panel over {stats['n']} captures: mean {stats['mean']:.2f}, SD {stats['sd']:.3f} "
              f"(gate {SCORE_SD_GATE}: {'PASS' if stats['sd'] <= SCORE_SD_GATE else 'FAIL'}); "
              f"same tier in {stats['tier_agreement']:.0%} of capture pairs; band holds the mean in {stats['band_coverage']:.0%} of captures")


def write_measured(res: dict[str, dict]) -> None:
    """Write measured noise_sd and the tier that follows from it into metrics.json."""
    p = ROOT / "data" / "metrics.json"
    with open(p, encoding="utf-8") as f:
        d = json.load(f)
    changed = 0
    for m in d["metrics"]:
        r = res.get(m["id"])
        if not r or not math.isfinite(r["retest_sd"]) or r["tier"] not in ("A", "B", "C", "D"):
            continue
        noise = float(f"{r['retest_sd']:.4g}")
        if m.get("noise_sd") != noise or m["reliability_tier"] != r["tier"]:
            m["noise_sd"], m["reliability_tier"] = noise, r["tier"]
            changed += 1
    with open(p, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"updated noise_sd and tier for {changed} metrics in {p}. Next: bump SCORING_MODEL_VERSION (Python and TS), "
          "python tools/build_reference.py, python tools/make_fixtures.py, python tools/make_fixtures.py --progress, node scripts/sync-app.mjs")


def synthetic(rng, truth: dict[str, tuple[float, float, float]], n_sessions=3, n_caps=10, frames=10) -> dict[str, list[dict]]:
    """truth: metric -> (value, session-to-session SD, capture-to-capture SD). Each capture is a median of frames."""
    sessions = {}
    for s in range(n_sessions):
        day = {m: rng.gauss(mu, sb) for m, (mu, sb, _) in truth.items()}
        caps = []
        for c in range(n_caps):
            readings, merged = {}, [{"metrics": {}} for _ in range(frames)]
            for m, (_, _, sw) in truth.items():
                centre = rng.gauss(day[m], sw)
                vals = [rng.gauss(centre, sw * 0.3) for _ in range(frames)]
                for k, v in enumerate(vals):
                    merged[k]["metrics"][m] = v
                q = st.quantiles(vals, n=4)
                readings[m] = {"value": st.median(vals), "confidence": 0.9, "iqr": q[2] - q[0]}
            caps.append({"session": f"s{s}", "capture": c, "frames": merged, "readings": readings})
        sessions[f"s{s}"] = caps
    return sessions


def selftest(quiet: bool = False) -> None:
    """Known noise in, the variance split and the tiers out."""
    import random
    rng = random.Random(1)
    reg = load_registry()
    sd = {m: reg.metrics[m].ref("male")[1] for m in ("intercanthal_to_width_ratio", "canthal_tilt_deg", "symmetry_index", "gonial_angle_deg")}
    truth = {  # (value, between-session SD, within-session SD), as fractions of the population SD
        "intercanthal_to_width_ratio": (reg.metrics["intercanthal_to_width_ratio"].ref("male")[0], 0.10 * sd["intercanthal_to_width_ratio"], 0.15 * sd["intercanthal_to_width_ratio"]),
        "canthal_tilt_deg": (4.0, 0.25 * sd["canthal_tilt_deg"], 0.35 * sd["canthal_tilt_deg"]),
        "symmetry_index": (reg.metrics["symmetry_index"].ref("male")[0], 0.6 * sd["symmetry_index"], 0.6 * sd["symmetry_index"]),
        "gonial_angle_deg": (122.0, 0.8 * sd["gonial_angle_deg"], 1.0 * sd["gonial_angle_deg"]),
    }
    est = {m: [] for m in truth}
    for _ in range(60):
        res, _ = analyse(synthetic(rng, truth, n_sessions=4, n_caps=8), reg, "male")
        for m in truth:
            est[m].append(res[m]["retest_sd"])
    for m, (_, sb, sw) in truth.items():
        want = math.sqrt(sb ** 2 + sw ** 2)
        got = st.median(est[m])
        assert abs(got - want) / want < 0.2, (m, got, want)     # unbiased single-capture noise, not a session mean
    res, stats = analyse(synthetic(random.Random(2), truth), reg, "male")
    if not quiet:
        report(res, stats, reg)
    assert res["intercanthal_to_width_ratio"]["tier"] == "A"
    assert res["gonial_angle_deg"]["tier"] == "D"
    assert res["gonial_angle_deg"]["pose"] == "profile"
    if not quiet:
        print("selftest ok")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("captures", nargs="?")
    ap.add_argument("--sex", default="male")
    ap.add_argument("--panel", choices=("frontal", "all"), default="frontal")
    ap.add_argument("--write", action="store_true", help="write measured noise_sd and tiers into data/metrics.json")
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
    res, stats = analyse(sessions, reg, a.sex, a.panel)
    report(res, stats, reg)
    if a.write:
        write_measured(res)


if __name__ == "__main__":
    main()
