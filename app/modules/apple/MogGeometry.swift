// `<mog-capture>`'s geometry: mesh → anatomical points → metrics → readings. Assembled from
// ios/Mog/Geometry and ios/Mog/Capture/FrameAggregator.swift (the SwiftUI reference); keep them in step.
//
// Privacy invariant: everything here is pure and in memory. Vertices and points are never stored,
// logged or sent; only `GeometryPipeline.json`'s named scalars leave this file.
#if os(iOS) && canImport(ARKit)
import Foundation
import ARKit
import CoreVideo
import simd

/// One metric's cross-frame median, mean landmark confidence and interquartile range.
struct Reading { let value: Double; let confidence: Double; let iqr: Double }

/// Anatomical points in the face anchor's coordinate space (metres): +Y up, +Z out of the face
/// toward the camera, X across the face. Which side is "left" is a display concern only — every
/// metric below is either symmetric or uses both sides.
struct AnatomicalPoints {
    var p: [String: SIMD3<Float>] = [:]
    var confidence: [String: Double] = [:]
    subscript(_ k: String) -> SIMD3<Float>? { p[k] }
    func conf(_ keys: [String]) -> Double { keys.map { confidence[$0] ?? 0 }.min() ?? 0 }
}

/// Produces anatomical points from the 1,220-vertex ARKit mesh. Uses picked indices from
/// landmark_map.json where present (confidence 0.92) and geometric heuristics elsewhere (0.75).
final class Landmarker {
    private let map: [String: Int]

    init() {
        var m: [String: Int] = [:]
        if let url = Bundle.main.url(forResource: "landmark_map", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let pts = obj["points"] as? [String: Any] {
            for (k, v) in pts { if let i = v as? Int { m[k] = i } }
        }
        map = m
    }

    var pickedCount: Int { map.count }

    func points(from v: [SIMD3<Float>]) -> AnatomicalPoints {
        var out = AnatomicalPoints()
        guard v.count > 100 else { return out }
        let h = Heuristics(v)

        func set(_ key: String, _ fallback: @autoclosure () -> SIMD3<Float>?) {
            if let i = map[key], i < v.count { out.p[key] = v[i]; out.confidence[key] = 0.92 }
            else if let f = fallback() { out.p[key] = f; out.confidence[key] = 0.75 }
        }

        set("pronasale", h.noseTip)
        set("menton", h.menton)
        set("subnasale", h.subnasale)
        set("nasion", h.nasion)
        set("glabella", h.glabella)
        set("pogonion", h.pogonion)
        set("sulcus_mentolabialis", h.mentolabialSulcus)
        set("labrale_superius", h.labraleSuperius)
        set("labrale_inferius", h.labraleInferius)
        set("stomion", h.stomion)
        set("upper_lip_top", h.labraleSuperius)
        set("zygion_l", h.zygion(sign: +1))
        set("zygion_r", h.zygion(sign: -1))
        set("gonion_l", h.gonion(sign: +1))
        set("gonion_r", h.gonion(sign: -1))
        set("cheilion_l", h.cheilion(sign: +1))
        set("cheilion_r", h.cheilion(sign: -1))
        set("alare_l", h.alare(sign: +1))
        set("alare_r", h.alare(sign: -1))
        set("canthus_outer_l", h.outerCanthus(sign: +1))
        set("canthus_outer_r", h.outerCanthus(sign: -1))
        set("canthus_inner_l", h.innerCanthus(sign: +1))
        set("canthus_inner_r", h.innerCanthus(sign: -1))
        set("chin_lateral_l", h.chinLateral(sign: +1))
        set("chin_lateral_r", h.chinLateral(sign: -1))
        set("frontotemporale_l", h.frontotemporale(sign: +1))
        set("frontotemporale_r", h.frontotemporale(sign: -1))
        // Eye lids, pupils, brows, columella, alar crease: no robust heuristic → picked index only.
        for k in ["lid_upper_l", "lid_lower_l", "lid_upper_r", "lid_lower_r", "pupil_l", "pupil_r", "brow_mid", "brow_lower_l", "brow_lower_r", "columella_point", "alar_crease"] {
            set(k, nil)
        }
        return out
    }
}

/// Geometric heuristics over the mesh. Each is a defensible first estimate, not a landmark
/// definition; the vertex picker replaces them one by one. All assume the anchor frame above.
struct Heuristics {
    let v: [SIMD3<Float>]
    let midlineTol: Float = 0.006   // 6 mm band around x = 0 counts as "midline"

