# Spike 1 — the go/no-go, on a device

Needs: a TrueDepth iPhone (iPhone X or later), the $99 Apple developer account, a Mac with Xcode 27.1+.
Two apps take part: the Exact app (`app/`, `<mog-capture>`) for the product path, and the SwiftUI
reference (`ios/`) for the dev-only tools (vertex picker, landmark dump), which must never ship in the
Exact app. Both read the same geometry; keep `app/modules/apple` and `ios/Mog/{Capture,Geometry}` in step.

1. **Build.** `cd app && bun exact.mjs ios` on the iPhone, then `bun exact.mjs verify ios`. `<mog-capture>`
   has never been compiled: expect a round of compiler fixes. The camera prompt shows
   `capture.camera_purpose`; the simulator shows `capture.unsupported`; refusing the camera shows
   `capture.camera_denied` with Open Settings.
2. **Pose.** Log yaw/pitch/roll while turning, nodding and tilting in portrait. Each angle moves with its
   own motion and reads ~0 facing the camera; `hint_pitch_up/down` point the right way. (The pose was
   rewritten on 20 Nov to measure in face space and against the phone's portrait up; signs are unconfirmed.)
3. **Buffer projection.** Overlay the `LumaStats` box and the `SkinEvenness` mask: they sit on the face,
   left/right split across it, and covering one side moves `leftMean` or `rightMean`.
4. **Gates.** Walk each failure and its hint (45–75 cm, dark, uneven, clipped, smile, blink, blur). Tune
   `sharpnessMin` (untuned). Record the frame rate (the 15-frame hold assumes ~30 fps) and the time per
   frame during the burst; move `GeometryPipeline.readings` off main if frames drop.
5. **Hold and burst.** 15 passing frames, then 10 collected; a drift mid-burst sends `aborted <i>` and
   alignment restarts; `readings` arrives once and the scan saves.
6. **Vertex picker** (SwiftUI app, Debug › Vertex picker): fill all 38 indices in
   `ios/Mog/Geometry/landmark_map.json`, run `node scripts/sync-app.mjs`, rebuild, and confirm
   `pickedCount == 38` on the device and that the picked-only metrics (fwhr, eye aspect, midface,
   mouth span, brow position, nasolabial angle, nasal tip projection) now appear in `readings`.
7. **Landmark dump** (SwiftUI app): ten captures × three sessions → `python core/tools/cv_analysis.py
   captures/`, then `harness.py --write-tiers`. **≥ 6 frontal metrics at tier A/B → go; < 4 → re-scope
   around skin, adiposity and grooming.** Read the mesh-derived profile angles' CV: if good, spike 2 is cancelled.
8. **Privacy.** During a capture the Exact app writes no files and makes no network calls (interception
   audit). The dumps stay on the dev machine.
