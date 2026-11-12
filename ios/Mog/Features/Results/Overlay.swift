import SwiftUI
import MogCore
import simd

// Measurement overlays — "one measurement at a time, drawn on your own capture, long-press to
// hide the geometry" (bible). Privacy decision, recorded here:
//   * Nothing geometric is persisted. Not the still, not the landmarks, not the projected points.
//   * During the session in which a capture happened, the still and the projected anatomical
//     points live in memory (`SessionStill`) and overlays draw on the real photo. The object is
//     dropped when the app backgrounds or the user leaves results.
//   * In every later session the same geometry is drawn on a neutral SCHEMATIC face, labelled as
//     such. The numbers are the user's; the face is not.
// This keeps the retained data exactly what the biometric policy says: named numbers only.

/// What to draw for a metric: points, segments, and an optional angle (vertex, armA, armB).
struct OverlaySpec {
    let points: [String]
    let segments: [(String, String)]
    let angle: (String, String, String)?
    let pose: Pose
}

enum OverlaySpecs {
    static func spec(for metricId: String) -> OverlaySpec? { table[metricId] }

    private static let table: [String: OverlaySpec] = [
        "canthal_tilt_deg": .init(points: ["canthus_inner_l", "canthus_outer_l", "canthus_inner_r", "canthus_outer_r"], segments: [("canthus_inner_l", "canthus_outer_l"), ("canthus_inner_r", "canthus_outer_r")], angle: nil, pose: .frontal),
        "intercanthal_to_width_ratio": .init(points: ["canthus_inner_l", "canthus_inner_r", "zygion_l", "zygion_r"], segments: [("canthus_inner_l", "canthus_inner_r"), ("zygion_l", "zygion_r")], angle: nil, pose: .frontal),
        "eye_width_to_intercanthal": .init(points: ["canthus_inner_l", "canthus_outer_l", "canthus_inner_r", "canthus_outer_r"], segments: [("canthus_outer_l", "canthus_inner_l"), ("canthus_inner_l", "canthus_inner_r"), ("canthus_inner_r", "canthus_outer_r")], angle: nil, pose: .frontal),
        "lower_third_split": .init(points: ["subnasale", "stomion", "menton"], segments: [("subnasale", "stomion"), ("stomion", "menton")], angle: nil, pose: .frontal),
        "midface_ratio": .init(points: ["pupil_l", "pupil_r", "upper_lip_top"], segments: [("pupil_l", "pupil_r")], angle: nil, pose: .frontal),
        "nasal_width_to_intercanthal": .init(points: ["alare_l", "alare_r", "canthus_inner_l", "canthus_inner_r"], segments: [("alare_l", "alare_r"), ("canthus_inner_l", "canthus_inner_r")], angle: nil, pose: .frontal),
        "mouth_width_to_nose": .init(points: ["cheilion_l", "cheilion_r", "alare_l", "alare_r"], segments: [("cheilion_l", "cheilion_r"), ("alare_l", "alare_r")], angle: nil, pose: .frontal),
        "mouth_width_to_interpupillary": .init(points: ["cheilion_l", "cheilion_r", "pupil_l", "pupil_r"], segments: [("cheilion_l", "cheilion_r"), ("pupil_l", "pupil_r")], angle: nil, pose: .frontal),
        "lip_ratio_upper_lower": .init(points: ["labrale_superius", "stomion", "labrale_inferius"], segments: [("labrale_superius", "stomion"), ("stomion", "labrale_inferius")], angle: nil, pose: .frontal),
        "bigonial_to_bizygomatic": .init(points: ["gonion_l", "gonion_r", "zygion_l", "zygion_r"], segments: [("gonion_l", "gonion_r"), ("zygion_l", "zygion_r")], angle: nil, pose: .frontal),
        "chin_width_to_mouth": .init(points: ["chin_lateral_l", "chin_lateral_r", "cheilion_l", "cheilion_r"], segments: [("chin_lateral_l", "chin_lateral_r"), ("cheilion_l", "cheilion_r")], angle: nil, pose: .frontal),
        "bitemporal_to_bizygomatic": .init(points: ["frontotemporale_l", "frontotemporale_r", "zygion_l", "zygion_r"], segments: [("frontotemporale_l", "frontotemporale_r"), ("zygion_l", "zygion_r")], angle: nil, pose: .frontal),
        "face_height_to_width": .init(points: ["nasion", "menton", "zygion_l", "zygion_r"], segments: [("nasion", "menton"), ("zygion_l", "zygion_r")], angle: nil, pose: .frontal),
        "philtrum_length_ratio": .init(points: ["subnasale", "labrale_superius", "menton"], segments: [("subnasale", "labrale_superius")], angle: nil, pose: .frontal),
        "fwhr": .init(points: ["zygion_l", "zygion_r", "brow_mid", "upper_lip_top"], segments: [("zygion_l", "zygion_r"), ("brow_mid", "upper_lip_top")], angle: nil, pose: .frontal),
        "symmetry_index": .init(points: ["zygion_l", "zygion_r", "gonion_l", "gonion_r", "cheilion_l", "cheilion_r", "canthus_outer_l", "canthus_outer_r"], segments: [("nasion", "menton")], angle: nil, pose: .frontal),
        "nasofrontal_angle_deg": .init(points: ["glabella", "nasion", "pronasale"], segments: [("glabella", "nasion"), ("nasion", "pronasale")], angle: ("nasion", "glabella", "pronasale"), pose: .profile),
        "nasolabial_angle_deg": .init(points: ["columella_point", "subnasale", "labrale_superius"], segments: [("columella_point", "subnasale"), ("subnasale", "labrale_superius")], angle: ("subnasale", "columella_point", "labrale_superius"), pose: .profile),
        "facial_convexity_deg": .init(points: ["glabella", "subnasale", "pogonion"], segments: [("glabella", "subnasale"), ("subnasale", "pogonion")], angle: ("subnasale", "glabella", "pogonion"), pose: .profile),
        "mentolabial_angle_deg": .init(points: ["labrale_inferius", "sulcus_mentolabialis", "pogonion"], segments: [("labrale_inferius", "sulcus_mentolabialis"), ("sulcus_mentolabialis", "pogonion")], angle: ("sulcus_mentolabialis", "labrale_inferius", "pogonion"), pose: .profile),
        "chin_projection_eline_mm": .init(points: ["pronasale", "pogonion", "labrale_inferius"], segments: [("pronasale", "pogonion")], angle: nil, pose: .profile),
        "nasal_tip_projection_goode": .init(points: ["alar_crease", "pronasale", "nasion"], segments: [("nasion", "pronasale"), ("alar_crease", "pronasale")], angle: nil, pose: .profile),
    ]
}

