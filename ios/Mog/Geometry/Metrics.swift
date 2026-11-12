import Foundation
import simd
import MogCore

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
