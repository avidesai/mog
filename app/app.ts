import type { Answer, Result, Sources, Storage } from './app.contract.d.ts';
import metricsJson from './data/metrics.json';
import rulesJson from './data/rules.json';
import referencesJson from './data/references.json';
import denylistJson from './data/denylist.json';
import compositeJson from './data/composite_reference.json';
import fixtures from './data/scoring_cases.json';
import { loadRegistry, type Sex } from './core/registry.ts';
import { score, type CompositeReference, type MetricReading, type ScoreResult } from './core/scoring.ts';
import { buildPlan, type PlanCard } from './core/planner.ts';
import { HabitEngine, daysBetween, newHabitState, type HabitState } from './core/habit.ts';
import { compare } from './core/progress.ts';
import { acknowledge, unfinishedPurchases } from '@exact/purchases';

// Privacy invariant: this file holds named measurements and plan state only. No frame, depth map,
// landmark, mesh or embedding is ever passed in, stored or sent; there is no net grant.
const FILE = 'app:/data/mog.json';
export const grants = `fs.read ${FILE}\nfs.write ${FILE}\ndevice.camera capture.camera_purpose`;

const reg = loadRegistry({ metrics: metricsJson, rules: rulesJson, references: referencesJson, denylist: denylistJson });
const ref = compositeJson as unknown as CompositeReference;
const copyOf = new Map<string, { short: string; plain: string }>((metricsJson as any).metrics.map((m: any) => [m.id, m]));

// `sample` marks the web stand-in's scans, so a made-up reading is never stored beside or compared with a real one.
interface Scan { id: string; date: string; sex: Sex; ageBand: string; profileCaptured: boolean; readings: Record<string, MetricReading>; sample?: boolean }
// `usage` counts how often Metrics was opened today, for the check-in card (habit.ts, distress). A count only.
interface Usage { date: string; resultsOpens: number }
interface Saved { scans: Scan[]; habit: HabitState | null; goals: string[]; timeBudget: number; usage: Usage }

const EMPTY: Saved = { scans: [], habit: null, goals: [], timeBudget: 15, usage: { date: '', resultsOpens: 0 } };

async function load(storage: Storage): Promise<Saved> {
  try {
    return { ...EMPTY, ...JSON.parse(new TextDecoder().decode(await storage.fs.readFile(FILE))) };
  } catch (e: any) {
    if (e.code === 'ENOENT' || e.code === 'bake') return { ...EMPTY };
    throw e;
  }
}
const save = (storage: Storage, s: Saved) => storage.fs.atomicWriteFile(FILE, new TextEncoder().encode(JSON.stringify(s)));

const GROUPS: [string, string[]][] = [
  ['eyes', ['canthal_tilt_deg', 'intercanthal_to_width_ratio', 'eye_aspect_ratio', 'eye_width_to_intercanthal', 'brow_to_eye_distance_ratio']],
  ['midface', ['midface_ratio', 'nasal_width_to_intercanthal', 'nose_length_to_face_height', 'philtrum_length_ratio']],
  ['lower', ['mouth_width_to_nose', 'mouth_width_to_interpupillary', 'lip_ratio_upper_lower', 'lower_third_split', 'bigonial_to_bizygomatic', 'chin_width_to_mouth']],
  ['proportion', ['facial_thirds_upper', 'facial_thirds_middle', 'facial_thirds_lower', 'face_height_to_width', 'bitemporal_to_bizygomatic', 'symmetry_index', 'fwhr']],
  ['profile', ['nasofrontal_angle_deg', 'nasolabial_angle_deg', 'nasal_tip_projection_goode', 'facial_convexity_deg', 'mentolabial_angle_deg', 'cervicomental_angle_deg', 'chin_projection_eline_mm', 'gonial_angle_deg', 'ramus_to_mandible_ratio', 'forehead_slope_deg']],
  ['appearance', ['skin_evenness', 'facial_adiposity', 'hairline_stage', 'beard_presence']],
];
const groupOf = new Map(GROUPS.flatMap(([g, ids]) => ids.map((id) => [id, g] as [string, string])));

// voice.md: whole degrees, one decimal on mm, three significant figures on ratios.
function fmt(v: number, unit: string): string {
  if (unit === 'deg') return `${Math.round(v)}°`;
  if (unit === 'mm') return `${v >= 0 ? '+' : '−'}${Math.abs(v).toFixed(1)} mm`;
  if (unit === 'index') return v.toFixed(2);
  if (unit === 'category') return v.toFixed(0);
  return Number(v.toPrecision(3)).toString();
}