/// In-memory only. Built right after a capture from the LAST collected frame; never persisted.
final class SessionStill {
    let image: UIImage?                       // nil when the still could not be made; geometry still draws on the schematic
    let points: [String: CGPoint]             // normalised (0–1) in the image's portrait frame
    let profilePoints: [String: CGPoint]      // sagittal projection of the same anchor points, normalised
    init(image: UIImage?, points: [String: CGPoint], profilePoints: [String: CGPoint]) { self.image = image; self.points = points; self.profilePoints = profilePoints }

    /// Project anchor-space points into a normalised frontal frame (x,y) and a sagittal frame (z,y)
    /// without any camera maths: the mesh is already pose-normalised, so an orthographic view is
    /// exactly the overlay we want. The photo (if present) is only a backdrop and is aligned by the
    /// face bounding box, which is close enough for a visual and never used for a number.
    static func make(from frame: FaceFrame, points: AnatomicalPoints) -> SessionStill {
        let xs = frame.vertices.map(\.x), ys = frame.vertices.map(\.y), zs = frame.vertices.map(\.z)
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max(), let z0 = zs.min(), let z1 = zs.max(), x1 > x0, y1 > y0 else {
            return SessionStill(image: nil, points: [:], profilePoints: [:])
        }
        let pad: Float = 0.12
        func n(_ v: Float, _ lo: Float, _ hi: Float) -> CGFloat { CGFloat((v - lo) / (hi - lo) * (1 - 2 * pad) + pad) }
        var f: [String: CGPoint] = [:], p: [String: CGPoint] = [:]
        for (k, v) in points.p {
            f[k] = CGPoint(x: 1 - n(v.x, x0, x1), y: 1 - n(v.y, y0, y1))          // mirror x so the overlay matches a selfie
            p[k] = CGPoint(x: n(v.z, z0 - 0.02, z1 + 0.02), y: 1 - n(v.y, y0, y1))  // profile: nose to the right
        }
        return SessionStill(image: nil, points: f, profilePoints: p)
    }
}

