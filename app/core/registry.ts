// Port of core/mogcore/registry.py. Built from the parsed data tables, so the engines never touch files.

export type Sex = 'male' | 'female';
export type EvidenceGrade = 'strong' | 'moderate' | 'weak' | 'community' | 'contradicted';
export type Direction = 'toward_mean' | 'higher_better' | 'lower_better' | 'none';
export type SafetyTier = 1 | 2 | 3 | 4 | 'X';

const EVIDENCE_GRADES = ['strong', 'moderate', 'weak', 'community', 'contradicted'];
export const EVIDENCE_CAP: Record<EvidenceGrade, number> = { strong: 1.0, moderate: 0.6, weak: 0.1, community: 0.02, contradicted: 0.0 };
const TIER_WEIGHT: Record<string, number> = { A: 1.0, B: 0.6, C: 0.0, D: 0.0 };
const DIRECTIONS = ['toward_mean', 'higher_better', 'lower_better', 'none'];
const SAFETY_TIERS: SafetyTier[] = [1, 2, 3, 4, 'X'];
const SEXES: Sex[] = ['male', 'female'];

export interface Reference { mean: number; sd: number }

export class Metric {
  constructor(
    readonly id: string,
    readonly name: string,
    readonly unit: string,
    readonly pose: string,
    readonly direction: Direction,
    readonly evidenceGrade: EvidenceGrade,
    readonly reliabilityTier: string,
    readonly confidenceFloor: number,
    readonly reference: Record<string, any>,
    readonly modifiable: boolean,
    readonly noiseSd: number,
  ) {}

  get weightCap(): number { return EVIDENCE_CAP[this.evidenceGrade]; }

  /** Tier gate only: A/B are eligible, C/D are not. The magnitude comes from reliability(). */
  get nominalWeight(): number { return TIER_WEIGHT[this.reliabilityTier] > 0 ? 1.0 : 0.0; }

  /** Attenuation factor r = 1 / (1 + (noise_sd / pop_sd)^2). */
  reliability(sex: Sex): number {
    const { sd } = this.ref(sex);
    if (this.noiseSd <= 0) return 1.0;
    return 1.0 / (1.0 + (this.noiseSd / sd) ** 2);
  }

  get scorable(): boolean {
    return this.direction !== 'none' && this.weightCap > 0 && this.nominalWeight > 0 && this.unit !== 'category';
  }

  get weight(): number { return this.scorable ? this.nominalWeight * this.weightCap : 0.0; }

  weightFor(sex: Sex): number { return this.weight * this.reliability(sex); }

  ref(sex: Sex): Reference {
    const r = this.reference[sex];
    return { mean: Number(r.mean), sd: Number(r.sd) };
  }
}

export interface Trigger {
  metric: string;
  op: string | null;
  value: number | null;
  category: string | null;
  minConfidence: number | null;
}

export interface RuleCopy { headline: string; body: string; why_this: string; [k: string]: string }

export interface Rule {
  id: string;
  version: number;
  triggers: Trigger[];
  goalMatch: string[];
  safetyTier: SafetyTier;
  evidenceGrade: EvidenceGrade;
  expectedTimelineWeeks: [number, number];
  effort: 'low' | 'medium' | 'high';
  impactRank: number;
  evidenceRefs: string[];
  overlay: string | null;
  excludes: string[];
  cadence: string;
  timeCostMin: number;
  opensWeek: number;
  taskTitle: string | null;
  copy: RuleCopy;
  alwaysOn: boolean;
  isInfoCard: boolean;
  weeklyTarget: number | null;
}

/** Tier 1 and 2 enter the ranked plan; 3 and 4 go to the professional section; X never renders. */
export const isPlanEligible = (r: Rule): boolean => r.safetyTier === 1 || r.safetyTier === 2;
export const isProfessional = (r: Rule): boolean => r.safetyTier === 3 || r.safetyTier === 4;

export interface Registry {
  metrics: Map<string, Metric>;
  rules: Map<string, Rule>;
  goals: Map<string, string>;
  references: Record<string, any>;
  denylistRaw: any;
  metricOrder: string[];
  ruleOrder: string[];
}

export interface DataTables { metrics: any; rules: any; references: any; denylist: any }