    init(_ v: [SIMD3<Float>]) { self.v = v }

    private var midline: [SIMD3<Float>] { v.filter { abs($0.x) < midlineTol } }

    /// Most anterior point.
    var noseTip: SIMD3<Float>? { v.max { $0.z < $1.z } }
    /// Lowest point on the midline.
    var menton: SIMD3<Float>? { midline.min { $0.y < $1.y } }
    /// Below the nose tip on the midline: the point of minimum z between tip and the upper lip.
    var subnasale: SIMD3<Float>? {
        guard let tip = noseTip else { return nil }
        let band = midline.filter { $0.y < tip.y - 0.008 && $0.y > tip.y - 0.030 }
        return band.min { $0.z < $1.z }
    }
    /// Above the nose tip: the point of minimum z between the tip and the brow.
    var nasion: SIMD3<Float>? {
        guard let tip = noseTip else { return nil }
        let band = midline.filter { $0.y > tip.y + 0.015 && $0.y < tip.y + 0.055 }
        return band.min { $0.z < $1.z }
    }
    /// Local z maximum above the nasion (brow ridge midline).
    var glabella: SIMD3<Float>? {
        guard let n = nasion else { return nil }
        let band = midline.filter { $0.y > n.y + 0.004 && $0.y < n.y + 0.030 }
        return band.max { $0.z < $1.z }
    }
    /// Most anterior midline point in the lower third below the lip.
    var pogonion: SIMD3<Float>? {
        guard let m = menton, let s = stomion else { return nil }
        let band = midline.filter { $0.y > m.y + 0.004 && $0.y < s.y - 0.012 }
        return band.max { $0.z < $1.z }
    }
    var mentolabialSulcus: SIMD3<Float>? {
        guard let pg = pogonion, let li = labraleInferius else { return nil }
        let band = midline.filter { $0.y > pg.y && $0.y < li.y }
        return band.min { $0.z < $1.z }
    }
    /// Lip points: the midline between subnasale and menton has two local z-maxima (lips) with a
    /// minimum between (stomion). Scan from subnasale downward.
    private var lipBand: [SIMD3<Float>] {
        guard let sn = subnasale, let m = menton else { return [] }
        let top = sn.y - 0.004, bottom = sn.y - (sn.y - m.y) * 0.62
        return midline.filter { $0.y < top && $0.y > bottom }.sorted { $0.y > $1.y }
    }
    var labraleSuperius: SIMD3<Float>? {
        let b = lipBand; guard b.count > 4 else { return nil }
        let upper = b.prefix(b.count / 2)
        return upper.max { $0.z < $1.z }
    }
    var labraleInferius: SIMD3<Float>? {
        let b = lipBand; guard b.count > 4 else { return nil }
        let lower = b.suffix(b.count / 2)
        return lower.max { $0.z < $1.z }
    }
    var stomion: SIMD3<Float>? {
        guard let ls = labraleSuperius, let li = labraleInferius else { return nil }
        return midline.filter { $0.y < ls.y && $0.y > li.y }.min { $0.z < $1.z }
    }
    /// Widest point of the face at cheekbone height (between nasion and subnasale).
    func zygion(sign: Float) -> SIMD3<Float>? {
        guard let n = nasion, let sn = subnasale else { return nil }
        let band = v.filter { $0.y < n.y && $0.y > sn.y && $0.x * sign > 0 }
        return band.max { $0.x * sign < $1.x * sign }
    }
    /// Widest point of the lower face at the height band just above the menton — the soft-tissue jaw angle.
    func gonion(sign: Float) -> SIMD3<Float>? {
        guard let m = menton, let st = stomion else { return nil }
        let band = v.filter { $0.y > m.y + 0.010 && $0.y < st.y && $0.x * sign > 0 }
        // the jaw angle is the point farthest from the midline that is also farthest back
        return band.max { ($0.x * sign - $0.z * 0.5) < ($1.x * sign - $1.z * 0.5) }
    }
    func cheilion(sign: Float) -> SIMD3<Float>? {
        guard let st = stomion else { return nil }
        let band = v.filter { abs($0.y - st.y) < 0.006 && $0.x * sign > 0.012 }
        // mouth corner: lateral extreme of the lip z-ridge
        return band.filter { $0.z > st.z - 0.012 }.max { $0.x * sign < $1.x * sign }
    }
    func alare(sign: Float) -> SIMD3<Float>? {
        guard let tip = noseTip, let sn = subnasale else { return nil }
        let band = v.filter { $0.y < tip.y && $0.y > sn.y - 0.002 && $0.x * sign > 0.006 && $0.z > sn.z + 0.004 }
        return band.max { $0.x * sign < $1.x * sign }
    }
    func outerCanthus(sign: Float) -> SIMD3<Float>? {
        guard let n = nasion else { return nil }
        // eye line is roughly at nasion height; the outer canthus is the lateral extreme of the orbital rim's z-dip
        let band = v.filter { abs($0.y - n.y) < 0.008 && $0.x * sign > 0.030 && $0.x * sign < 0.060 }
        return band.min { $0.z < $1.z }
    }
    func innerCanthus(sign: Float) -> SIMD3<Float>? {
        guard let n = nasion else { return nil }
        let band = v.filter { abs($0.y - n.y) < 0.008 && $0.x * sign > 0.008 && $0.x * sign < 0.024 }
        return band.min { $0.z < $1.z }
    }
    func chinLateral(sign: Float) -> SIMD3<Float>? {
        guard let pg = pogonion, let m = menton else { return nil }
        let band = v.filter { $0.y < pg.y && $0.y > m.y && $0.x * sign > 0 && $0.z > pg.z - 0.015 }
        return band.max { $0.x * sign < $1.x * sign }
    }
    func frontotemporale(sign: Float) -> SIMD3<Float>? {
        guard let g = glabella else { return nil }
        let band = v.filter { $0.y > g.y + 0.010 && $0.x * sign > 0.030 }
        // narrowest point of the forehead above the brow: minimum lateral extent per row → take the row min of max-x
        return band.min { $0.x * sign < $1.x * sign }
    }
}

/// Pure functions from anatomical points to the metric ids in core/data/metrics.json.
/// Everything is computed in the face anchor frame, which is already pose-normalised and metric,
/// so there is no perspective or scale step. Frontal metrics use (x, y); profile angles use the
/// midline's (y, z) — which means the ARKit mesh yields profile angles from the FRONT capture.
/// Whether those are reliable enough to replace a separate profile capture is a spike-2 question.
enum MetricFunctions {

