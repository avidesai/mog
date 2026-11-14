// The TypeScript port of MogCore against the Python spec: core/fixtures/scoring_cases.json to 1e-6,
// plus the scenarios of core/tests/test_planner.py, test_habit.py and the denylist checks.
//   bun test app/tools
import { describe, expect, test } from 'bun:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { loadRegistry, type Registry, type Sex } from '../core/registry.ts';
import { SCORING_MODEL_VERSION, score, tierForPercentile, type CompositeReference, type MetricReading } from '../core/scoring.ts';
import { buildPlan } from '../core/planner.ts';
import { HabitEngine, PATH_WEEKS, addDays, daysBetween, newHabitState, type TaskDef } from '../core/habit.ts';
import { Denylist } from '../core/denylist.ts';

const CORE = join(import.meta.dir, '../../core');
const json = (p: string) => JSON.parse(readFileSync(join(CORE, p), 'utf8'));
const reg: Registry = loadRegistry({
  metrics: json('data/metrics.json'), rules: json('data/rules.json'),
  references: json('data/references.json'), denylist: json('data/denylist.json'),
});
const ref: CompositeReference = json('data/composite_reference.json');
const deny = new Denylist(reg.denylistRaw);

// Mirrors core/tests/conftest.py typical_readings: every metric at its mean, overrides in z.
function typical(sex: Sex = 'male', overrides: Record<string, number> = {}, profile = true): Record<string, MetricReading> {
  const out: Record<string, MetricReading> = {};
  for (const [id, m] of reg.metrics) {
    if (m.pose === 'profile' && !profile) continue;
    if (m.unit === 'category') {
      const v = id in overrides ? overrides[id] : ({ hairline_stage: 1, beard_presence: 0 } as Record<string, number>)[id];
      out[id] = { value: v, confidence: 0.9, iqr: 0 };
      continue;
    }
    const { mean, sd } = m.ref(sex);
    out[id] = { value: mean + (overrides[id] ?? 0) * sd, confidence: 0.9, iqr: 0.05 * sd };
  }
  return out;
}

const plan = (goals: string[], minutes = 15, overrides: Record<string, number> = {}) =>
  buildPlan({ goals, timeBudgetMin: minutes, score: score({ sex: 'male', ageBand: '18-24', readings: typical('male', overrides) }, reg, ref) }, reg);

