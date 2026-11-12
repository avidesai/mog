"""Habit layer: daily plan → streak → eight-week path → scan windows.

Rules the code enforces (eng doc, "Habit-layer data model"):
  - A day completes when every DAILY task open that week has a completion for
    that local date. Weekly tasks count toward the week, not the day.
  - A week banks at days_complete >= 5. A banked week never un-banks. A missed
    week stays open; it is never reset.
  - The streak increments once per completed local day. A missed day offers
    one repair if no repair was used this calendar month. Repairs are never
    purchasable and never exceed one.
  - Scan windows open at week 4 and week 8 regardless of streak or banking.
  - Distress card: results_opens_today >= 10 or rescan_attempts_in_window >= 3,
    at most once per 14 days, never A/B tested.
  - Nothing here touches a score.

Local dates are 'YYYY-MM-DD' strings computed by the caller in the device
time zone at the moment of the event. This module never calls the clock.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Iterable

PATH_WEEKS = 8
BANK_THRESHOLD = 5
SCAN_WEEKS = (4, 8)
DISTRESS_RESULTS_OPENS = 10
DISTRESS_RESCAN_ATTEMPTS = 3
DISTRESS_COOLDOWN_DAYS = 14


def _d(s: str) -> date:
    return date.fromisoformat(s)


def _s(d: date) -> str:
    return d.isoformat()


@dataclass(frozen=True)
class TaskDef:
    task_id: str
    cadence: str              # daily / weekly / once
    opens_week: int           # 1-based
    weekly_target: int | None = None


@dataclass
class HabitState:
    plan_start: str                              # local date the plan began (day 1 of week 1)
    tasks: tuple[TaskDef, ...]
    completions: dict[str, set[str]] = field(default_factory=dict)   # local_date → {task_id}
    current_days: int = 0
    longest_days: int = 0
    last_complete_date: str | None = None
    repair_used_month: str | None = None         # 'YYYY-MM'
    banked_weeks: set[int] = field(default_factory=set)
    scans: dict[int, str] = field(default_factory=dict)   # week_index → scan_id
    distress_last_shown: str | None = None


@dataclass(frozen=True)
class DistressSignals:
    results_opens_today: int
    rescan_attempts_in_window: int


@dataclass(frozen=True)
class DayStatus:
    local_date: str
    week_index: int
    daily_due: tuple[str, ...]
    daily_done: tuple[str, ...]
    complete: bool


class HabitEngine:
    def __init__(self, state: HabitState):
        self.s = state

    # ------------------------------------------------------------ calendar
    def week_index(self, local_date: str) -> int:
        """1-based week of the path; 0 before start; > PATH_WEEKS after the path ends."""
        days = (_d(local_date) - _d(self.s.plan_start)).days
        if days < 0:
            return 0
        return days // 7 + 1

    def week_dates(self, week_index: int) -> list[str]:
        start = _d(self.s.plan_start) + timedelta(days=7 * (week_index - 1))
        return [_s(start + timedelta(days=i)) for i in range(7)]

    def open_tasks(self, week_index: int) -> list[TaskDef]:
        return [t for t in self.s.tasks if t.opens_week <= week_index]

    def daily_due(self, week_index: int) -> tuple[str, ...]:
        return tuple(t.task_id for t in self.open_tasks(week_index) if t.cadence == "daily")

    # --------------------------------------------------------------- days
    def day_status(self, local_date: str) -> DayStatus:
        wk = self.week_index(local_date)
        due = self.daily_due(wk)
        done_set = self.s.completions.get(local_date, set())
        done = tuple(t for t in due if t in done_set)
        complete = wk >= 1 and len(due) > 0 and len(done) == len(due)
        return DayStatus(local_date=local_date, week_index=wk, daily_due=due, daily_done=done, complete=complete)

    def complete_task(self, task_id: str, local_date: str) -> DayStatus:
        """Record a completion. Idempotent. Returns the day's status after the change
        and advances the streak if the day just completed."""
        if task_id not in {t.task_id for t in self.s.tasks}:
            raise KeyError(task_id)
        wk = self.week_index(local_date)
        tdef = next(t for t in self.s.tasks if t.task_id == task_id)
        if tdef.opens_week > wk:
            raise ValueError(f"{task_id} opens in week {tdef.opens_week}, not {wk}")
        before = self.day_status(local_date).complete
        self.s.completions.setdefault(local_date, set()).add(task_id)
        after = self.day_status(local_date)
        if after.complete and not before:
            self._on_day_complete(local_date)
        self._maybe_bank(wk)
        return after

    def uncomplete_task(self, task_id: str, local_date: str) -> DayStatus:
        """Un-tick. The streak is NOT rolled back (it only ever counts up and resets on a
        missed day); a banked week never un-banks."""
        self.s.completions.get(local_date, set()).discard(task_id)
        return self.day_status(local_date)

    def _on_day_complete(self, local_date: str) -> None:
        last = self.s.last_complete_date
        if last is None:
            self.s.current_days = 1
        else:
            gap = (_d(local_date) - _d(last)).days
            if gap == 1:
                self.s.current_days += 1
            elif gap <= 0:
                return  # out-of-order or duplicate; nothing changes
            else:
                # missed ≥1 day without a repair → streak restarts
                self.s.current_days = 1
        self.s.last_complete_date = local_date
        self.s.longest_days = max(self.s.longest_days, self.s.current_days)

    # ------------------------------------------------------------ streaks
    def streak_at_risk(self, today: str) -> bool:
        """True when yesterday was missed and today's completion would otherwise restart the streak."""
        last = self.s.last_complete_date
        if last is None or self.s.current_days == 0:
            return False
        gap = (_d(today) - _d(last)).days
        return gap == 2  # exactly one missed day between

    def repair_available(self, today: str) -> bool:
        return self.s.repair_used_month != today[:7]

    def use_repair(self, today: str) -> bool:
        """Spend this month's single repair to bridge one missed day. Returns False and
        changes nothing if no repair is available or there is nothing to repair."""
        if not self.streak_at_risk(today) or not self.repair_available(today):
            return False
        missed = _s(_d(today) - timedelta(days=1))
        # Repairing marks the missed day as bridged: the streak continues as if that day completed.
        self.s.last_complete_date = missed
        self.s.repair_used_month = today[:7]
        return True

    def reconcile(self, today: str) -> None:
        """Call on app foreground. If more than one day has passed since the last
        completion (and no repair bridged it), the streak is 0. Never touches banking."""
        last = self.s.last_complete_date
        if last is None:
            return
        gap = (_d(today) - _d(last)).days
        if gap >= 2:
            self.s.current_days = 0

    # -------------------------------------------------------------- weeks
    def days_complete_in_week(self, week_index: int) -> int:
        return sum(1 for d in self.week_dates(week_index) if self.day_status(d).complete)

    def weekly_progress(self, week_index: int) -> dict[str, tuple[int, int]]:
        """{task_id: (done, target)} for weekly-cadence tasks open this week."""
        dates = set(self.week_dates(week_index))
        out: dict[str, tuple[int, int]] = {}
        for t in self.open_tasks(week_index):
            if t.cadence != "weekly":
                continue
            done = sum(1 for d, ids in self.s.completions.items() if d in dates and t.task_id in ids)
            out[t.task_id] = (done, t.weekly_target or 0)
        return out

    def _maybe_bank(self, week_index: int) -> None:
        if 1 <= week_index <= PATH_WEEKS and week_index not in self.s.banked_weeks:
            if self.days_complete_in_week(week_index) >= BANK_THRESHOLD:
                self.s.banked_weeks.add(week_index)

    def is_banked(self, week_index: int) -> bool:
        return week_index in self.s.banked_weeks

    # -------------------------------------------------------------- scans
    def scan_window_open(self, today: str) -> int | None:
        """Returns the scan week (4 or 8) whose window is open today and unused, else None.
        Windows open on day 1 of that week and stay open until used. Independent of streak."""
        wk = self.week_index(today)
        for sw in SCAN_WEEKS:
            if wk >= sw and sw not in self.s.scans:
                return sw
        return None

    def days_until_next_scan(self, today: str) -> int | None:
        wk = self.week_index(today)
        for sw in SCAN_WEEKS:
            if sw not in self.s.scans and wk < sw:
                opens = _d(self.s.plan_start) + timedelta(days=7 * (sw - 1))
                return (opens - _d(today)).days
        return None

    def record_scan(self, today: str, scan_id: str) -> int:
        sw = self.scan_window_open(today)
        if sw is None:
            raise ValueError("no scan window open")
        self.s.scans[sw] = scan_id
        return sw

    # ----------------------------------------------------------- distress
    def should_show_distress(self, today: str, sig: DistressSignals) -> bool:
        triggered = (sig.results_opens_today >= DISTRESS_RESULTS_OPENS
                     or sig.rescan_attempts_in_window >= DISTRESS_RESCAN_ATTEMPTS)
        if not triggered:
            return False
        last = self.s.distress_last_shown
        if last is not None and (_d(today) - _d(last)).days < DISTRESS_COOLDOWN_DAYS:
            return False
        return True

    def mark_distress_shown(self, today: str) -> None:
        self.s.distress_last_shown = today

    # ------------------------------------------------------------ summary
    def path_summary(self, today: str) -> dict:
        wk = self.week_index(today)
        return {
            "week_index": wk,
            "current_days": self.s.current_days,
            "longest_days": self.s.longest_days,
            "banked_weeks": sorted(self.s.banked_weeks),
            "this_week_days": self.days_complete_in_week(wk) if 1 <= wk <= PATH_WEEKS else 0,
            "scan_window": self.scan_window_open(today),
            "days_until_scan": self.days_until_next_scan(today),
            "repair_available": self.repair_available(today),
            "finished": wk > PATH_WEEKS or (8 in self.s.scans),
        }
