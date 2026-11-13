"""Builds data/composite_reference.json.

Samples a synthetic reference population from the per-metric published norms
(independent normals), computes each metric's quality-term moments and the
standardised composite's quantile table. Fixed seed; the OUTPUT is what ships,
so the app never needs to reproduce this.

Independence between metrics is an acknowledged simplification. It makes the
composite's reference variance slightly too small where metrics correlate
(e.g. adiposity and cervicomental angle), which makes percentiles slightly too
extreme. v1.1's peer-rating data replaces this table with an empirical one.

Run:  python tools/build_reference.py
"""

from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from mogcore.registry import load_registry, DATA_DIR  # noqa: E402
from mogcore.scoring import quality_from_z  # noqa: E402

N = 200_000
SEED = 20261111


def main() -> None:
    reg = load_registry()
    out: dict = {"n": N, "seed": SEED, "q_moments": {}, "quantiles_std": {}, "scorable_metrics": []}
    scorable = [reg.metrics[m] for m in reg.metric_order if reg.metrics[m].scorable]
    out["scorable_metrics"] = [m.id for m in scorable]

    for sex in ("male", "female"):
        rng = random.Random(SEED if sex == "male" else SEED + 1)
        sums = {m.id: 0.0 for m in scorable}
        sqs = {m.id: 0.0 for m in scorable}
        comps: list[float] = []
        total_w = sum(m.weight_for(sex) for m in scorable)
        for _ in range(N):
            c = 0.0
            for m in scorable:
                z = rng.gauss(0.0, 1.0)
                q = quality_from_z(z, m.direction)
                sums[m.id] += q
                sqs[m.id] += q * q
                c += m.weight_for(sex) * q
            comps.append(c / total_w)
        moments = {}
        for m in scorable:
            mean = sums[m.id] / N
            var = sqs[m.id] / N - mean * mean
            moments[m.id] = {"mean": round(mean, 6), "sd": round(math.sqrt(max(var, 0.0)), 6)}
        out["q_moments"][sex] = moments
        # analytic standardisation under independence, mirroring the scorer
        ref_mean = sum(m.weight_for(sex) * moments[m.id]["mean"] for m in scorable) / total_w
        ref_sd = math.sqrt(sum((m.weight_for(sex) * moments[m.id]["sd"]) ** 2 for m in scorable)) / total_w
        std = sorted((c - ref_mean) / ref_sd for c in comps)
        table = [round(std[min(int(i * (N - 1) / 1000), N - 1)], 6) for i in range(1001)]
        out["quantiles_std"][sex] = table
        print(f"{sex}: ref_mean={ref_mean:.4f} ref_sd={ref_sd:.4f} p5={table[50]:.3f} p50={table[500]:.3f} p95={table[950]:.3f}")

    with open(DATA_DIR / "composite_reference.json", "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)
    print("wrote", DATA_DIR / "composite_reference.json")


if __name__ == "__main__":
    main()