describe('scoring', () => {
  test('golden fixtures: composite_std to 1e-6; percentile, band, tier and n_scored as recorded', () => {
    const cases = json('fixtures/scoring_cases.json');
    expect(cases.length).toBeGreaterThan(0);
    for (const c of cases) {
      const r = score({ sex: c.sex, ageBand: c.age_band, readings: c.readings, profileCaptured: c.profile_captured }, reg, ref);
      expect(c.model_version, c.name).toBe(SCORING_MODEL_VERSION);
      expect(Math.abs(r.compositeStd - c.expected.composite_std), c.name).toBeLessThanOrEqual(1e-6);
      expect(Math.abs(r.percentile - c.expected.percentile), c.name).toBeLessThanOrEqual(5e-5);
      for (const [got, want] of [[r.score, c.expected.score], [r.scoreLow, c.expected.score_low], [r.scoreHigh, c.expected.score_high]]) {
        expect(Math.abs(got - want), c.name).toBeLessThanOrEqual(0.005 + 1e-9);
      }
      expect(r.tier, c.name).toBe(c.expected.tier);
      expect(r.nScored, c.name).toBe(c.expected.n_scored);
    }
  });

  test('deterministic', () => {
    const a = score({ sex: 'male', ageBand: '18-24', readings: typical('male', { facial_adiposity: 0.7 }) }, reg, ref);
    const b = score({ sex: 'male', ageBand: '18-24', readings: typical('male', { facial_adiposity: 0.7 }) }, reg, ref);
    expect(a.compositeStd).toBe(b.compositeStd);
  });

  test('no scorable metrics throws', () => {
    expect(() => score({ sex: 'male', ageBand: '18-24', readings: { fwhr: { value: 1.9, confidence: 0.9 } } }, reg, ref)).toThrow();
  });

  test('bone is never most improvable', () => {
    const r = score({ sex: 'male', ageBand: '18-24', readings: typical('male', { lower_third_split: 2.5, skin_evenness: -1.2 }) }, reg, ref);
    expect(r.mostImprovable).toBe('skin_evenness');
    expect(score({ sex: 'male', ageBand: '18-24', readings: typical('male', { lower_third_split: 2.5 }) }, reg, ref).mostImprovable).toBeNull();
  });

  test('a non-finite or missing value or confidence is suppressed, a null reading is not measured', () => {
    const baseline = score({ sex: 'male', ageBand: '18-24', readings: typical() }, reg, ref);
    const broken: Partial<MetricReading>[] = [{ value: NaN }, { confidence: NaN }, { value: Infinity }, { confidence: undefined }];
    for (const patch of broken) {
      const readings = typical();
      readings.facial_adiposity = { ...readings.facial_adiposity, ...patch } as MetricReading;
      const r = score({ sex: 'male', ageBand: '18-24', readings }, reg, ref);
      expect(r.metrics.find((m) => m.id === 'facial_adiposity')!.suppressedReason, JSON.stringify(patch)).toBe('low_confidence');
      expect(r.nScored).toBe(baseline.nScored - 1);
      expect(Number.isFinite(r.score)).toBe(true);
    }
    const readings: Record<string, MetricReading | null> = typical();
    readings.facial_adiposity = null;
    const r = score({ sex: 'male', ageBand: '18-24', readings: readings as Record<string, MetricReading> }, reg, ref);
    expect(r.metrics.find((m) => m.id === 'facial_adiposity')!.suppressedReason).toBe('not_measured');
    expect(() => tierForPercentile(NaN)).toThrow();
  });

  test('tier bands', () => {
    expect([41, 50, 68, 90, 99].map((p) => tierForPercentile(p).short)).toEqual(['LTN', 'MTN', 'HTN', 'Chadlite', 'Chad']);
  });
});

describe('planner', () => {
  test('plan size bounds', () => {
    for (const goals of [['general'], ['sharper_jawline', 'better_skin'], ['better_photos']]) {
      const n = plan(goals).plan.length;
      expect(n >= 3 && n <= 6, goals.join()).toBe(true);
    }
  });

  test('tier X never appears', () => {
    const p = plan(['sharper_jawline'], 15, { bigonial_to_bizygomatic: -2.0, beard_presence: 0 });
    const everything = [...p.plan, ...p.professional, ...p.info].map((c) => c.ruleId).concat(p.tasks.map((t) => t.ruleId));
    expect(everything).not.toContain('jaw_exercise_devices');
  });

  test('adiposity rule excludes the weaker duplicate', () => {
    const p = plan(['sharper_jawline'], 15, { facial_adiposity: 1.8, cervicomental_angle_deg: 2.0 });
    const ids = p.plan.map((c) => c.ruleId);
    expect(ids).toContain('adiposity_high_cervicomental_obtuse');
    expect(ids).not.toContain('adiposity_moderate_general');
    expect(p.excludedBy.adiposity_moderate_general).toBe('adiposity_high_cervicomental_obtuse');
  });

  test('professional section is separate and never creates tasks', () => {
    const hair = plan(['hair'], 15, { hairline_stage: 4 });
    expect(hair.professional.map((c) => c.ruleId)).toContain('hairline_recession_referral');
    expect(hair.plan.map((c) => c.ruleId)).not.toContain('hairline_recession_referral');
    expect(hair.plan.every((c) => c.safetyTier === 1 || c.safetyTier === 2)).toBe(true);
    expect(hair.professional.every((c) => c.safetyTier === 3 || c.safetyTier === 4)).toBe(true);
    const chin = plan(['sharper_jawline', 'general'], 15, { chin_projection_eline_mm: -3.0, facial_convexity_deg: -2.5 });
    const pro = new Set(chin.professional.map((c) => c.ruleId));
    expect(pro.size).toBeGreaterThan(0);
    expect(chin.tasks.some((t) => pro.has(t.ruleId))).toBe(false);
  });

  test('mewing myth card is info, not plan', () => {
    const p = plan(['sharper_jawline'], 15, { facial_convexity_deg: -1.5 });
    expect(p.info.map((c) => c.ruleId)).toContain('mewing_myth');
    expect(p.plan.map((c) => c.ruleId)).not.toContain('mewing_myth');
  });

  test('goal match gates rules', () => {
    const ids = plan(['better_photos']).plan.map((c) => c.ruleId);
    expect(ids).toContain('photo_distance_lens');
    expect(ids).not.toContain('adiposity_moderate_general');
  });

  test('each card carries its findings', () => {
    const card = plan(['better_skin'], 15, { skin_evenness: -1.6 }).plan.find((c) => c.ruleId === 'skin_evenness_low_cleanse_moisturise');
    expect(card?.findingRefs).toEqual(['skin_evenness']);
  });

  test('time budget and week one', () => {
    const o = { facial_adiposity: 1.8, skin_evenness: -1.6 };
    const p5 = plan(['sharper_jawline', 'better_skin'], 5, o);
    const p30 = plan(['sharper_jawline', 'better_skin'], 30, o);
    expect(p30.plan.length).toBeGreaterThanOrEqual(p5.plan.length);
    const week1 = plan(['sharper_jawline', 'better_skin'], 15, o).tasks.filter((t) => t.cadence === 'daily' && t.opensWeek === 1);
    expect(week1.length >= 1 && week1.length <= 4).toBe(true);
  });

  test('every goal produces a plan with a daily task for a typical face', () => {
    for (const g of reg.goals.keys()) {
      const p = plan([g]);
      expect(p.plan.length, g).toBeGreaterThanOrEqual(3);
      expect(p.tasks.some((t) => t.cadence === 'daily'), g).toBe(true);
    }
  });
});