    static func compute(_ a: AnatomicalPoints) -> FrameAggregator.PerFrame {
        var m: [String: Double] = [:]
        var c: [String: Double] = [:]

        func dist2(_ p: SIMD3<Float>, _ q: SIMD3<Float>) -> Double { Double(hypot(p.x - q.x, p.y - q.y)) }   // frontal plane
        func dy(_ p: SIMD3<Float>, _ q: SIMD3<Float>) -> Double { Double(abs(p.y - q.y)) }
        func mid(_ p: SIMD3<Float>, _ q: SIMD3<Float>) -> SIMD3<Float> { (p + q) / 2 }
        func angleDeg(at b: SIMD3<Float>, _ a: SIMD3<Float>, _ cpt: SIMD3<Float>, plane: (SIMD3<Float>) -> SIMD2<Float>) -> Double {
            let u = plane(a) - plane(b), w = plane(cpt) - plane(b)
            let cosv = simd_dot(u, w) / max(1e-9, simd_length(u) * simd_length(w))
            return Double(acos(max(-1, min(1, cosv)))) * 180 / .pi
        }
        let sag: (SIMD3<Float>) -> SIMD2<Float> = { SIMD2($0.z, $0.y) }   // sagittal plane (profile)
        let fro: (SIMD3<Float>) -> SIMD2<Float> = { SIMD2($0.x, $0.y) }

        func put(_ id: String, _ keys: [String], _ f: () -> Double?) {
            guard keys.allSatisfy({ a[$0] != nil }), let v = f(), v.isFinite else { return }
            m[id] = v; c[id] = a.conf(keys)
        }

        // --- widths and heights ---
        let bizyg = a["zygion_l"].flatMap { l in a["zygion_r"].map { dist2(l, $0) } }
        let interc = a["canthus_inner_l"].flatMap { l in a["canthus_inner_r"].map { dist2(l, $0) } }
        let ipd = a["pupil_l"].flatMap { l in a["pupil_r"].map { dist2(l, $0) } }
        let mouthW = a["cheilion_l"].flatMap { l in a["cheilion_r"].map { dist2(l, $0) } }
        let alarW = a["alare_l"].flatMap { l in a["alare_r"].map { dist2(l, $0) } }
        let bigon = a["gonion_l"].flatMap { l in a["gonion_r"].map { dist2(l, $0) } }

        put("fwhr", ["zygion_l", "zygion_r", "brow_mid", "upper_lip_top"]) {
            guard let bz = bizyg, let b = a["brow_mid"], let u = a["upper_lip_top"] else { return nil }
            return bz / dy(b, u)
        }
        put("canthal_tilt_deg", ["canthus_inner_l", "canthus_outer_l", "canthus_inner_r", "canthus_outer_r"]) {
            func tilt(_ i: SIMD3<Float>, _ o: SIMD3<Float>) -> Double { Double(atan2(o.y - i.y, abs(o.x - i.x))) * 180 / .pi }
            return (tilt(a["canthus_inner_l"]!, a["canthus_outer_l"]!) + tilt(a["canthus_inner_r"]!, a["canthus_outer_r"]!)) / 2
        }
        put("intercanthal_to_width_ratio", ["canthus_inner_l", "canthus_inner_r", "zygion_l", "zygion_r"]) { interc! / bizyg! }
        put("eye_aspect_ratio", ["canthus_inner_l", "canthus_outer_l", "lid_upper_l", "lid_lower_l", "canthus_inner_r", "canthus_outer_r", "lid_upper_r", "lid_lower_r"]) {
            let l = dy(a["lid_upper_l"]!, a["lid_lower_l"]!) / dist2(a["canthus_inner_l"]!, a["canthus_outer_l"]!)
            let r = dy(a["lid_upper_r"]!, a["lid_lower_r"]!) / dist2(a["canthus_inner_r"]!, a["canthus_outer_r"]!)
            return (l + r) / 2
        }
        put("eye_width_to_intercanthal", ["canthus_inner_l", "canthus_outer_l", "canthus_inner_r", "canthus_outer_r"]) {
            let w = (dist2(a["canthus_inner_l"]!, a["canthus_outer_l"]!) + dist2(a["canthus_inner_r"]!, a["canthus_outer_r"]!)) / 2
            return w / interc!
        }
        // facial thirds need trichion (hairline) — not in the ARKit mesh. Suppressed until the appearance layer supplies it.
        put("lower_third_split", ["subnasale", "stomion", "menton"]) { dy(a["subnasale"]!, a["stomion"]!) / dy(a["subnasale"]!, a["menton"]!) }
        put("midface_ratio", ["pupil_l", "pupil_r", "upper_lip_top"]) {
            let line = mid(a["pupil_l"]!, a["pupil_r"]!)
            return ipd! / dy(line, a["upper_lip_top"]!)
        }
        put("nasal_width_to_intercanthal", ["alare_l", "alare_r", "canthus_inner_l", "canthus_inner_r"]) { alarW! / interc! }
        put("mouth_width_to_nose", ["cheilion_l", "cheilion_r", "alare_l", "alare_r"]) { mouthW! / alarW! }
        put("mouth_width_to_interpupillary", ["cheilion_l", "cheilion_r", "pupil_l", "pupil_r"]) { mouthW! / ipd! }
        put("lip_ratio_upper_lower", ["labrale_superius", "stomion", "labrale_inferius"]) {
            dy(a["labrale_superius"]!, a["stomion"]!) / dy(a["stomion"]!, a["labrale_inferius"]!)
        }
        put("bigonial_to_bizygomatic", ["gonion_l", "gonion_r", "zygion_l", "zygion_r"]) { bigon! / bizyg! }
        put("chin_width_to_mouth", ["chin_lateral_l", "chin_lateral_r", "cheilion_l", "cheilion_r"]) { dist2(a["chin_lateral_l"]!, a["chin_lateral_r"]!) / mouthW! }
        put("bitemporal_to_bizygomatic", ["frontotemporale_l", "frontotemporale_r", "zygion_l", "zygion_r"]) { dist2(a["frontotemporale_l"]!, a["frontotemporale_r"]!) / bizyg! }
        put("face_height_to_width", ["nasion", "menton", "zygion_l", "zygion_r"]) { dy(a["nasion"]!, a["menton"]!) / bizyg! }
        put("philtrum_length_ratio", ["subnasale", "labrale_superius", "menton"]) { dy(a["subnasale"]!, a["labrale_superius"]!) / dy(a["subnasale"]!, a["menton"]!) }
        put("brow_to_eye_distance_ratio", ["brow_lower_l", "lid_upper_l", "brow_lower_r", "lid_upper_r", "canthus_inner_l", "canthus_outer_l"]) {
            let fw = dist2(a["canthus_inner_l"]!, a["canthus_outer_l"]!)
            return ((dy(a["brow_lower_l"]!, a["lid_upper_l"]!) + dy(a["brow_lower_r"]!, a["lid_upper_r"]!)) / 2) / fw
        }

        // --- symmetry: mirror paired points across x = 0 and measure displacement, normalised by bizygomatic width ---
        put("symmetry_index", ["zygion_l", "zygion_r"]) {
            let pairs = [("zygion_l", "zygion_r"), ("gonion_l", "gonion_r"), ("cheilion_l", "cheilion_r"), ("alare_l", "alare_r"),
                         ("canthus_inner_l", "canthus_inner_r"), ("canthus_outer_l", "canthus_outer_r"), ("chin_lateral_l", "chin_lateral_r")]
            var acc = 0.0, n = 0.0
            for (l, r) in pairs {
                guard let L = a[l], let R = a[r] else { continue }
                let mirrored = SIMD3(-R.x, R.y, R.z)
                acc += Double(simd_length(L - mirrored)); n += 1
            }
            guard n >= 4, let bz = bizyg else { return nil }
            return 1.0 - (acc / n) / bz
        }

        // --- profile angles from the midline's sagittal plane ---
        put("nasofrontal_angle_deg", ["glabella", "nasion", "pronasale"]) { angleDeg(at: a["nasion"]!, a["glabella"]!, a["pronasale"]!, plane: sag) }
        put("nasolabial_angle_deg", ["columella_point", "subnasale", "labrale_superius"]) { angleDeg(at: a["subnasale"]!, a["columella_point"]!, a["labrale_superius"]!, plane: sag) }
        put("facial_convexity_deg", ["glabella", "subnasale", "pogonion"]) { angleDeg(at: a["subnasale"]!, a["glabella"]!, a["pogonion"]!, plane: sag) }
        put("mentolabial_angle_deg", ["labrale_inferius", "sulcus_mentolabialis", "pogonion"]) { angleDeg(at: a["sulcus_mentolabialis"]!, a["labrale_inferius"]!, a["pogonion"]!, plane: sag) }
        put("nasal_tip_projection_goode", ["alar_crease", "pronasale", "nasion"]) {
            let ac = a["alar_crease"]!, pn = a["pronasale"]!, n = a["nasion"]!
            let proj = Double(abs(pn.z - ac.z))
            let len = Double(hypot(pn.z - n.z, pn.y - n.y))
            return proj / len
        }
        put("chin_projection_eline_mm", ["pronasale", "pogonion", "labrale_inferius"]) {
            // signed distance (mm) of the lower lip from the pronasale–pogonion line, sagittal plane
            let p = sag(a["pronasale"]!), g = sag(a["pogonion"]!), l = sag(a["labrale_inferius"]!)
            let d = g - p
            let cross = d.x * (l.y - p.y) - d.y * (l.x - p.x)
            return Double(cross / max(1e-6, simd_length(d))) * 1000
        }
        // cervicomental angle, gonial angle, ramus ratio, forehead slope: need neck / tragus / trichion → not from this mesh.

        return FrameAggregator.PerFrame(metrics: m, confidences: c)
    }
}

// Port of core/appearance (skin.py, adiposity.py). Same algorithm, same constants.
// Skin evenness works directly on the 420f buffer's Y and CbCr planes inside a skin mask built by
// projecting cheek and forehead regions of the mesh — no RGB conversion, no pixels retained.

enum SkinEvenness {
    static let wTexture = 6.0, wChroma = 0.045, largeSigma = 9.0, smallSigma = 1.2
    static let cropWidth = 96          // analyse a ~96 px wide face crop, like the prototype

