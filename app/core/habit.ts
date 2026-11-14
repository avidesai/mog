// Port of core/mogcore/habit.py. The streak counts days the plan was done, never scans; one repair a
// month, never purchasable; a banked week never un-banks. Local dates are 'YYYY-MM-DD' strings the
// caller computes in the device time zone: this module never reads the clock.

export const PATH_WEEKS = 8;
const BANK_THRESHOLD = 5;
const SCAN_WEEKS = [4, 8];
const DISTRESS_RESULTS_OPENS = 10;
const DISTRESS_RESCAN_ATTEMPTS = 3;
const DISTRESS_COOLDOWN_DAYS = 14;

const DAY_MS = 86_400_000;
const fromDay = (n: number): string => new Date(n * DAY_MS).toISOString().slice(0, 10);
// Strict, as Python's date.fromisoformat: a timestamp or 2026-02-30 throws rather than shifting the streak.
const toDay = (s: string): number => {
  const [y, m, d] = s.split('-').map(Number);
  const n = Date.UTC(y, m - 1, d) / DAY_MS;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s) || fromDay(n) !== s) throw new Error(`not a local date: ${s}`);
  return n;
};
export const addDays = (s: string, n: number): string => fromDay(toDay(s) + n);
export const daysBetween = (later: string, earlier: string): number => toDay(later) - toDay(earlier);

export interface TaskDef {
  taskId: string;
  cadence: 'daily' | 'weekly' | 'once';
  opensWeek: number;        // 1-based
  weeklyTarget?: number | null;
}

export interface HabitState {
  planStart: string;                        // day 1 of week 1
  tasks: TaskDef[];
  completions: Record<string, string[]>;    // local date → task ids
  currentDays: number;
  longestDays: number;
  lastCompleteDate: string | null;
  repairUsedMonth: string | null;           // 'YYYY-MM'
  bankedWeeks: number[];
  scans: Record<number, string>;            // week → scan id
  distressLastShown: string | null;
}

export const newHabitState = (planStart: string, tasks: TaskDef[]): HabitState => ({
  planStart, tasks, completions: {}, currentDays: 0, longestDays: 0, lastCompleteDate: null,
  repairUsedMonth: null, bankedWeeks: [], scans: {}, distressLastShown: null,
});

export interface DistressSignals { resultsOpensToday: number; rescanAttemptsInWindow: number }

export interface DayStatus {
  localDate: string;
  weekIndex: number;
  dailyDue: string[];
  dailyDone: string[];
  complete: boolean;
}

/** Mutates the state it wraps, as the Python engine does; the caller persists `s`. */
export class HabitEngine {
  constructor(readonly s: HabitState) {}

  /** 1-based week of the path; 0 before start; > PATH_WEEKS after it ends. */
  weekIndex(localDate: string): number {
    const days = daysBetween(localDate, this.s.planStart);
    return days < 0 ? 0 : Math.floor(days / 7) + 1;
  }

  weekDates(weekIndex: number): string[] {
    const start = addDays(this.s.planStart, 7 * (weekIndex - 1));
    return Array.from({ length: 7 }, (_, i) => addDays(start, i));
  }

  openTasks(weekIndex: number): TaskDef[] {
    return this.s.tasks.filter((t) => t.opensWeek <= weekIndex);
  }

  dailyDue(weekIndex: number): string[] {
    return this.openTasks(weekIndex).filter((t) => t.cadence === 'daily').map((t) => t.taskId);
  }

  dayStatus(localDate: string): DayStatus {
    const wk = this.weekIndex(localDate);
    const due = this.dailyDue(wk);
    const doneSet = this.s.completions[localDate] ?? [];
    const done = due.filter((t) => doneSet.includes(t));
    const complete = wk >= 1 && due.length > 0 && done.length === due.length;
    return { localDate, weekIndex: wk, dailyDue: due, dailyDone: done, complete };
  }

  /** Idempotent. Advances the streak if the day just completed. */
  completeTask(taskId: string, localDate: string): DayStatus {
    const tdef = this.s.tasks.find((t) => t.taskId === taskId);
    if (!tdef) throw new Error(`unknown task ${taskId}`);
    const wk = this.weekIndex(localDate);
    if (tdef.opensWeek > wk) throw new Error(`${taskId} opens in week ${tdef.opensWeek}, not ${wk}`);
    const before = this.dayStatus(localDate).complete;
    const ids = this.s.completions[localDate] ?? [];
    if (!ids.includes(taskId)) this.s.completions[localDate] = [...ids, taskId];
    const after = this.dayStatus(localDate);
    if (after.complete && !before) this.onDayComplete(localDate);
    this.maybeBank(wk);
    return after;
  }

  /** The streak is not rolled back and a banked week never un-banks. */
  uncompleteTask(taskId: string, localDate: string): DayStatus {
    const ids = this.s.completions[localDate];
    if (ids) this.s.completions[localDate] = ids.filter((t) => t !== taskId);
    return this.dayStatus(localDate);
  }

