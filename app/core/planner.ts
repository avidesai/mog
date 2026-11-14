// Port of core/mogcore/planner.py. Tier 3/4 never enter the ranked plan; tier X is never emitted (checked twice).
import { EVIDENCE_CAP, isProfessional, type Registry, type Rule, type SafetyTier, type Trigger } from './registry.ts';
import type { MetricResult, ScoreResult } from './scoring.ts';

const PLAN_MIN = 3;
const PLAN_MAX = 6;
const EFFORT_PENALTY: Record<string, number> = { low: 0.0, medium: 0.1, high: 0.2 };
// The first goal picked weighs most; unpicked goals keep a floor so foundational habits still appear.
const GOAL_WEIGHT_BY_RANK = [1.0, 0.85, 0.7];
const GOAL_WEIGHT_UNPICKED = 0.25;

export interface PlanInput {
  goals: string[];          // in the order the user picked them; ["general"] alone is valid
  timeBudgetMin: number;
  score: ScoreResult;
}

export interface PlanCard {
  ruleId: string;
  headline: string;
  body: string;
  whyThis: string;
  safetyTier: SafetyTier;
  evidenceGrade: string;
  effort: string;
  timelineWeeks: [number, number];
  findingRefs: string[];
  overlay: string | null;
  isInfoCard: boolean;
  rankScore: number;
}

export interface PlanTask {
  taskId: string;
  ruleId: string;
  title: string;
  cadence: string;
  weeklyTarget: number | null;
  opensWeek: number;
  timeCostMin: number;
  sortRank: number;
  findingRefs: string[];
}

export interface PlanResult {
  plan: PlanCard[];
  professional: PlanCard[];
  info: PlanCard[];
  tasks: PlanTask[];
  excludedBy: Record<string, string>;
  dailyMinutes: number;
}

function triggerFires(t: Trigger, metrics: Map<string, MetricResult>, reg: Registry): boolean {
  const m = metrics.get(t.metric);
  if (m === undefined || m.value === null || m.z === null) return false;
  const floor = t.minConfidence ?? reg.metrics.get(t.metric)!.confidenceFloor;
  if (m.confidence === null || m.confidence < floor) return false;
  if (t.category !== null) return m.category === t.category;
  const v = m.value;
  const x = Number(t.value);
  switch (t.op) {
    case '>': return v > x;
    case '>=': return v >= x;
    case '<': return v < x;
    case '<=': return v <= x;
    case '==': return v === x;
    case '!=': return v !== x;
    default: throw new Error(`unknown op ${t.op}`);
  }
}

function goalWeight(rule: Rule, goals: string[]): number {
  let best = 0.0;
  goals.forEach((g, i) => {
    if (rule.goalMatch.includes(g)) best = Math.max(best, GOAL_WEIGHT_BY_RANK[Math.min(i, GOAL_WEIGHT_BY_RANK.length - 1)]);
  });
  if (best === 0.0 && rule.goalMatch.length) best = GOAL_WEIGHT_UNPICKED;
  return best;
}

function rank(rule: Rule, goalW: number): number {
  const impact = 1.0 / rule.impactRank;
  const evidence = rule.evidenceGrade !== 'contradicted' ? EVIDENCE_CAP[rule.evidenceGrade] : 0.0;
  return impact * (0.3 + evidence) * goalW * (1.0 - EFFORT_PENALTY[rule.effort]);
}

const card = (rule: Rule, refs: string[], rankScore: number): PlanCard => ({
  ruleId: rule.id, headline: rule.copy.headline, body: rule.copy.body, whyThis: rule.copy.why_this,
  safetyTier: rule.safetyTier, evidenceGrade: rule.evidenceGrade, effort: rule.effort,
  timelineWeeks: rule.expectedTimelineWeeks, findingRefs: refs, overlay: rule.overlay,
  isInfoCard: rule.isInfoCard, rankScore,
});

const byRank = (a: PlanCard, b: PlanCard): number =>
  a.rankScore !== b.rankScore ? b.rankScore - a.rankScore : a.ruleId < b.ruleId ? -1 : a.ruleId > b.ruleId ? 1 : 0;

export function buildPlan(inp: PlanInput, reg: Registry): PlanResult {
  const goals = inp.goals.length ? inp.goals : ['general'];
  for (const g of goals) if (!reg.goals.has(g)) throw new Error(`unknown goal ${g}`);
  const metrics = new Map(inp.score.metrics.map((m) => [m.id, m]));

  let fired: [Rule, string[]][] = [];
  for (const rid of reg.ruleOrder) {
    const rule = reg.rules.get(rid)!;
    if (rule.safetyTier === 'X') continue; // first check: tier X never fires
    // every rule, always_on included, must match at least one chosen goal
    if (!goals.some((g) => rule.goalMatch.includes(g))) continue;
    if (rule.alwaysOn && !rule.triggers.length) {
      fired.push([rule, []]);
      continue;
    }
    if (rule.triggers.length && rule.triggers.every((t) => triggerFires(t, metrics, reg))) {
      fired.push([rule, rule.triggers.map((t) => t.metric)]);
    }
  }

  const excludedBy: Record<string, string> = {};
  const firedIds = new Set(fired.map(([r]) => r.id));
  for (const [rule] of fired) {
    for (const x of rule.excludes) if (firedIds.has(x) && !(x in excludedBy)) excludedBy[x] = rule.id;
  }
  fired = fired.filter(([r]) => !(r.id in excludedBy));

  const candidates: PlanCard[] = [];
  const professional: PlanCard[] = [];
  const info: PlanCard[] = [];
  for (const [rule, refs] of fired) {
    if (rule.safetyTier === 'X') throw new Error('tier X reached ranking'); // second check
    const c = card(rule, refs, rank(rule, goalWeight(rule, goals)));
    if (isProfessional(rule)) professional.push(c);
    else if (rule.isInfoCard) info.push(c);
    else candidates.push(c);
  }
  candidates.sort(byRank);
  professional.sort(byRank);
  info.sort(byRank);

  // Take in rank order while daily minutes fit the budget; always take at least PLAN_MIN.
  const plan: PlanCard[] = [];
  let dailyMinutes = 0;
  for (const c of candidates) {
    const rule = reg.rules.get(c.ruleId)!;
    const cost = rule.cadence === 'daily' ? rule.timeCostMin : 0;
    if (plan.length >= PLAN_MAX) break;
    if (plan.length >= PLAN_MIN && dailyMinutes + cost > inp.timeBudgetMin) continue;
    plan.push(c);
    dailyMinutes += cost;
  }

  const tasks: PlanTask[] = [];
  plan.forEach((c, i) => {
    const rule = reg.rules.get(c.ruleId)!;
    if (rule.taskTitle === null) return;
    tasks.push({
      taskId: `task_${rule.id}`, ruleId: rule.id, title: rule.taskTitle, cadence: rule.cadence,
      weeklyTarget: rule.weeklyTarget, opensWeek: rule.opensWeek, timeCostMin: rule.timeCostMin,
      sortRank: i, findingRefs: c.findingRefs,
    });
  });

  return { plan, professional, info, tasks, excludedBy, dailyMinutes };
}
