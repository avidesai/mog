# MogCore (Swift)

Port of `mog-core` for the iPhone app. Pure Foundation. Same JSON tables, same fixtures.

Compiles and passes all tests (including the cross-language golden fixtures) on the macOS CI runner. Locally:

```
cd swift/MogCore
./sync-data.sh        # copies data + fixtures into Resources/
swift build
swift test            # FixtureTests.testGoldenFixtures is the cross-language gate
```

Never edit a fixture to make it pass. If a fixture disagrees after a change, the port has a logic drift — diff against the Python module of the same name line by line.

Module map:

| Swift | Python | What |
|---|---|---|
| `Registry.swift` | `registry.py` | Codable models + validation |
| `Scoring.swift` | `scoring.py` | readings → score, band, tier |
| `Planner.swift` | `planner.py` | rules → plan / professional / info + tasks |
| `Habit.swift` | `habit.py` | streak, banking, scan windows, distress; own date arithmetic (no Calendar) |
| `Denylist.swift` | `denylist.py` | tier-X scanner for LLM output |

Integration notes for the app:
- The geometry layer produces `[String: MetricReading]` keyed by metric id. `confidence` is landmark confidence in [0,1]; `iqr` is the cross-frame interquartile range in metric units.
- Compute local dates with `Calendar.current` **at the moment of the event**, format as `yyyy-MM-dd`, and pass strings. The engine never reads the clock.
- Persist `HabitState` with `Codable` into the encrypted store. `completions` is `[String: Set<String>]`.
- Call `HabitEngine.reconcile(today:)` on every foreground.