    struct Stats { let texture: Double; let chromaSpread: Double; let evenness: Double; let nPixels: Int }

    /// Returns nil when the mask has too few pixels (e.g. the face is tiny in frame).
    static func compute(pixelBuffer: CVPixelBuffer, face: ARFaceAnchor, camera: ARCamera) -> Stats? {
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else { return nil }
        let w = CVPixelBufferGetWidth(pixelBuffer), h = CVPixelBufferGetHeight(pixelBuffer)
        // Buffer coordinates directly (see LumaStats: landscape-right + buffer size = identity transform).
        let size = CGSize(width: w, height: h)
        func project(_ p: SIMD3<Float>) -> (Int, Int) {
            let wp = face.transform * SIMD4<Float>(p, 1)
            let q = camera.projectPoint(SIMD3(wp.x, wp.y, wp.z), orientation: .landscapeRight, viewportSize: size)
            return (max(0, min(w - 1, Int(q.x))), max(0, min(h - 1, Int(q.y))))
        }
        let v = face.geometry.vertices
        guard v.count > 100 else { return nil }
        // skin regions in anchor space: two cheek boxes and a forehead strip (heuristic, like Landmarker)
        let h0 = Heuristics(v)
        guard let nasion = h0.nasion, let subnasale = h0.subnasale, let glabella = h0.glabella else { return nil }
        let cheekTop = nasion.y - 0.010, cheekBottom = subnasale.y - 0.012
        var regionPts: [(Int, Int)] = []
        for p in v {
            let ax = abs(p.x)
            let cheek = p.y < cheekTop && p.y > cheekBottom && ax > 0.022 && ax < 0.055
            let forehead = p.y > glabella.y + 0.012 && p.y < glabella.y + 0.040 && ax < 0.030
            if cheek || forehead { regionPts.append(project(p)) }
        }
        guard regionPts.count > 60 else { return nil }
        let xs = regionPts.map(\.0), ys = regionPts.map(\.1)
        let x0 = xs.min()!, x1 = xs.max()!, y0 = ys.min()!, y1 = ys.max()!
        guard x1 - x0 > 16, y1 - y0 > 16 else { return nil }

        // Mask: a coarse occupancy grid of projected region vertices, dilated by one cell.
        let step = max(1, (x1 - x0) / cropWidth)
        let gw = (x1 - x0) / step + 1, gh = (y1 - y0) / step + 1
        var occ = [Bool](repeating: false, count: gw * gh)
        for (px, py) in regionPts { occ[((py - y0) / step) * gw + (px - x0) / step] = true }
        var mask = occ
        for gy in 0..<gh { for gx in 0..<gw where occ[gy * gw + gx] {
            for dy in -1...1 { for dx in -1...1 {
                let nx = gx + dx, ny = gy + dy
                if nx >= 0, ny >= 0, nx < gw, ny < gh { mask[ny * gw + nx] = true }
            } }
        } }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let yBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0), let cBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else { return nil }
        let yStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0), cStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
        let yp = yBase.assumingMemoryBound(to: UInt8.self), cp = cBase.assumingMemoryBound(to: UInt8.self)