type View = Result<'loadApp'>;

const MINUS = '\u2212';
// A signed change in the metric's own format: "+3°", "\u22120.08".
function fmtDelta(d: number, unit: string): string {
  const body = fmt(Math.abs(d), unit).replace(/^[+\u2212]/, '');
  return `${d >= 0 ? '+' : MINUS}${body}`;
}

const ordinal = (n: number): string => {
  const teen = n % 100 >= 11 && n % 100 <= 13;
  return `${n}${teen ? 'th' : ['th', 'st', 'nd', 'rd'][n % 10] ?? 'th'}`;
};

const cardView = (c: PlanCard) => ({
  ruleId: c.ruleId, headline: c.headline, body: c.body, whyThis: c.whyThis, evidence: c.evidenceGrade,
  effort: c.effort, weeksLow: c.timelineWeeks[0], weeksHigh: c.timelineWeeks[1], professional: c.safetyTier === 3 || c.safetyTier === 4,
});

// The measurements this audience asks about first lead the paywall's sentence.
const ASKED_FIRST = ['canthal_tilt_deg', 'bigonial_to_bizygomatic', 'midface_ratio', 'symmetry_index', 'gonial_angle_deg', 'facial_thirds_lower'];
const rank = (id: string): number => { const i = ASKED_FIRST.indexOf(id); return i < 0 ? ASKED_FIRST.length : i; };

function view(s: Saved, today: string, isPro: boolean): View {
  const scan = s.scans[s.scans.length - 1];
  if (!scan) return emptyView();
  const r: ScoreResult = score({ sex: scan.sex, ageBand: scan.ageBand, readings: scan.readings, profileCaptured: scan.profileCaptured }, reg, ref);
  const p = buildPlan({ goals: s.goals, timeBudgetMin: s.timeBudget, score: r }, reg);
  const metrics = r.metrics.flatMap((m) => {
    const def = reg.metrics.get(m.id)!;
    if (!groupOf.has(m.id)) return [];
    const free = isPro || m.id === r.topStrength || m.id === r.mostImprovable;
    const unit = def.unit;
    return [{
      id: m.id, name: def.name, short: copyOf.get(m.id)!.short, group: groupOf.get(m.id)!,
      value: m.value === null || !free ? '' : fmt(m.value, unit),
      category: m.category === null || !free ? '' : m.category,
      suppressed: m.suppressedReason ?? '', evidence: m.evidenceGrade, reliability: m.reliabilityTier,
      free, plain: free ? copyOf.get(m.id)!.plain : '',
      refLow: unit === 'category' ? '' : fmt(m.refMean - m.refSd, unit), refHigh: unit === 'category' ? '' : fmt(m.refMean + m.refSd, unit),
      contradicted: m.evidenceGrade === 'contradicted', community: m.evidenceGrade === 'community',
      // Where the reading sits on a ±3 SD track; locked rows get the middle, so nothing leaks through the lock.
      pos: m.z === null || !free ? 0.5 : Math.min(1, Math.max(0, (m.z + 3) / 6)),
    }];
  });
  const habit = s.habit ? new HabitEngine(s.habit) : null;
  const opens = s.usage?.date === today ? s.usage.resultsOpens : 0;
  // The card shows on the day it was triggered; noteResultsOpen marks that day, which starts the 14-day cooldown.
  const distress = habit !== null && habit.s.distressLastShown === today;
  const locked = metrics.filter((m) => !m.free && m.suppressed === '');
  const named = [...locked].sort((x, y) => rank(x.id) - rank(y.id)).slice(0, 3).map((m) => m.short);
  return {
    // What was measured on this scan: profile metrics need a profile capture and are never counted as unlockable.
    hasScan: true, scanDate: scan.date, nMetrics: metrics.filter((m) => m.suppressed === '').length,
    nLocked: locked.length, lockedMore: locked.length - named.length,
    lockedNames: named.map((n, i) => (i === 0 || n === 'fWHR' ? n : n[0].toLowerCase() + n.slice(1))).join(', '),
    nMovable: r.metrics.filter((m) => m.value !== null && reg.metrics.get(m.id)!.modifiable).length,
    score: r.score.toFixed(1), low: r.scoreLow.toFixed(1), high: r.scoreHigh.toFixed(1), lowN: r.scoreLow, highN: r.scoreHigh,
    pct: ordinal(Math.round(r.percentile)),
    tier: r.tier, modelVersion: r.modelVersion,
    strength: r.topStrength ?? '', improvable: r.mostImprovable ?? '',
    metrics,
    plan: p.plan.map(cardView), professional: p.professional.map(cardView), info: p.info.map(cardView),
    dailyMinutes: p.dailyMinutes,
    tasks: habit ? habitTasks(habit, today, new Map(p.plan.map((c) => [c.ruleId, c.findingRefs]))) : [],
    summary: habit ? { ...summaryView(habit, today), distress, opensToday: opens } : emptySummary(),
    nScans: s.scans.length,
    progress: progressView(s, metrics),
  };
}