  /** One-off tasks are done or not: remove every completion. Streak and banking stay. */
  uncompleteEverywhere(taskId: string): void {
    for (const d of Object.keys(this.s.completions)) this.s.completions[d] = this.s.completions[d].filter((t) => t !== taskId);
  }

  private onDayComplete(localDate: string): void {
    const last = this.s.lastCompleteDate;
    if (last === null) {
      this.s.currentDays = 1;
    } else {
      const gap = daysBetween(localDate, last);
      if (gap === 1) this.s.currentDays += 1;
      else if (gap <= 0) return; // out of order or duplicate
      else this.s.currentDays = 1; // missed a day without a repair
    }
    this.s.lastCompleteDate = localDate;
    this.s.longestDays = Math.max(this.s.longestDays, this.s.currentDays);
  }

  /** Yesterday was missed and today's completion would otherwise restart the streak. */
  streakAtRisk(today: string): boolean {
    const last = this.s.lastCompleteDate;
    if (last === null || this.s.currentDays === 0) return false;
    return daysBetween(today, last) === 2;
  }

  repairAvailable(today: string): boolean {
    return this.s.repairUsedMonth !== today.slice(0, 7);
  }

  /** Bridges exactly one missed day with this month's single repair; false and no change otherwise. */
  useRepair(today: string): boolean {
    if (!this.streakAtRisk(today) || !this.repairAvailable(today)) return false;
    this.s.lastCompleteDate = addDays(today, -1);
    this.s.repairUsedMonth = today.slice(0, 7);
    return true;
  }

  /** On foreground: more than one day since the last completion zeroes the streak. Banking is untouched. */
  reconcile(today: string): void {
    const last = this.s.lastCompleteDate;
    if (last !== null && daysBetween(today, last) >= 2) this.s.currentDays = 0;
  }

  daysCompleteInWeek(weekIndex: number): number {
    return this.weekDates(weekIndex).filter((d) => this.dayStatus(d).complete).length;
  }

  /** {taskId: [done, target]} for weekly tasks open this week. */
  weeklyProgress(weekIndex: number): Record<string, [number, number]> {
    const dates = new Set(this.weekDates(weekIndex));
    const out: Record<string, [number, number]> = {};
    for (const t of this.openTasks(weekIndex)) {
      if (t.cadence !== 'weekly') continue;
      const done = Object.entries(this.s.completions).filter(([d, ids]) => dates.has(d) && ids.includes(t.taskId)).length;
      out[t.taskId] = [done, t.weeklyTarget ?? 0];
    }
    return out;
  }

  private maybeBank(weekIndex: number): void {
    if (weekIndex >= 1 && weekIndex <= PATH_WEEKS && !this.s.bankedWeeks.includes(weekIndex)
      && this.daysCompleteInWeek(weekIndex) >= BANK_THRESHOLD) {
      this.s.bankedWeeks = [...this.s.bankedWeeks, weekIndex];
    }
  }

  isBanked(weekIndex: number): boolean {
    return this.s.bankedWeeks.includes(weekIndex);
  }

  /** The scan week (4 or 8) open today and unused. Opens on day 1 of that week, independent of streak. */
  scanWindowOpen(today: string): number | null {
    const wk = this.weekIndex(today);
    for (const sw of SCAN_WEEKS) if (wk >= sw && !(sw in this.s.scans)) return sw;
    return null;
  }

  daysUntilNextScan(today: string): number | null {
    const wk = this.weekIndex(today);
    for (const sw of SCAN_WEEKS) {
      if (!(sw in this.s.scans) && wk < sw) return daysBetween(addDays(this.s.planStart, 7 * (sw - 1)), today);
    }
    return null;
  }

  recordScan(today: string, scanId: string): number {
    const sw = this.scanWindowOpen(today);
    if (sw === null) throw new Error('no scan window open');
    this.s.scans[sw] = scanId;
    return sw;
  }

  /** At most once per 14 days; never A/B tested. */
  shouldShowDistress(today: string, sig: DistressSignals): boolean {
    const triggered = sig.resultsOpensToday >= DISTRESS_RESULTS_OPENS || sig.rescanAttemptsInWindow >= DISTRESS_RESCAN_ATTEMPTS;
    if (!triggered) return false;
    const last = this.s.distressLastShown;
    return !(last !== null && daysBetween(today, last) < DISTRESS_COOLDOWN_DAYS);
  }

  markDistressShown(today: string): void {
    this.s.distressLastShown = today;
  }

  pathSummary(today: string) {
    const wk = this.weekIndex(today);
    return {
      weekIndex: wk,
      currentDays: this.s.currentDays,
      longestDays: this.s.longestDays,
      bankedWeeks: [...this.s.bankedWeeks].sort((a, b) => a - b),
      thisWeekDays: wk >= 1 && wk <= PATH_WEEKS ? this.daysCompleteInWeek(wk) : 0,
      scanWindow: this.scanWindowOpen(today),
      daysUntilScan: this.daysUntilNextScan(today),
      repairAvailable: this.repairAvailable(today),
      finished: wk > PATH_WEEKS || 8 in this.s.scans,
    };
  }
}