/// Canonical schematic positions (normalised) for later sessions. Proportions are the reference
/// means in metrics.json for an adult face; this is a diagram, and the UI says so.
enum SchematicFace {
    static let frontal: [String: CGPoint] = [
        "glabella": .init(x: 0.50, y: 0.33), "nasion": .init(x: 0.50, y: 0.38), "pronasale": .init(x: 0.50, y: 0.55), "subnasale": .init(x: 0.50, y: 0.59),
        "alare_l": .init(x: 0.44, y: 0.57), "alare_r": .init(x: 0.56, y: 0.57),
        "canthus_inner_l": .init(x: 0.43, y: 0.40), "canthus_inner_r": .init(x: 0.57, y: 0.40), "canthus_outer_l": .init(x: 0.30, y: 0.39), "canthus_outer_r": .init(x: 0.70, y: 0.39),
        "lid_upper_l": .init(x: 0.365, y: 0.375), "lid_lower_l": .init(x: 0.365, y: 0.415), "lid_upper_r": .init(x: 0.635, y: 0.375), "lid_lower_r": .init(x: 0.635, y: 0.415),
        "pupil_l": .init(x: 0.365, y: 0.395), "pupil_r": .init(x: 0.635, y: 0.395),
        "brow_mid": .init(x: 0.50, y: 0.31), "brow_lower_l": .init(x: 0.365, y: 0.33), "brow_lower_r": .init(x: 0.635, y: 0.33),
        "zygion_l": .init(x: 0.21, y: 0.47), "zygion_r": .init(x: 0.79, y: 0.47), "frontotemporale_l": .init(x: 0.27, y: 0.28), "frontotemporale_r": .init(x: 0.73, y: 0.28),
        "cheilion_l": .init(x: 0.40, y: 0.70), "cheilion_r": .init(x: 0.60, y: 0.70), "labrale_superius": .init(x: 0.50, y: 0.675), "stomion": .init(x: 0.50, y: 0.70), "labrale_inferius": .init(x: 0.50, y: 0.73), "upper_lip_top": .init(x: 0.50, y: 0.665),
        "sulcus_mentolabialis": .init(x: 0.50, y: 0.78), "pogonion": .init(x: 0.50, y: 0.86), "menton": .init(x: 0.50, y: 0.90),
        "gonion_l": .init(x: 0.27, y: 0.75), "gonion_r": .init(x: 0.73, y: 0.75), "chin_lateral_l": .init(x: 0.41, y: 0.85), "chin_lateral_r": .init(x: 0.59, y: 0.85),
        "trichion": .init(x: 0.50, y: 0.10),
    ]
    static let profile: [String: CGPoint] = [
        "trichion": .init(x: 0.52, y: 0.10), "glabella": .init(x: 0.62, y: 0.33), "nasion": .init(x: 0.58, y: 0.38), "pronasale": .init(x: 0.78, y: 0.55),
        "columella_point": .init(x: 0.70, y: 0.585), "subnasale": .init(x: 0.62, y: 0.59), "alar_crease": .init(x: 0.60, y: 0.56),
        "labrale_superius": .init(x: 0.66, y: 0.675), "stomion": .init(x: 0.63, y: 0.70), "labrale_inferius": .init(x: 0.65, y: 0.73),
        "sulcus_mentolabialis": .init(x: 0.60, y: 0.78), "pogonion": .init(x: 0.64, y: 0.86), "menton": .init(x: 0.58, y: 0.91),
        "gonion_l": .init(x: 0.28, y: 0.76), "zygion_l": .init(x: 0.40, y: 0.47), "canthus_outer_l": .init(x: 0.48, y: 0.39),
    ]
    /// A soft outline so the schematic reads as a face and not a scatter of dots.
    static func outline(in rect: CGRect, pose: Pose) -> Path {
        var p = Path()
        if pose == .frontal {
            p.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.17, y: rect.minY + rect.height * 0.08, width: rect.width * 0.66, height: rect.height * 0.86))
        } else {
            let pts: [CGPoint] = ["trichion", "glabella", "nasion", "pronasale", "columella_point", "subnasale", "labrale_superius", "stomion", "labrale_inferius", "sulcus_mentolabialis", "pogonion", "menton"].compactMap { profile[$0] }
            for (i, q) in pts.enumerated() { let pt = CGPoint(x: rect.minX + q.x * rect.width, y: rect.minY + q.y * rect.height); i == 0 ? p.move(to: pt) : p.addLine(to: pt) }
        }
        return p
    }
}