function validate(reg: Registry): string[] {
  const errors: string[] = [];
  for (const m of reg.metrics.values()) {
    if (!DIRECTIONS.includes(m.direction)) errors.push(`${m.id}: bad direction ${m.direction}`);
    if (!EVIDENCE_GRADES.includes(m.evidenceGrade)) errors.push(`${m.id}: bad evidence grade ${m.evidenceGrade}`);
    if (!(m.reliabilityTier in TIER_WEIGHT)) errors.push(`${m.id}: bad reliability tier ${m.reliabilityTier}`);
    for (const sex of SEXES) {
      if (!(sex in m.reference)) errors.push(`${m.id}: missing reference for ${sex}`);
      else if (m.reference[sex].sd <= 0) errors.push(`${m.id}: non-positive sd for ${sex}`);
    }
    const src = m.reference.source;
    if (!(src in reg.references) && src !== 'n/a') errors.push(`${m.id}: unknown reference source ${src}`);
    const kind = reg.references[src]?.kind;
    if (m.evidenceGrade === 'community' && kind !== 'community' && kind !== undefined) {
      errors.push(`${m.id}: community grade must cite a community source`);
    }
  }
  for (const r of reg.rules.values()) {
    if (!SAFETY_TIERS.includes(r.safetyTier)) errors.push(`${r.id}: bad safety tier ${r.safetyTier}`);
    if (!EVIDENCE_GRADES.includes(r.evidenceGrade)) errors.push(`${r.id}: bad evidence grade`);
    for (const t of r.triggers) {
      if (!reg.metrics.has(t.metric)) errors.push(`${r.id}: trigger on unknown metric ${t.metric}`);
      if ((t.op === null) === (t.category === null)) errors.push(`${r.id}: trigger must have exactly one of op/category`);
    }
    for (const g of r.goalMatch) if (!reg.goals.has(g)) errors.push(`${r.id}: unknown goal ${g}`);
    for (const x of r.excludes) if (!reg.rules.has(x)) errors.push(`${r.id}: excludes unknown rule ${x}`);
    for (const ref of r.evidenceRefs) if (!(ref in reg.references)) errors.push(`${r.id}: unknown evidence ref ${ref}`);
    if (r.safetyTier === 'X' && r.goalMatch.length) errors.push(`${r.id}: tier X rule must have no goal match`);
    if (isPlanEligible(r) && r.cadence === 'daily' && r.taskTitle === null && !r.isInfoCard) errors.push(`${r.id}: daily plan rule needs a task_title`);
    if (r.cadence === 'weekly' && !r.weeklyTarget) errors.push(`${r.id}: weekly rule needs weekly_target`);
    if (!r.triggers.length && !r.alwaysOn) errors.push(`${r.id}: rule with no triggers must be always_on`);
    if (isProfessional(r) && r.taskTitle !== null) errors.push(`${r.id}: tier 3/4 rules never become tasks`);
    for (const k of ['headline', 'body', 'why_this']) if (!(k in r.copy)) errors.push(`${r.id}: copy missing ${k}`);
  }
  return errors;
}

export function loadRegistry(data: DataTables): Registry {
  const metrics = new Map<string, Metric>();
  for (const m of data.metrics.metrics) {
    metrics.set(m.id, new Metric(
      m.id, m.name, m.unit, m.pose, m.direction, m.evidence_grade, m.reliability_tier,
      Number(m.confidence_floor), m.reference, Boolean(m.modifiable ?? false), Number(m.noise_sd ?? 0),
    ));
  }
  const rules = new Map<string, Rule>();
  for (const r of data.rules.rules) {
    rules.set(r.id, {
      id: r.id,
      version: Number(r.version),
      triggers: (r.triggers ?? []).map((t: any) => ({
        metric: t.metric, op: t.op ?? null, value: t.value ?? null, category: t.category ?? null, minConfidence: t.min_confidence ?? null,
      })),
      goalMatch: r.goal_match ?? [],
      safetyTier: r.safety_tier,
      evidenceGrade: r.evidence_grade,
      expectedTimelineWeeks: [r.expected_timeline_weeks[0], r.expected_timeline_weeks[1]],
      effort: r.effort,
      impactRank: Number(r.impact_rank),
      evidenceRefs: r.evidence_refs ?? [],
      overlay: r.overlay ?? null,
      excludes: r.excludes ?? [],
      cadence: r.cadence,
      timeCostMin: Number(r.time_cost_min ?? 0),
      opensWeek: Number(r.opens_week ?? 1),
      taskTitle: r.task_title ?? null,
      copy: r.copy,
      alwaysOn: Boolean(r.always_on ?? false),
      isInfoCard: Boolean(r.is_info_card ?? false),
      weeklyTarget: r.weekly_target ?? null,
    });
  }
  const reg: Registry = {
    metrics,
    rules,
    goals: new Map(data.rules.goals.map((g: any) => [g.id, g.label])),
    references: data.references.refs,
    denylistRaw: data.denylist,
    metricOrder: data.metrics.metrics.map((m: any) => m.id),
    ruleOrder: data.rules.rules.map((r: any) => r.id),
  };
  const errors = validate(reg);
  if (errors.length) throw new Error(`Registry validation failed:\n  ${errors.join('\n  ')}`);
  return reg;
}
