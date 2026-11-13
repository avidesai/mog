# Capture — what I know about this repo

- Primary geometry source: ARKit face mesh (1,220 vertices, metric, pose-normalised in anchor space). MediaPipe is deferred. Anatomical points: picked indices in `ios/Mog/Geometry/landmark_map.json` (all null until the Debug vertex picker is used on a real face) else `Heuristics` (geometric estimates, confidence 0.75).
- Profile angles (nasofrontal, nasolabial, convexity, mentolabial, E-line, Goode) are computed from the frontal mesh's sagittal midline. Not in the mesh: trichion (thirds), cervical point (cervicomental), tragus (ramus), hairline → those metrics suppress.
- Gates (`GateEvaluator`): yaw/pitch ±3°, roll ±2°, 45–75 cm, luma 0.30–0.85, L/R asymmetry ≤ 0.12, clipping ≤ 2%, sharpness (Laplacian variance, threshold untuned), expression blendshapes ≤ 0.25, eyes open. Occlusion gate passes when tracked (not implemented). 15 stable frames → auto-capture 10 frames; a drift aborts and discards.
- `LumaStats` and `SkinEvenness` read the 420f buffer directly; projection uses `.landscapeRight` with the buffer's size (identity transform).
- Appearance heads, cheap path: skin evenness = sqrt-illumination-scaled texture + chroma spread in a cheek/forehead mask (≈0.05 residual luma dependence); adiposity = geometric proxy (lower-face width, cheek fullness, submental bulge). Python prototype tested; Swift port wired.
- Spike tooling: Settings › Debug › Vertex picker, Landmark dump → `core/tools/cv_analysis.py` (per-metric CV, provisional tiers) and `core/tools/harness.py` (per-person test–retest, fairness smoke, `--write-tiers` writes `reliability_tier` + `noise_sd`).
- None of the Swift has run on a device yet. Euler sign conventions and the buffer orientation are the first things to verify.