// The latest scan against the one before it. Only modifiable metrics are listed; a locked one keeps its name
// and its direction of travel but shows no numbers.
function progressView(s: Saved, shown: { id: string; free: boolean }[]): View['progress'] {
  if (s.scans.length < 2) return emptyProgress();
  const [a, b] = s.scans.slice(-2);
  if (!!a.sample !== !!b.sample) return emptyProgress(); // a fixture face is never compared with a real one
  const input = (x: Scan) => ({ sex: x.sex, ageBand: x.ageBand, readings: x.readings, profileCaptured: x.profileCaptured });
  const c = compare(input(a), input(b), reg, ref);
  const free = new Map(shown.map((m) => [m.id, m.free]));
  const days = daysBetween(b.date, a.date);
  const lead = c.metrics.find((m) => !m.withinNoise);
  return {
    comparable: c.comparable,
    delta: c.scoreDelta.toFixed(1) === '0.0' || c.scoreDelta.toFixed(1) === '-0.0' ? '0.0' : `${c.scoreDelta >= 0 ? '+' : MINUS}${Math.abs(c.scoreDelta).toFixed(1)}`,
    up: c.scoreDelta > 0,
    withinNoise: c.scoreWithinNoise,
    before: c.scoreBefore.toFixed(1), after: c.scoreAfter.toFixed(1),
    days, weeks: Math.round(days / 7), sinceDate: a.date,
    lead: lead ? midSentence(copyOf.get(lead.id)!.short) : '',
    rows: c.metrics.map((m) => {
      const unit = reg.metrics.get(m.id)!.unit;
      const open = free.get(m.id) ?? false;
      return {
        id: m.id, short: copyOf.get(m.id)!.short, locked: !open,
        delta: open ? fmtDelta(m.delta, unit) : '', before: open ? fmt(m.before, unit) : '', after: open ? fmt(m.after, unit) : '',
        withinNoise: m.withinNoise, better: m.better,
        // Where each reading sits on a ±3 SD track; a locked row gets the middle, so nothing leaks.
        posA: open ? pos(m.before, m.id, b.sex) : 0.5, posB: open ? pos(m.after, m.id, b.sex) : 0.5,
      };
    }),
  };
}

// A metric name inside a sentence: lower-case first letter, except names that are abbreviations (fWHR).
const midSentence = (n: string): string => (/^[A-Z][a-z]/.test(n) ? n[0].toLowerCase() + n.slice(1) : n);

function pos(v: number, id: string, sex: Sex): number {
  const { mean, sd } = reg.metrics.get(id)!.ref(sex);
  return Math.min(1, Math.max(0, ((v - mean) / sd + 3) / 6));
}

const emptyProgress = (): View['progress'] => ({
  comparable: true, delta: '', up: false, withinNoise: true, before: '', after: '', days: 0, weeks: 0, sinceDate: '', lead: '', rows: [],
});

// Tasks are named task_<rule id> by the planner; the card behind each gives its why, effort and findings.
function habitTasks(e: HabitEngine, today: string, findings: Map<string, string[]>): View['tasks'] {
  const wk = e.weekIndex(today);
  const done = e.s.completions[today] ?? [];
  const weekly = e.weeklyProgress(wk);
  return e.openTasks(wk).map((t) => {
    const rule = reg.rules.get(t.taskId.replace(/^task_/, ''));
    return {
      id: t.taskId, title: rule?.taskTitle ?? t.taskId, cadence: t.cadence,
      done: t.cadence === 'once' ? Object.values(e.s.completions).some((ids) => ids.includes(t.taskId)) : done.includes(t.taskId),
      weeklyDone: weekly[t.taskId]?.[0] ?? 0, weeklyTarget: weekly[t.taskId]?.[1] ?? 0,
      headline: rule?.copy.headline ?? '', body: rule?.copy.body ?? '', whyThis: rule?.copy.why_this ?? '',
      evidence: rule?.evidenceGrade ?? 'weak', effort: rule?.effort ?? 'low',
      weeksLow: rule?.expectedTimelineWeeks[0] ?? 0, weeksHigh: rule?.expectedTimelineWeeks[1] ?? 0,
      basedOn: (findings.get(rule?.id ?? '') ?? []).map((id) => copyOf.get(id)?.short ?? id).join(', '),
    };
  });
}

