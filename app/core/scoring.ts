// Port of core/mogcore/scoring.py (rules-1.1.0). Metrics are iterated in registry order so the
// floating-point reductions match the Python reference to the last bit.
import type { Metric, Registry, Sex } from './registry.ts';

const Q_CLAMP = 3.0;
const FLAT_BELOW_SD = 1.0;
const MODEL_SIGMA_STD = 0.1;
const BAND_K = 1.0;
const MIN_BAND_HALF_PTS = 0.15;
const IQR_TO_SD = 1.349;
const BEARD_CONFIDENCE_FACTOR = 0.8;
const BEARD_AFFECTED = new Set([
  'bigonial_to_bizygomatic', 'chin_width_to_mouth', 'gonial_angle_deg', 'ramus_to_mandible_ratio',
  'cervicomental_angle_deg', 'chin_projection_eline_mm', 'mentolabial_angle_deg',
]);

const TIERS: [number, string, string][] = [
  [45.0, 'LTN', 'Low-tier normie'],
  [65.0, 'MTN', 'Mid-tier normie'],
  [85.0, 'HTN', 'High-tier normie'],
  [97.0, 'Chadlite', 'Chadlite'],
  [100.1, 'Chad', 'Chad'],
];

export const SCORING_MODEL_VERSION = 'rules-1.1.0';

export function tierForPercentile(p: number): { short: string; long: string } {
  for (const [upper, short, long] of TIERS) if (p < upper) return { short, long };
  const last = TIERS[TIERS.length - 1];
  return { short: last[1], long: last[2] };
}

/** Cross-frame median, landmark confidence in [0,1], cross-frame IQR in metric units. */
export interface MetricReading { value: number; confidence: number; iqr?: number; occluded?: boolean }

export interface ScoreInput {
  sex: Sex;
  ageBand: string;
  readings: Record<string, MetricReading>;
  profileCaptured?: boolean;
}

export type SuppressedReason = 'pose_missing' | 'not_measured' | 'occluded' | 'low_confidence' | 'not_shipped';

export interface MetricResult {
  id: string;
  value: number | null;
  z: number | null;
  category: 'low' | 'typical' | 'high' | null;
  quality: number | null;
  weight: number;
  display: 'point' | 'band' | 'category' | 'suppressed';
  suppressedReason: SuppressedReason | null;
  confidence: number | null;
  refMean: number;
  refSd: number;
  evidenceGrade: string;
  reliabilityTier: string;
  direction: string;
  pose: string;
}

export interface ScoreResult {
  modelVersion: string;
  percentile: number;
  score: number;
  scoreLow: number;
  scoreHigh: number;
  tier: string;
  tierLong: string;
  composite: number;
  compositeStd: number;
  sigmaCaptureStd: number;
  sigmaTotalStd: number;
  metrics: MetricResult[];
  topStrength: string | null;
  mostImprovable: string | null;
  nScored: number;
}

export interface CompositeReference {
  quantiles_std: Record<Sex, number[]>;
  q_moments: Record<Sex, Record<string, { mean: number; sd: number }>>;
}

export function qualityFromZ(z: number, direction: string): number {
  let q: number;
  if (direction === 'toward_mean') q = -Math.abs(z);
  else if (direction === 'higher_better') q = z;
  else if (direction === 'lower_better') q = Math.min(-z, FLAT_BELOW_SD);
  else throw new Error(direction);
  return Math.max(-Q_CLAMP, Math.min(Q_CLAMP, q));
}

/** |dq/dz| at z, used to propagate capture noise. Zero in clamped and flat regions. */
function qualitySlope(z: number, direction: string): number {
  if (Math.abs(z) >= Q_CLAMP) return 0.0;
  if (direction === 'lower_better' && -z >= FLAT_BELOW_SD) return 0.0;
  return 1.0;
}

function categoryFromZ(z: number): 'low' | 'typical' | 'high' {
  if (z < -1.0) return 'low';
  if (z > 1.0) return 'high';
  return 'typical';
}

/** Linear interpolation into the sorted table of standardised-composite quantiles (table[i] is the i/10-th percentile). */
export function percentileFromStd(s: number, table: number[]): number {
  const n = table.length - 1;
  if (s <= table[0]) return 0.0;
  if (s >= table[n]) return 100.0;
  let lo = 0;
  let hi = n;
  while (hi - lo > 1) {
    const mid = Math.floor((lo + hi) / 2);
    if (table[mid] <= s) lo = mid;
    else hi = mid;
  }
  const a = table[lo];
  const b = table[hi];
  const frac = b === a ? 0.0 : (s - a) / (b - a);
  return (lo + frac) * (100.0 / n);
}

const DISPLAY: Record<string, MetricResult['display']> = { A: 'point', B: 'band', C: 'category', D: 'suppressed' };

// Python compares (key, id) tuples; ids break ties in string order.
const byKeyThenId = (ka: number, a: string, kb: number, b: string): number => (ka !== kb ? ka - kb : a < b ? -1 : a > b ? 1 : 0);

