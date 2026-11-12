import pytest

from mogcore.habit import HabitEngine, HabitState, TaskDef, DistressSignals, PATH_WEEKS

T = (
    TaskDef("spf", "daily", 1),
    TaskDef("sleep", "daily", 1),
    TaskDef("active", "daily", 3),
    TaskDef("lift", "weekly", 1, weekly_target=3),
    TaskDef("haircut", "once", 1),
)
START = "2026-11-16"  # a Monday


def eng():
    return HabitEngine(HabitState(plan_start=START, tasks=T))


def day(n):  # day n of the path, 1-based
    from datetime import date, timedelta
    return (date.fromisoformat(START) + timedelta(days=n - 1)).isoformat()


def complete_day(e, d):
    for t in e.daily_due(e.week_index(d)):
        e.complete_task(t, d)


def test_day_completes_only_when_all_daily_tasks_done():
    e = eng()
    e.complete_task("spf", day(1))
    assert not e.day_status(day(1)).complete
    e.complete_task("sleep", day(1))
    assert e.day_status(day(1)).complete
    assert e.s.current_days == 1


def test_weekly_and_once_tasks_do_not_gate_the_day():
    e = eng()
    complete_day(e, day(1))
    assert e.day_status(day(1)).complete
    assert "lift" not in e.daily_due(1) and "haircut" not in e.daily_due(1)


def test_task_not_yet_open_cannot_be_completed():
    e = eng()
    with pytest.raises(ValueError):
        e.complete_task("active", day(1))
    e.complete_task("active", day(15))  # week 3


def test_newly_opened_daily_task_is_required_from_its_week():
    e = eng()
    d = day(15)
    e.complete_task("spf", d)
    e.complete_task("sleep", d)
    assert not e.day_status(d).complete
    e.complete_task("active", d)
    assert e.day_status(d).complete


def test_streak_increments_once_per_day_and_is_idempotent():
    e = eng()
    complete_day(e, day(1))
    complete_day(e, day(1))
    e.complete_task("spf", day(1))
    assert e.s.current_days == 1
    complete_day(e, day(2))
    assert e.s.current_days == 2
    assert e.s.longest_days == 2


def test_missed_day_restarts_streak_without_repair():
    e = eng()
    complete_day(e, day(1)); complete_day(e, day(2))
    complete_day(e, day(4))
    assert e.s.current_days == 1
    assert e.s.longest_days == 2


def test_reconcile_zeroes_a_lapsed_streak_but_not_banking():
    e = eng()
    for n in range(1, 8):
        complete_day(e, day(n))
    assert e.is_banked(1)
    e.reconcile(day(10))
    assert e.s.current_days == 0
    assert e.is_banked(1)


def test_one_repair_per_month_never_more():
    e = eng()
    complete_day(e, day(1)); complete_day(e, day(2))
    # miss day 3
    assert e.streak_at_risk(day(4))
    assert e.repair_available(day(4))
    assert e.use_repair(day(4))
    complete_day(e, day(4))
    assert e.s.current_days == 3
    # miss day 5, try again same month
    assert e.streak_at_risk(day(6))
    assert not e.repair_available(day(6))
    assert not e.use_repair(day(6))
    complete_day(e, day(6))
    assert e.s.current_days == 1


def test_repair_only_bridges_exactly_one_day():
    e = eng()
    complete_day(e, day(1))
    # miss days 2 and 3
    assert not e.streak_at_risk(day(4))
    assert not e.use_repair(day(4))


def test_repair_resets_in_a_new_calendar_month():
    e = HabitEngine(HabitState(plan_start="2026-11-28", tasks=T))
    complete_day(e, "2026-11-28")
    assert e.use_repair("2026-11-30")   # bridges 11-29
    complete_day(e, "2026-11-30")
    # miss 12-01
    assert e.use_repair("2026-12-02")   # new month → new repair
    assert e.s.repair_used_month == "2026-12"


def test_week_banks_at_five_days_and_never_unbanks():
    e = eng()
    for n in range(1, 5):
        complete_day(e, day(n))
    assert not e.is_banked(1)
    complete_day(e, day(5))
    assert e.is_banked(1)
    e.uncomplete_task("spf", day(5))
    assert e.is_banked(1)
    assert e.days_complete_in_week(1) == 4


def test_missed_week_stays_open_not_reset():
    e = eng()
    complete_day(e, day(8)); complete_day(e, day(9))  # week 2 only
    assert not e.is_banked(1)
    assert e.days_complete_in_week(2) == 2
    # late completions in week 1 still count toward banking it
    for n in range(1, 6):
        complete_day(e, day(n))
    assert e.is_banked(1)


def test_weekly_progress_counts_within_the_week():
    e = eng()
    e.complete_task("lift", day(1)); e.complete_task("lift", day(3)); e.complete_task("lift", day(8))
    assert e.weekly_progress(1)["lift"] == (2, 3)
    assert e.weekly_progress(2)["lift"] == (1, 3)


def test_scan_windows_open_at_weeks_4_and_8_regardless_of_streak():
    e = eng()
    assert e.scan_window_open(day(21)) is None
    assert e.days_until_next_scan(day(21)) == 1
    assert e.scan_window_open(day(22)) == 4
    assert e.record_scan(day(22), "scan-a") == 4
    assert e.scan_window_open(day(23)) is None
    assert e.days_until_next_scan(day(23)) == 27  # week 8 opens on day 50
    assert e.scan_window_open(day(50)) == 8


def test_unused_scan_window_stays_open():
    e = eng()
    assert e.scan_window_open(day(40)) == 4  # week 6, week-4 scan never taken
    e.record_scan(day(40), "late")
    assert e.scan_window_open(day(50)) == 8


def test_no_scan_outside_window():
    e = eng()
    with pytest.raises(ValueError):
        e.record_scan(day(10), "x")


def test_distress_thresholds_and_cooldown():
    e = eng()
    assert not e.should_show_distress(day(1), DistressSignals(9, 2))
    assert e.should_show_distress(day(1), DistressSignals(10, 0))
    assert e.should_show_distress(day(1), DistressSignals(0, 3))
    e.mark_distress_shown(day(1))
    assert not e.should_show_distress(day(10), DistressSignals(50, 9))
    assert e.should_show_distress(day(15), DistressSignals(10, 0))


def test_path_summary_shape():
    e = eng()
    for n in range(1, 6):
        complete_day(e, day(n))
    s = e.path_summary(day(5))
    assert s["week_index"] == 1 and s["current_days"] == 5 and s["banked_weeks"] == [1]
    assert s["scan_window"] is None and s["days_until_scan"] == 17
    assert not s["finished"]
    assert e.path_summary(day(7 * PATH_WEEKS + 1))["finished"]


def test_timezone_change_does_not_break_streak():
    """Local dates are supplied by the caller; the engine only sees 'YYYY-MM-DD'. Two
    completions on consecutive local dates are consecutive regardless of UTC offsets."""
    e = eng()
    complete_day(e, day(1))
    complete_day(e, day(2))
    assert e.s.current_days == 2