        var Y = [Double](repeating: 0, count: gw * gh), Cb = Y, Cr = Y
        for gy in 0..<gh { for gx in 0..<gw {
            let px = x0 + gx * step, py = y0 + gy * step
            Y[gy * gw + gx] = max(1, Double(yp[py * yStride + px]))
            let ci = (py / 2) * cStride + (px / 2) * 2          // interleaved CbCr at half resolution
            Cb[gy * gw + gx] = Double(cp[ci]); Cr[gy * gw + gx] = Double(cp[ci + 1])
        } }

        let n = mask.filter { $0 }.count
        guard n >= 200 else { return nil }
        let illum = Grid.blur(Y, gw, gh, largeSigma).map { max(1, $0) }
        let yNorm = zip(Y, illum).map { $0 / $1 }
        let yNormBlur = Grid.blur(yNorm, gw, gh, smallSigma)
        var hp = [Double](repeating: 0, count: gw * gh)
        for i in 0..<hp.count { hp[i] = (yNorm[i] - yNormBlur[i]) * illum[i] / (illum[i] / 128).squareRoot() }
        let texture = Grid.std(hp, mask) / 128.0
        func spread(_ c: [Double]) -> Double {
            let b = Grid.blur(c, gw, gh, largeSigma)
            return Grid.std(zip(c, b).map { $0 - $1 }, mask)
        }
        let chroma = (spread(Cb) + spread(Cr)) / 2
        let raw = wTexture * texture + wChroma * chroma
        return Stats(texture: texture, chromaSpread: chroma, evenness: 1 - min(1, max(0, raw)), nPixels: n)
    }
}

