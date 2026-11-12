import XCTest
import MogCore
@testable import Mog

final class AggregatorTests: XCTestCase {
    func testMedianAndIQR() {
        let frames = (1...10).map { FrameAggregator.PerFrame(metrics: ["m": Double($0)], confidences: ["m": 0.9]) }
        let out = FrameAggregator.aggregate(frames)
        XCTAssertEqual(out["m"]!.value, 5.5)
        XCTAssertEqual(out["m"]!.iqr, 4.5, accuracy: 1e-9)   // numpy: q75 7.75 − q25 3.25
        XCTAssertEqual(out["m"]!.confidence, 0.9, accuracy: 1e-9)
    }
    func testMetricMissingOnMostFramesIsDropped() {
        var frames = (1...10).map { _ in FrameAggregator.PerFrame(metrics: ["a": 1], confidences: ["a": 0.9]) }
        frames[0] = FrameAggregator.PerFrame(metrics: ["a": 1, "b": 2], confidences: ["a": 0.9, "b": 0.9])
        XCTAssertNil(FrameAggregator.aggregate(frames)["b"])
    }
}

final class CopyTests: XCTestCase {
    func testStringsLoadAndSubstitute() {
        XCTAssertEqual(Copy.s("today.title"), "Today")
        XCTAssertEqual(Copy.f("today.scan_countdown", ["days": "12"]), "Next scan opens in 12 days")
        XCTAssertFalse(Copy.s("consent.affirm_label").contains("{app_name}"))
    }
}

final class GateTests: XCTestCase {
    func testAngleGate() {
        let ev = GateEvaluator()
        let good = FaceFrame(timestamp: 0, vertices: [], pose: .init(yaw: 1, pitch: -1, roll: 0.5, distance: 0.55), blendShapes: [:],
                             luma: LumaStats(mean: 0.5, leftMean: 0.5, rightMean: 0.5, clippedFraction: 0, sharpness: 0.01))
        XCTAssertTrue(ev.evaluate(good).allPass)
        let yawed = FaceFrame(timestamp: 0, vertices: [], pose: .init(yaw: 6, pitch: 0, roll: 0, distance: 0.55), blendShapes: [:], luma: good.luma)
        XCTAssertFalse(ev.evaluate(yawed).angle)
        XCTAssertEqual(ev.evaluate(yawed).hintKey, "capture.hint_yaw")
        let close = FaceFrame(timestamp: 0, vertices: [], pose: .init(yaw: 0, pitch: 0, roll: 0, distance: 0.30), blendShapes: [:], luma: good.luma)
        XCTAssertEqual(ev.evaluate(close).hintKey, "capture.hint_further")
    }
    func testExpressionGate() {
        let ev = GateEvaluator()
        let smiling = FaceFrame(timestamp: 0, vertices: [], pose: .init(yaw: 0, pitch: 0, roll: 0, distance: 0.55), blendShapes: [.mouthSmileLeft: 0.6],
                                luma: LumaStats(mean: 0.5, leftMean: 0.5, rightMean: 0.5, clippedFraction: 0, sharpness: 0.01))
        XCTAssertFalse(ev.evaluate(smiling).expression)
    }
}
