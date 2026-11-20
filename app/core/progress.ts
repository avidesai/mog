// Port of core/mogcore/progress.py: what changed between two scans of one person.
// A difference counts as a change only when it clears the noise; only modifiable metrics are compared.
import type { Registry } from './registry.ts';
import { IQR_TO_SD, qualityFromZ, score, type CompositeReference, type ScoreInput } from './scoring.ts';

const Z95 = 1.96;

export interface MetricChange { id: string; before: number; after: number; delta: number; withinNoise: boolean; better: boolean }
export interface ScanChange {
  comparable: boolean;
  scoreBefore: number;
  scoreAfter: number;
  scoreDelta: number;
  scoreWithinNoise: boolean;
  metrics: MetricChange[];
}

const readingSd = (inp: ScoreInput, id: string, noiseSd: number): number => {
  const iqr = inp.readings[id]?.iqr ?? 0;
  return Math.max(iqr > 0 ? iqr / IQR_TO_SD : 0, noiseSd);
};

export function compare(before: ScoreInput, after: ScoreInput, reg: Registry, ref: CompositeReference): ScanChange {
  const a = score(before, reg, ref);
  const b = score(after, reg, ref);
  const delta = b.score - a.score;
  const noise = Math.max(b.scoreHigh - b.score, a.scoreHigh - a.score);
  const am = new Map(a.metrics.map((m) => [m.id, m]));
  const rows: { within: boolean; size: number; change: MetricChange }[] = [];
  for (const mb of b.metrics) {
    const m = reg.metrics.get(mb.id)!;
    const ma = am.get(mb.id);
    if (!m.modifiable || !m.scorable || !ma || ma.value === null || mb.value === null) continue;
    const d = mb.value - ma.value;
    const sd = Math.hypot(readingSd(before, m.id, m.noiseSd), readingSd(after, m.id, m.noiseSd));
    const within = Math.abs(d) < Z95 * sd;
    const better = qualityFromZ(mb.z!, m.direction) > qualityFromZ(ma.z!, m.direction);
    rows.push({ within, size: Math.abs(mb.z! - ma.z!), change: { id: m.id, before: ma.value, after: mb.value, delta: d, withinNoise: within, better } });
  }
  rows.sort((x, y) => Number(x.within) - Number(y.within) || y.size - x.size || (x.change.id < y.change.id ? -1 : 1));
  return {
    comparable: a.modelVersion === b.modelVersion,
    scoreBefore: a.score, scoreAfter: b.score, scoreDelta: delta,
    scoreWithinNoise: Math.abs(delta) < noise,
    metrics: rows.map((r) => r.change),
  };
}