const emptySummary = (): View['summary'] => ({
  day: 0, week: 0, currentDays: 0, longestDays: 0, thisWeekDays: 0, banked: [], scanWindow: 0, daysUntilScan: -1,
  repairAvailable: false, atRisk: false, dayComplete: false, finished: false, distress: false, opensToday: 0,
});

function summaryView(e: HabitEngine, today: string): Omit<View['summary'], 'distress' | 'opensToday'> {
  // Ask before reconciling: reconcile zeroes a lapsed streak, after which nothing is at risk to repair.
  // While the month's repair can still bridge yesterday, the streak stands.
  const atRisk = e.streakAtRisk(today);
  if (!(atRisk && e.repairAvailable(today))) e.reconcile(today);
  const p = e.pathSummary(today);
  return {
    day: daysBetween(today, e.s.planStart) + 1, week: p.weekIndex, currentDays: p.currentDays, longestDays: p.longestDays, thisWeekDays: p.thisWeekDays,
    banked: p.bankedWeeks, scanWindow: p.scanWindow ?? 0, daysUntilScan: p.daysUntilScan ?? -1,
    repairAvailable: p.repairAvailable, atRisk,
    dayComplete: e.dayStatus(today).complete, finished: p.finished,
  };
}

const emptyView = (): View => ({
  hasScan: false, scanDate: '', nMetrics: 0, nLocked: 0, lockedMore: 0, lockedNames: '', nMovable: 0, score: '', low: '', high: '', lowN: 0, highN: 0, pct: '', tier: '', modelVersion: '',
  strength: '', improvable: '', metrics: [], plan: [], professional: [], info: [], dailyMinutes: 0, tasks: [], summary: emptySummary(),
  nScans: 0, progress: emptyProgress(),
});

const ok = { ok: true, error: '' };

async function storeScan(storage: Storage, today: string, sex: string, ageBand: string, goals: string[], timeBudget: number,
  readings: Record<string, MetricReading>, profileCaptured: boolean, sample = false) {
  if (sex !== 'male' && sex !== 'female') return { ok: false, error: 'no reference table' };
  if (ageBand === '') return { ok: false, error: 'no age band' };
  const s = await load(storage);
  if (sample && s.scans.some((x) => !x.sample)) return { ok: false, error: 'sample after a real scan' };
  const scan: Scan = { id: `scan-${s.scans.length + 1}`, date: today, sex: sex as Sex, ageBand, profileCaptured, readings, ...(sample ? { sample: true } : {}) };
  let r;
  try { r = score({ sex: scan.sex, ageBand, readings, profileCaptured }, reg, ref); }
  catch { return { ok: false, error: 'nothing scorable' }; } // every reading under its floor: the screen offers a retake
  const plan = buildPlan({ goals, timeBudgetMin: timeBudget, score: r }, reg);
  const tasks = plan.tasks.map((t) => ({ taskId: t.taskId, cadence: t.cadence as 'daily' | 'weekly' | 'once', opensWeek: t.opensWeek, weeklyTarget: t.weeklyTarget }));
  const habit = s.habit && s.scans.length ? s.habit : newHabitState(today, tasks);
  if (s.habit && new HabitEngine(habit).scanWindowOpen(today) !== null) new HabitEngine(habit).recordScan(today, scan.id);
  await save(storage, { ...s, goals, timeBudget, scans: [...s.scans, scan], habit });
  return ok;
}

// The one place a purchase is finished (Exact's purchases recipe): Pro is a subscription or a
// non-consumable, so each purchased item is acknowledged once; the store redelivers until it is.
// One run at a time; a request during a run asks it to read the queue again.
let delivering = false, askedAgain = false;
async function deliverPurchases(): Promise<typeof ok> {
  if (delivering) { askedAgain = true; return ok; }
  delivering = true;
  try {
    do {
      askedAgain = false;
      for (const p of await unfinishedPurchases()) {
        if (p.purchaseState !== 'purchased' || !p.itemId.startsWith('pro.')) continue;
        try { await acknowledge({ purchaseToken: p.purchaseToken }); } catch { /* stays queued; retried */ }
      }
    } while (askedAgain);
    return ok;
  } finally {
    delivering = false;
  }
}

