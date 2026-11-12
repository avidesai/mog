import Foundation
import ARKit
import CoreVideo
import simd

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
        // Face bounding box in buffer coordinates (same transform as LumaStats).
        let size = CGSize(width: w, height: h)
        func project(_ p: SIMD3<Float>) -> (Int, Int) {
            let wp = face.transform * SIMD4<Float>(p, 1)
            let q = camera.projectPoint(SIMD3(wp.x, wp.y, wp.z), orientation: .portrait, viewportSize: size)
            return (max(0, min(w - 1, Int(q.y))), max(0, min(h - 1, w - 1 - Int(q.x))))   // (bx, by) in landscape buffer
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