/// Tiny grid helpers: separable Gaussian with edge replication (same as the prototype), masked std.
enum Grid {
    static func kernel(_ sigma: Double) -> [Double] {
        let r = Int(3 * sigma + 0.5)
        var k = (-r...r).map { exp(-0.5 * pow(Double($0) / sigma, 2)) }
        let s = k.reduce(0, +); k = k.map { $0 / s }
        return k
    }
    static func blur(_ img: [Double], _ w: Int, _ h: Int, _ sigma: Double) -> [Double] {
        let k = kernel(sigma); let r = k.count / 2
        var tmp = [Double](repeating: 0, count: w * h), out = tmp
        for y in 0..<h { for x in 0..<w {
            var acc = 0.0
            for (i, kw) in k.enumerated() { acc += kw * img[y * w + min(w - 1, max(0, x + i - r))] }
            tmp[y * w + x] = acc
        } }
        for y in 0..<h { for x in 0..<w {
            var acc = 0.0
            for (i, kw) in k.enumerated() { acc += kw * tmp[min(h - 1, max(0, y + i - r)) * w + x] }
            out[y * w + x] = acc
        } }
        return out
    }
    static func std(_ a: [Double], _ mask: [Bool]) -> Double {
        var s = 0.0, s2 = 0.0, n = 0.0
        for i in 0..<a.count where mask[i] { s += a[i]; s2 += a[i] * a[i]; n += 1 }
        guard n > 1 else { return 0 }
        let m = s / n
        return max(0, s2 / n - m * m).squareRoot()
    }
}