/// The overlay itself. Long-press hides the geometry (and shows the plain still when there is one).
struct MeasurementOverlayView: View {
    let metric: MetricResult
    let still: SessionStill?
    @State private var hidden = false

    private var spec: OverlaySpec? { OverlaySpecs.spec(for: metric.id) }
    private var usingSchematic: Bool { still == nil || still?.points.isEmpty == true }

    var body: some View {
        GeometryReader { g in
            let rect = CGRect(origin: .zero, size: g.size)
            let pose = spec?.pose ?? .frontal
            let pts: [String: CGPoint] = usingSchematic ? (pose == .frontal ? SchematicFace.frontal : SchematicFace.profile)
                                                        : (pose == .frontal ? still!.points : still!.profilePoints)
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous).fill(Tokens.Colors.raised)
                if let img = still?.image, pose == .frontal {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
                } else {
                    SchematicFace.outline(in: rect, pose: pose).stroke(Tokens.Colors.line200, lineWidth: 1.5)
                }
                if !hidden, let spec {
                    Canvas { ctx, _ in
                        func P(_ k: String) -> CGPoint? { pts[k].map { CGPoint(x: $0.x * rect.width, y: $0.y * rect.height) } }
                        let accent = Tokens.Colors.accent
                        for (a, b) in spec.segments { if let pa = P(a), let pb = P(b) { var path = Path(); path.move(to: pa); path.addLine(to: pb); ctx.stroke(path, with: .color(accent), style: StrokeStyle(lineWidth: 2, lineCap: .round)) } }
                        if let ang = spec.angle, let pv = P(ang.0), let pa = P(ang.1), let pb = P(ang.2) {
                            let r: CGFloat = min(rect.width, rect.height) * 0.09
                            let a1 = atan2(pa.y - pv.y, pa.x - pv.x), a2 = atan2(pb.y - pv.y, pb.x - pv.x)
                            var arc = Path(); arc.addArc(center: pv, radius: r, startAngle: .radians(a1), endAngle: .radians(a2), clockwise: Self.clockwise(a1, a2))
                            ctx.stroke(arc, with: .color(accent), lineWidth: 2)
                        }
                        for k in spec.points { if let p = P(k) { ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(accent)) } }
                    }
                    if let v = metric.value {
                        Text(MetricFormat.value(v, unit: metric.metric.unit)).style(TypeStyle.value)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: Tokens.Radius.sm).fill(Tokens.Colors.surface50).overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm).strokeBorder(Tokens.Colors.line200, lineWidth: 1)))
                            .position(x: rect.width - 48, y: 28)
                    }
                }
                if !hidden {
                    Text(Copy.s(usingSchematic ? "metric_detail.schematic_note" : "metric_detail.geometry_note")).style(TypeStyle.caption, color: Tokens.Colors.ink500)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(10)
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.2, pressing: { hidden = $0 }, perform: {})
            .animation(.easeOut(duration: Tokens.Motion.instant), value: hidden)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
    }

    private static func clockwise(_ a1: CGFloat, _ a2: CGFloat) -> Bool {
        var d = a2 - a1
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        return d < 0
    }
}