const sources: Sources = {
  loadApp: async ([today, isPro], _store, storage) => view(await load(storage), today, isPro),

  // Stands in for <mog-capture> until the native module lands: a sample face's readings from the
  // golden fixtures. The real module hands over the same named measurements and nothing else.
  // Stands in for <mog-capture> where there is no TrueDepth camera (the web): a sample face's readings.
  // From the second scan on, two soft-tissue readings drop by one reference SD, so Progress has a change to show.
  saveSampleScan: async ([today, sex, ageBand, goals, timeBudget], _store, storage) => {
    const sample = (fixtures as any[]).find((c) => c.name === (sex === 'female' ? 'average_female_full' : 'average_male_full'));
    const readings: Record<string, MetricReading> = { ...sample.readings };
    const earlier = (await load(storage)).scans;
    if (earlier.length > 0 && earlier.every((x) => x.sample) && (sex === 'male' || sex === 'female')) {
      for (const id of ['facial_adiposity', 'cervicomental_angle_deg']) {
        readings[id] = { ...readings[id], value: readings[id].value - reg.metrics.get(id)!.ref(sex).sd };
      }
    }
    return storeScan(storage, today, sex, ageBand, goals, timeBudget, readings, true, true);
  },

  // <mog-capture>'s readings. Only known metric ids with finite numbers are kept; anything else in the
  // message (a nested object, a list, an unknown key) is dropped, so nothing geometric can be stored.
  saveScan: ([today, sex, ageBand, goals, timeBudget, json], _store, storage) => {
    let raw: unknown;
    try { raw = JSON.parse(json); } catch { return Promise.resolve({ ok: false, error: 'unreadable capture' }); }
    const readings: Record<string, MetricReading> = {};
    for (const [id, r] of Object.entries(raw && typeof raw === 'object' ? raw as Record<string, any> : {})) {
      if (!reg.metrics.has(id) || !r || typeof r !== 'object') continue;
      const { value, confidence, iqr } = r;
      if (![value, confidence, iqr].every((x) => typeof x === 'number' && Number.isFinite(x))) continue;
      readings[id] = { value, confidence: Math.min(1, Math.max(0, confidence)), iqr: Math.max(0, iqr) };
    }
    if (Object.keys(readings).length === 0) return Promise.resolve({ ok: false, error: 'nothing measured' });
    return storeScan(storage, today, sex, ageBand, goals, timeBudget, readings, false);
  },

  setTask: async ([taskId, today, done], _store, storage) => {
    const s = await load(storage);
    if (!s.habit) return { ok: false, error: 'no plan', dayCompleted: false };
    const e = new HabitEngine(s.habit);
    const once = s.habit.tasks.find((t) => t.taskId === taskId)?.cadence === 'once';
    const was = e.dayStatus(today).complete;
    if (done) e.completeTask(taskId, today);
    else if (once) e.uncompleteEverywhere(taskId);
    else e.uncompleteTask(taskId, today);
    await save(storage, s);
    return { ok: true, error: '', dayCompleted: !was && e.dayStatus(today).complete };
  },

  noteResultsOpen: async ([today], _store, storage) => {
    const s = await load(storage);
    if (!s.habit) return ok;
    const n = s.usage?.date === today ? s.usage.resultsOpens + 1 : 1;
    const e = new HabitEngine(s.habit);
    if (e.shouldShowDistress(today, { resultsOpensToday: n, rescanAttemptsInWindow: 0 })) e.markDistressShown(today);
    await save(storage, { ...s, usage: { date: today, resultsOpens: n } });
    return ok;
  },

  repairStreak: async ([today], _store, storage) => {
    const s = await load(storage);
    if (!s.habit || !new HabitEngine(s.habit).useRepair(today)) return { ok: false, error: 'no repair' };
    await save(storage, s);
    return ok;
  },

  deliverPurchases: () => deliverPurchases(),

  deleteEverything: async (_args, _store, storage) => {
    await save(storage, { ...EMPTY });
    return ok;
  },
};
export const answer: Answer = (source, args, store, storage, native) => sources[source](args, store, storage, native);
