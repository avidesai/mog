# ios: capture and geometry reference, spike tools

The product is the Exact app in `app/`. This folder holds the Swift that `app/modules/apple` was ported from, and a small dev-only app that hosts the two spike-1 tools. The SwiftUI screens that used to sit in `Mog/Features/` were deleted on 20 Nov 2026: they called copy keys that `core/copy/strings.json` no longer has. `git show d674aa6:ios/Mog/Features/<path>` still prints any of them.

Nothing here has been compiled or run on a device. Expect the first `xcodebuild` to surface type errors, and fix them forward.

## What is here

```
Mog/Capture/    CaptureSession (ARKit face tracking), GateEvaluator (the capture gates), LumaStats (lighting and sharpness),
                FrameAggregator (median and IQR over ten frames)
Mog/Geometry/   Landmarker (picked indices, heuristics for the rest), Metrics (anatomical points to metrics.json ids),
                Appearance (skin evenness, adiposity proxy), GeometryPipeline (frames to readings), landmark_map.json
Mog/Debug/      SpikeTools: the vertex picker and the landmark dump, DEBUG builds only
Mog/Copy/       Copy.s: the gate labels and hints, read from core/copy/strings.json
Mog/App/        MogApp: a list with the two tools
MogTests/       aggregator, gate and copy-key tests
fastlane/       App Store metadata and screenshots, generated from core/appstore
project.yml     XcodeGen spec for the spike tools app
```

`app/modules/apple/MogCapture.swift` and `MogGeometry.swift` are the copies that ship. A change to a gate threshold, a heuristic or a metric goes into both. `scripts/sync-app.mjs` copies `Mog/Geometry/landmark_map.json` into `app/geometry/`, so edit the map here and run the script.

The landmark dump writes raw mesh vertices to the phone's Documents folder. That is why the tools have their own app and bundle id (`com.avidesai.mog.spike`) and must never be added to the Exact app. The folder is excluded from device backups, and `captures/` is gitignored for the copies you pull to the Mac.

This app has no consent screen and no region check; the deleted screens had both. Use it on your own face. Capturing anyone else, as the week-9 harness plans to, needs their consent handled first, and nothing here does that yet.

## Generate and run

```
brew install xcodegen
cp Mog/Config/Secrets.xcconfig.example Mog/Config/Secrets.xcconfig   # set DEVELOPMENT_TEAM
cd ios && xcodegen generate && open Mog.xcodeproj
```

Run on an iPhone with a TrueDepth camera. The simulator has no face tracking.

## Spike 1

`core/plan/spike-1.md` is the runbook. This app covers two of its steps.

1. Vertex picker. Tap your own face mesh to read ARKit vertex indices, then fill `Mog/Geometry/landmark_map.json` and run `node scripts/sync-app.mjs`. Until a point is picked, `Landmarker` estimates it geometrically at reduced confidence. There are 38 points; nasion, pronasale, menton, the zygions and the canthi matter most.
2. Landmark dump. Each gated capture writes `Documents/captures/<session>/capture_N.json` (pose and metrics per frame, aggregated readings, raw vertices). Do 10 captures in each of 3 sessions, at different times of day and in different light. Pull the folder with Xcode's Devices window, then:
   ```
   python core/tools/cv_analysis.py path/to/captures/
   ```
   It prints each metric's within-session CV, between-session CV and a provisional tier. `core/tools/harness.py --write-tiers` writes the tiers and `noise_sd` into `core/data/metrics.json`; rebuild the reference table and bump the model version after that.

Go or no-go: 6 or more frontal metrics at tier A or B means continue. Fewer than 4 means re-scope around skin, adiposity and grooming (eng doc).

The same captures test one hypothesis. The ARKit mesh is 3D and pose-normalised, so `Metrics.swift` already computes the profile angles (nasofrontal, nasolabial, convexity, mentolabial, E-line) from the frontal capture's midline. If their CV is acceptable, the separate profile capture and its landmark model (spike 2) may be unnecessary.

## Known gaps

- The occlusion gate passes whenever the face is tracked. Spike 1 decides whether it needs a real check.
- 24 metrics come from the mesh, through picked indices or heuristics. Facial thirds (needs trichion), cervicomental, gonial, ramus and forehead slope need the appearance layer or a profile capture.
- The sharpness threshold is untuned.