enum AdiposityProxy {
    static let ref: [String: (Double, Double)] = ["lower_face_width": (0.68, 0.05), "cheek_fullness": (0.055, 0.015), "submental_bulge": (0.0, 0.004)]

    static func compute(_ a: AnatomicalPoints, mesh: [SIMD3<Float>]) -> (index: Double, terms: [String: Double])? {
        guard let zl = a["zygion_l"], let zr = a["zygion_r"] else { return nil }
        let bizyg = Double(hypot(zl.x - zr.x, zl.y - zr.y))
        guard bizyg > 0 else { return nil }
        var terms: [String: Double] = [:]

        if let st = a["stomion"], let m = a["menton"] {
            let level = (st.y + m.y) / 2
            let band = mesh.filter { abs($0.y - level) < 0.004 }
            if band.count >= 6, let mn = band.map(\.x).min(), let mx = band.map(\.x).max() {
                terms["lower_face_width"] = Double(mx - mn) / bizyg
            } else if let cl = a["chin_lateral_l"], let cr = a["chin_lateral_r"] {
                terms["lower_face_width"] = Double(hypot(cl.x - cr.x, cl.y - cr.y)) / bizyg * 1.35
            }
        }
        if let gl = a["gonion_l"], let gr = a["gonion_r"], let n = a["nasion"], let m = a["menton"] {
            let faceH = Double(abs(n.y - m.y))
            var vals: [Double] = []
            for (zy, go) in [(zl, gl), (zr, gr)] {
                let sign: Float = zy.x >= 0 ? 1 : -1
                let box = mesh.filter { $0.x * sign > abs(zy.x) * 0.45 && $0.x * sign < abs(zy.x) * 0.95 && $0.y < zy.y && $0.y > go.y }
                if box.count >= 10, faceH > 0, let mz = box.map(\.z).max() {
                    vals.append(Double(mz - (zy.z + go.z) / 2) / faceH)
                }
            }
            if !vals.isEmpty { terms["cheek_fullness"] = vals.reduce(0, +) / Double(vals.count) }
        }
        if let m = a["menton"], let pg = a["pogonion"] {
            let below = mesh.filter { $0.y < m.y - 0.003 && abs($0.x) < 0.015 }
            if below.count >= 6, let mz = below.map(\.z).max() { terms["submental_bulge"] = Double(mz - pg.z) }
        }
        guard !terms.isEmpty else { return nil }
        let z = terms.map { ($0.value - ref[$0.key]!.0) / ref[$0.key]!.1 }.reduce(0, +) / Double(terms.count)
        var index = 1 / (1 + exp(-0.9 * z))
        index = 0.45 + (index - 0.5) * 0.9
        return (max(0, min(1, index)), terms)
    }
}