describe('habit', () => {
  const T: TaskDef[] = [
    { taskId: 'spf', cadence: 'daily', opensWeek: 1 },
    { taskId: 'sleep', cadence: 'daily', opensWeek: 1 },
    { taskId: 'active', cadence: 'daily', opensWeek: 3 },
    { taskId: 'lift', cadence: 'weekly', opensWeek: 1, weeklyTarget: 3 },
    { taskId: 'haircut', cadence: 'once', opensWeek: 1 },
  ];
  const START = '2026-11-16';
  const eng = (start = START) => new HabitEngine(newHabitState(start, T));
  const day = (n: number) => addDays(START, n - 1);
  const completeDay = (e: HabitEngine, d: string) => { for (const t of e.dailyDue(e.weekIndex(d))) e.completeTask(t, d); };

  test('date arithmetic, strict about what a local date is', () => {
    for (const bad of ['2026-11-14T09:00', '2026-02-30', '2026-1-5', 'garbage']) expect(() => addDays(bad, 0), bad).toThrow();
    expect(() => eng().completeTask('spf', '2026-11-16T09:00')).toThrow();
    expect(addDays('2026-11-30', 1)).toBe('2026-12-01');
    expect(addDays('2028-02-28', 1)).toBe('2028-02-29');
    expect(daysBetween('2027-01-01', '2026-11-16')).toBe(46);
  });

  test('a day completes only when every open daily task is done; weekly and once do not gate it', () => {
    const e = eng();
    e.completeTask('spf', day(1));
    expect(e.dayStatus(day(1)).complete).toBe(false);
    e.completeTask('sleep', day(1));
    expect(e.dayStatus(day(1)).complete).toBe(true);
    expect(e.s.currentDays).toBe(1);
    expect(e.dailyDue(1)).not.toContain('lift');
    expect(e.dailyDue(1)).not.toContain('haircut');
  });

  test('a task not yet open throws, and is required from its week', () => {
    const e = eng();
    expect(() => e.completeTask('active', day(1))).toThrow();
    e.completeTask('spf', day(15)); e.completeTask('sleep', day(15));
    expect(e.dayStatus(day(15)).complete).toBe(false);
    e.completeTask('active', day(15));
    expect(e.dayStatus(day(15)).complete).toBe(true);
  });

  test('streak increments once per day and is idempotent; a missed day restarts it', () => {
    const e = eng();
    completeDay(e, day(1)); completeDay(e, day(1)); e.completeTask('spf', day(1));
    expect(e.s.currentDays).toBe(1);
    completeDay(e, day(2));
    expect([e.s.currentDays, e.s.longestDays]).toEqual([2, 2]);
    completeDay(e, day(4));
    expect([e.s.currentDays, e.s.longestDays]).toEqual([1, 2]);
  });

  test('reconcile zeroes a lapsed streak but not banking', () => {
    const e = eng();
    for (let n = 1; n <= 7; n++) completeDay(e, day(n));
    expect(e.isBanked(1)).toBe(true);
    e.reconcile(day(10));
    expect(e.s.currentDays).toBe(0);
    expect(e.isBanked(1)).toBe(true);
  });

  test('one repair per month, bridging exactly one day', () => {
    const e = eng();
    completeDay(e, day(1)); completeDay(e, day(2));
    expect(e.streakAtRisk(day(4)) && e.repairAvailable(day(4))).toBe(true);
    expect(e.useRepair(day(4))).toBe(true);
    completeDay(e, day(4));
    expect(e.s.currentDays).toBe(3);
    expect(e.streakAtRisk(day(6))).toBe(true);
    expect(e.repairAvailable(day(6))).toBe(false);
    expect(e.useRepair(day(6))).toBe(false);
    completeDay(e, day(6));
    expect(e.s.currentDays).toBe(1);

    const two = eng();
    completeDay(two, day(1));
    expect(two.streakAtRisk(day(4))).toBe(false);
    expect(two.useRepair(day(4))).toBe(false);
  });

  test('repair resets in a new calendar month', () => {
    const e = eng('2026-11-28');
    completeDay(e, '2026-11-28');
    expect(e.useRepair('2026-11-30')).toBe(true);
    completeDay(e, '2026-11-30');
    expect(e.useRepair('2026-12-02')).toBe(true);
    expect(e.s.repairUsedMonth).toBe('2026-12');
  });

  test('a week banks at five days and never un-banks; a missed week stays open', () => {
    const e = eng();
    for (let n = 1; n <= 4; n++) completeDay(e, day(n));
    expect(e.isBanked(1)).toBe(false);
    completeDay(e, day(5));
    expect(e.isBanked(1)).toBe(true);
    e.uncompleteTask('spf', day(5));
    expect(e.isBanked(1)).toBe(true);
    expect(e.daysCompleteInWeek(1)).toBe(4);

    const late = eng();
    completeDay(late, day(8)); completeDay(late, day(9));
    expect(late.isBanked(1)).toBe(false);
    expect(late.daysCompleteInWeek(2)).toBe(2);
    for (let n = 1; n <= 5; n++) completeDay(late, day(n));
    expect(late.isBanked(1)).toBe(true);
  });

  test('weekly progress counts within the week', () => {
    const e = eng();
    e.completeTask('lift', day(1)); e.completeTask('lift', day(3)); e.completeTask('lift', day(8));
    expect(e.weeklyProgress(1).lift).toEqual([2, 3]);
    expect(e.weeklyProgress(2).lift).toEqual([1, 3]);
  });

  test('scan windows open at weeks 4 and 8 regardless of streak, and stay open until used', () => {
    const e = eng();
    expect(e.scanWindowOpen(day(21))).toBeNull();
    expect(e.daysUntilNextScan(day(21))).toBe(1);
    expect(e.scanWindowOpen(day(22))).toBe(4);
    expect(e.recordScan(day(22), 'scan-a')).toBe(4);
    expect(e.scanWindowOpen(day(23))).toBeNull();
    expect(e.daysUntilNextScan(day(23))).toBe(27);
    expect(e.scanWindowOpen(day(50))).toBe(8);

    const late = eng();
    expect(late.scanWindowOpen(day(40))).toBe(4);
    late.recordScan(day(40), 'late');
    expect(late.scanWindowOpen(day(50))).toBe(8);
    expect(() => eng().recordScan(day(10), 'x')).toThrow();
  });

  test('distress thresholds and cooldown', () => {
    const e = eng();
    expect(e.shouldShowDistress(day(1), { resultsOpensToday: 9, rescanAttemptsInWindow: 2 })).toBe(false);
    expect(e.shouldShowDistress(day(1), { resultsOpensToday: 10, rescanAttemptsInWindow: 0 })).toBe(true);
    expect(e.shouldShowDistress(day(1), { resultsOpensToday: 0, rescanAttemptsInWindow: 3 })).toBe(true);
    e.markDistressShown(day(1));
    expect(e.shouldShowDistress(day(10), { resultsOpensToday: 50, rescanAttemptsInWindow: 9 })).toBe(false);
    expect(e.shouldShowDistress(day(15), { resultsOpensToday: 10, rescanAttemptsInWindow: 0 })).toBe(true);
  });

  test('path summary', () => {
    const e = eng();
    for (let n = 1; n <= 5; n++) completeDay(e, day(n));
    const s = e.pathSummary(day(5));
    expect([s.weekIndex, s.currentDays, s.bankedWeeks, s.scanWindow, s.daysUntilScan, s.finished]).toEqual([1, 5, [1], null, 17, false]);
    expect(e.pathSummary(day(7 * PATH_WEEKS + 1)).finished).toBe(true);
  });

  test('uncomplete everywhere for once tasks', () => {
    const e = eng();
    e.completeTask('haircut', day(1)); e.completeTask('haircut', day(3));
    e.uncompleteEverywhere('haircut');
    expect(Object.values(e.s.completions).some((ids) => ids.includes('haircut'))).toBe(false);
  });

  test('the streak save must precede completion', () => {
    const e = eng();
    completeDay(e, day(1)); completeDay(e, day(2));
    expect(e.streakAtRisk(day(4))).toBe(true);
    completeDay(e, day(4));
    expect(e.streakAtRisk(day(4))).toBe(false);
    expect(e.useRepair(day(4))).toBe(false);
    expect(e.s.currentDays).toBe(1);
  });
});

