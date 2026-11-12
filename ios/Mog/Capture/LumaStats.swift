import Foundation
import ARKit
import CoreVideo
import simd

/// Lighting and sharpness statistics over the face region of the camera frame. Reads only the
/// Y (luma) plane of the 420f pixel buffer, on a coarse stride, so it runs comfortably per frame.
/// No pixels are retained.
struct LumaStats {
    var mean: Double = 0          // [0,1]
    var leftMean: Double = 0
    var rightMean: Double = 0
    var clippedFraction: Double = 0
    var sharpness: Double = 0     // variance of a 4-neighbour Laplacian, normalised

    static let zero = LumaStats()

    static func compute(from pixelBuffer: CVPixelBuffer, face: ARFaceAnchor, camera: ARCamera) -> LumaStats {
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 1 else { return .zero }
        let w = CVPixelBufferGetWidth(pixelBuffer), h = CVPixelBufferGetHeight(pixelBuffer)
        // Project the face anchor origin and a few mesh extremes to get a bounding box in image space.
        let size = CGSize(width: w, height: h)
        func project(_ p: SIMD3<Float>) -> CGPoint {
            let world = face.transform * SIMD4<Float>(p, 1)
            return camera.projectPoint(SIMD3(world.x, world.y, world.z), orientation: .portrait, viewportSize: size)
        }
        let verts = face.geometry.vertices
        guard !verts.isEmpty else { return .zero }
        var minX = CGFloat.greatestFiniteMagnitude, minY = minX, maxX = -minX, maxY = -minX
        for i in stride(from: 0, to: verts.count, by: 40) {
            let q = project(verts[i]); minX = min(minX, q.x); maxX = max(maxX, q.x); minY = min(minY, q.y); maxY = max(maxY, q.y)
        }
        // projectPoint gives portrait-oriented coordinates; the buffer is landscape. Swap axes.
        let x0 = max(0, Int(minY)), x1 = min(w - 1, Int(maxY)), y0 = max(0, Int(w - 1 - Int(maxX))), y1 = min(h - 1, Int(w - 1 - Int(minX)))
        guard x1 > x0 + 8, y1 > y0 + 8 else { return .zero }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return .zero }
        let stride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        let step = max(1, (x1 - x0) / 64)
        var sum = 0.0, sumL = 0.0, sumR = 0.0, n = 0.0, nL = 0.0, nR = 0.0, clipped = 0.0
        var lapSum = 0.0, lapSq = 0.0, lapN = 0.0
        let midY = (y0 + y1) / 2   // left/right halves of the face run along the buffer's y axis in portrait
        var y = y0 + step
        while y < y1 - step {
            var x = x0 + step
            while x < x1 - step {
                let v = Double(ptr[y * stride + x]) / 255.0
                sum += v; n += 1
                if v >= 0.98 { clipped += 1 }
                if y < midY { sumL += v; nL += 1 } else { sumR += v; nR += 1 }
                let lap = 4 * v - Double(ptr[y * stride + x - step]) / 255 - Double(ptr[y * stride + x + step]) / 255
                                - Double(ptr[(y - step) * stride + x]) / 255 - Double(ptr[(y + step) * stride + x]) / 255
                lapSum += lap; lapSq += lap * lap; lapN += 1
                x += step
            }
            y += step
        }
        guard n > 0, lapN > 0 else { return .zero }
        let lapMean = lapSum / lapN
        return LumaStats(mean: sum / n, leftMean: nL > 0 ? sumL / nL : 0, rightMean: nR > 0 ? sumR / nR : 0,
                         clippedFraction: clipped / n, sharpness: lapSq / lapN - lapMean * lapMean)
    }
}