export function score(inp: ScoreInput, reg: Registry, ref: CompositeReference): ScoreResult {
  const sex = inp.sex;
  if (sex !== 'male' && sex !== 'female') throw new Error("sex must be 'male' or 'female'");
  const table = ref.quantiles_std[sex];
  const moments = ref.q_moments[sex];
  const profileCaptured = inp.profileCaptured ?? true;

  const beard = inp.readings.beard_presence;
  const beardPresent = beard !== undefined && beard.value >= 1;

  const results: MetricResult[] = [];
  let sumW = 0.0;
  let sumWq = 0.0;
  let sumWMu = 0.0;
  let varRef = 0.0;
  let varCap = 0.0;

  for (const mid of reg.metricOrder) {
    const m = reg.metrics.get(mid) as Metric;
    const { mean, sd } = m.ref(sex);
    const r = inp.readings[mid];
    const base = {
      id: mid, refMean: mean, refSd: sd, evidenceGrade: m.evidenceGrade, reliabilityTier: m.reliabilityTier,
      direction: m.direction, pose: m.pose, weight: 0.0, quality: null,
    };
    const suppressed = (reason: SuppressedReason, confidence: number | null): MetricResult =>
      ({ ...base, value: null, z: null, category: null, display: 'suppressed', suppressedReason: reason, confidence });

    if (r === undefined) {
      results.push(suppressed(m.pose === 'profile' && !profileCaptured ? 'pose_missing' : 'not_measured', null));
      continue;
    }
    let conf = r.confidence;
    if (beardPresent && BEARD_AFFECTED.has(mid)) conf *= BEARD_CONFIDENCE_FACTOR;
    if (r.occluded) { results.push(suppressed('occluded', conf)); continue; }
    if (conf < m.confidenceFloor) { results.push(suppressed('low_confidence', conf)); continue; }
    if (m.reliabilityTier === 'D') { results.push(suppressed('not_shipped', conf)); continue; }

    const z = (r.value - mean) / sd;
    let q: number | null = null;
    let w = 0.0;
    if (m.scorable) {
      q = qualityFromZ(z, m.direction);
      w = m.weightFor(sex);
      const mo = moments[mid];
      sumW += w;
      sumWq += w * q;
      sumWMu += w * mo.mean;
      varRef += (w * mo.sd) ** 2;
      // capture noise: the larger of this capture's cross-frame IQR and the between-session noise_sd
      const iqr = r.iqr ?? 0;
      const zSd = Math.max(iqr > 0 ? iqr / IQR_TO_SD : 0.0, m.noiseSd) / sd;
      varCap += (w * zSd * qualitySlope(z, m.direction)) ** 2;
    }
    results.push({
      ...base, weight: w, quality: q, value: r.value, z, category: categoryFromZ(z),
      display: DISPLAY[m.reliabilityTier], suppressedReason: null, confidence: conf,
    });
  }

  if (sumW <= 0) throw new Error('No scorable metrics available — capture must be retaken');

  const composite = sumWq / sumW;
  const refMean = sumWMu / sumW;
  const refSd = Math.sqrt(varRef) / sumW;
  const compositeStd = (composite - refMean) / refSd;
  const sigmaCaptureStd = Math.sqrt(varCap) / sumW / refSd;
  const sigmaTotal = Math.sqrt(sigmaCaptureStd ** 2 + MODEL_SIGMA_STD ** 2);

  const pct = percentileFromStd(compositeStd, table);
  let pctLo = percentileFromStd(compositeStd - BAND_K * sigmaTotal, table);
  let pctHi = percentileFromStd(compositeStd + BAND_K * sigmaTotal, table);
  // Saturated tails would show a band of ±0.00: false precision. Enforce a minimum half-width.
  pctLo = Math.max(0.0, Math.min(pctLo, pct - MIN_BAND_HALF_PTS * 10.0));
  pctHi = Math.min(100.0, Math.max(pctHi, pct + MIN_BAND_HALF_PTS * 10.0));
  const tier = tierForPercentile(pct);

  const scored = results.filter((x) => x.quality !== null && x.weight > 0);
  let best: MetricResult | null = null;
  for (const x of scored) {
    if (best === null || byKeyThenId(x.quality! * x.weight, x.id, best.quality! * best.weight, best.id) > 0) best = x;
  }
  // Bone is never called improvable: only `modifiable` metrics reading below typical.
  let worst: MetricResult | null = null;
  for (const x of scored) {
    if (!(reg.metrics.get(x.id) as Metric).modifiable || x.quality! >= 0) continue;
    if (worst === null || byKeyThenId(x.quality!, x.id, worst.quality!, worst.id) < 0) worst = x;
  }

  return {
    modelVersion: SCORING_MODEL_VERSION,
    percentile: pct, score: pct / 10.0, scoreLow: pctLo / 10.0, scoreHigh: pctHi / 10.0,
    tier: tier.short, tierLong: tier.long, composite, compositeStd, sigmaCaptureStd, sigmaTotalStd: sigmaTotal,
    metrics: results, topStrength: best ? best.id : null, mostImprovable: worst ? worst.id : null, nScored: scored.length,
  };
}