describe('denylist', () => {
  test('all rule copy and task titles pass', () => {
    for (const r of reg.rules.values()) {
      if (r.safetyTier === 'X') continue;
      for (const [key, text] of Object.entries(r.copy)) {
        const hits = deny.scan(text, r.isInfoCard).filter((h) =>
          !((r.safetyTier === 3 || r.safetyTier === 4) && deny.allowedInProfessional.includes(h.match.toLowerCase())));
        expect(hits.map((h) => h.match), `${r.id}.${key}`).toEqual([]);
      }
      if (r.taskTitle !== null) expect(deny.isClean(r.taskTitle), r.id).toBe(true);
    }
  });

  test('catches known bad strings, passes good ones', () => {
    for (const bad of ['Try bone smashing for your cheekbones', 'Take 1mg finasteride daily', 'Aim for 1800 kcal a day',
      'Hard mewing fixes recession', 'You mog most people', 'Looks better than most people',
      'consider leg-lengthening', 'leg lengthening surgery', 'try bpc157', 'try BPC-157']) {
      expect(deny.isClean(bad), bad).toBe(false);
    }
    expect(deny.isClean('Reduce body fat at roughly half a percent of bodyweight per week.')).toBe(true);
    expect(deny.isClean('Daily broad-spectrum SPF 30 or higher.')).toBe(true);
  });

  test('unicode look-alikes are caught as Python catches them', () => {
    for (const bad of ['take ５０ mg', 'take ٥٠ mg', '1٠٠ lbs', 'ſteroid cycle', 'ſarms', '1500 Kcal a day']) expect(deny.isClean(bad), bad).toBe(false);
  });

  test('mewing is allowed only in info cards', () => {
    expect(deny.isClean('There is no evidence that mewing changes adult facial shape.')).toBe(false);
    expect(deny.isClean('There is no evidence that mewing changes adult facial shape.', true)).toBe(true);
  });
});