/// Ten frames → one set of `Reading`s. Metrics are computed per frame by the geometry
/// layer, then the cross-frame median is the value and the interquartile range feeds the
/// confidence band (eng doc, "Capture and quality gates": median of 10, IQR → band).
enum FrameAggregator {
    struct PerFrame { let metrics: [String: Double]; let confidences: [String: Double] }

    static func aggregate(_ frames: [PerFrame]) -> [String: Reading] {
        guard !frames.isEmpty else { return [:] }
        let ids = Set(frames.flatMap { $0.metrics.keys })
        var out: [String: Reading] = [:]
        for id in ids.sorted() {
            let vals = frames.compactMap { $0.metrics[id] }.sorted()
            guard vals.count >= max(3, frames.count / 2) else { continue }   // a metric must be present on most frames
            let med = median(vals)
            let iqr = quantile(vals, 0.75) - quantile(vals, 0.25)
            let conf = frames.compactMap { $0.confidences[id] }.reduce(0, +) / Double(max(1, frames.count))
            out[id] = Reading(value: med, confidence: conf, iqr: iqr)
        }
        return out
    }

    static func median(_ sorted: [Double]) -> Double {
        let n = sorted.count
        return n % 2 == 1 ? sorted[n / 2] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2
    }

    /// Linear-interpolated quantile on a sorted array (matches numpy's default).
    static func quantile(_ sorted: [Double], _ q: Double) -> Double {
        let pos = q * Double(sorted.count - 1)
        let lo = Int(pos.rounded(.down)), hi = min(sorted.count - 1, lo + 1)
        return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - Double(lo))
    }
}

/// Frames → readings. The whole on-device measurement path in one place so the privacy audit
/// has one function to read: nothing here writes to disk or touches the network.
enum GeometryPipeline {
    static let landmarker = Landmarker()

    static func readings(from frames: [FaceFrame], beardPresence: Int?, hairlineStage: Int?) -> [String: Reading] {
        let perFrame: [FrameAggregator.PerFrame] = frames.map { f in
            let pts = landmarker.points(from: f.vertices)
            var pf = MetricFunctions.compute(pts)
            var m = pf.metrics, c = pf.confidences
            // Appearance heads, cheap path (core/appearance): geometric adiposity proxy + skin evenness from the frame.
            if let ad = AdiposityProxy.compute(pts, mesh: f.vertices) {
                m["facial_adiposity"] = ad.index; c["facial_adiposity"] = 0.75 * (Double(ad.terms.count) / 3.0 + 0.34)   // more terms → more confidence, capped ≈1
            }
            if let s = f.skin, s.evenness.isFinite {
                m["skin_evenness"] = s.evenness; c["skin_evenness"] = s.nPixels >= 600 ? 0.8 : 0.7
            }
            pf = FrameAggregator.PerFrame(metrics: m, confidences: c.mapValues { min(1, $0) })
            return pf
        }
        var out = FrameAggregator.aggregate(perFrame)
        // Hairline and beard come from onboarding toggles in the interim (metrics.json: category metrics).
        // Only what the person said: an unanswered question is no reading, never a default.
        if let b = beardPresence { out["beard_presence"] = Reading(value: Double(b), confidence: 0.9, iqr: 0) }
        if let h = hairlineStage { out["hairline_stage"] = Reading(value: Double(h), confidence: 0.7, iqr: 0) }
        return out
    }

    /// The one thing that crosses to the Contract: metric id → {value, confidence, iqr}, finite scalars only.
    static func json(_ readings: [String: Reading]) -> String {
        var obj: [String: [String: Double]] = [:]
        for (id, r) in readings where r.value.isFinite && r.confidence.isFinite && r.iqr.isFinite {
            obj[id] = ["value": r.value, "confidence": r.confidence, "iqr": r.iqr]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
#endif
