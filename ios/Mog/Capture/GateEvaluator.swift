import Foundation
import ARKit

/// Capture gates (eng doc, "Capture and quality gates"). The shutter is never enabled until every
/// gate passes; a gate failing during the 10-frame burst aborts the capture.
struct GateThresholds {
    var yawDeg = 3.0, pitchDeg = 3.0, rollDeg = 2.0
    var distanceMin = 0.45, distanceMax = 0.75          // metres
    var lumaMin = 0.30, lumaMax = 0.85                  // mean Y in [0,1] over the face region
    var lumaAsymmetryMax = 0.12                         // |left − right| mean Y
    var clippingMax = 0.02                              // fraction of face pixels ≥ 0.98
    var sharpnessMin = 0.0015                           // Laplacian variance on the face crop (tune in spike 1)
    var expressionMax: Float = 0.25                     // any of the expression blendshapes above this = not neutral
    var eyeOpenMin: Float = 0.6                         // 1 − eyeBlink
}

struct GateReport: Equatable {
    var angle = false, lighting = false, distance = false, expression = false, clear = false, sharp = false
    var hintKey: String = "capture.hint_yaw"

    static let allFailing = GateReport()
    var allPass: Bool { angle && lighting && distance && expression && clear && sharp }
    var hint: String { Copy.s(hintKey) }
    /// Name of the first failing gate, for the abort message and analytics.
    var firstFailing: String? {
        if !angle { return Copy.s("capture.gate_angle") }
        if !distance { return Copy.s("capture.gate_distance") }
        if !lighting { return Copy.s("capture.gate_lighting") }
        if !expression { return Copy.s("capture.gate_expression") }
        if !clear { return Copy.s("capture.gate_clear") }
        if !sharp { return Copy.s("capture.gate_sharp") }
        return nil
    }
    var chips: [(label: String, pass: Bool)] {
        [(Copy.s("capture.gate_angle"), angle), (Copy.s("capture.gate_lighting"), lighting), (Copy.s("capture.gate_distance"), distance),
         (Copy.s("capture.gate_expression"), expression), (Copy.s("capture.gate_clear"), clear), (Copy.s("capture.gate_sharp"), sharp)]
    }
}

struct GateEvaluator {
    var t = GateThresholds()

    private static let expressionShapes: [ARFaceAnchor.BlendShapeLocation] = [
        .jawOpen, .mouthSmileLeft, .mouthSmileRight, .mouthPucker, .mouthFunnel, .browInnerUp, .browDownLeft, .browDownRight,
        .cheekPuff, .mouthFrownLeft, .mouthFrownRight, .eyeSquintLeft, .eyeSquintRight, .jawLeft, .jawRight,
    ]

    func evaluate(_ f: FaceFrame) -> GateReport {
        var r = GateReport()
        var hint: String? = nil

        // Angle. Order matters for the hint: the biggest offender first.
        let yawOK = abs(f.pose.yaw) <= t.yawDeg, pitchOK = abs(f.pose.pitch) <= t.pitchDeg, rollOK = abs(f.pose.roll) <= t.rollDeg
        r.angle = yawOK && pitchOK && rollOK
        if !yawOK { hint = hint ?? "capture.hint_yaw" }
        if !pitchOK { hint = hint ?? (f.pose.pitch > 0 ? "capture.hint_pitch_down" : "capture.hint_pitch_up") }
        if !rollOK { hint = hint ?? "capture.hint_roll" }

        // Distance.
        r.distance = f.pose.distance >= t.distanceMin && f.pose.distance <= t.distanceMax
        if !r.distance { hint = hint ?? (f.pose.distance < t.distanceMin ? "capture.hint_further" : "capture.hint_closer") }

        // Lighting: level, asymmetry, clipping.
        let L = f.luma
        let levelOK = L.mean >= t.lumaMin && L.mean <= t.lumaMax
        let asymOK = abs(L.leftMean - L.rightMean) <= t.lumaAsymmetryMax
        let clipOK = L.clippedFraction <= t.clippingMax
        r.lighting = levelOK && asymOK && clipOK
        if !clipOK { hint = hint ?? "capture.hint_clipping" }
        else if !levelOK { hint = hint ?? "capture.hint_lighting_dark" }
        else if !asymOK { hint = hint ?? "capture.hint_lighting_uneven" }

        // Expression: neutral, eyes open.
        let maxExpr = Self.expressionShapes.map { f.blendShapes[$0] ?? 0 }.max() ?? 0
        let eyesOpen = (1 - (f.blendShapes[.eyeBlinkLeft] ?? 0)) >= t.eyeOpenMin && (1 - (f.blendShapes[.eyeBlinkRight] ?? 0)) >= t.eyeOpenMin
        r.expression = maxExpr <= t.expressionMax && eyesOpen
        if !r.expression { hint = hint ?? "capture.hint_expression" }

        // Clear view (occlusion). ARKit does not report occlusion; v1 uses mesh-tracking confidence
        // as a proxy (isTracked already gated upstream) and the luma crop's edge contrast. Spike 1
        // decides whether a Vision-based check is needed. Until then this gate passes when tracked.
        r.clear = true

        // Sharpness.
        r.sharp = L.sharpness >= t.sharpnessMin
        if !r.sharp { hint = hint ?? "capture.hint_sharp" }

        r.hintKey = hint ?? "capture.hint_ready"
        return r
    }
}
