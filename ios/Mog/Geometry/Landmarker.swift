import Foundation
import simd

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
