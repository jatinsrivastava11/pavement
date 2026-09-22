import Foundation

/// Decides whether a depth map looks like a flat screen held close to the camera.
///
/// A real street scene has depth that varies a lot (a car at 4 m, a wall at 20 m). A monitor, TV or
/// phone is a single flat surface, usually within arm's length. The check fits a flat plane to the
/// depth values and measures how far the scene strays from it.
struct DepthFlatnessCheck: Sendable {
    enum Verdict: Equatable, Sendable {
        case likelyScreen
        case likelyReal
        /// Not enough usable depth to decide.
        case inconclusive
    }

    struct Result: Equatable, Sendable {
        var verdict: Verdict
        /// Typical distance to the scene, in meters.
        var medianDepth: Float
        /// Average distance from the best-fit plane, as a fraction of the median depth.
        var relativePlaneError: Float
        var validSampleFraction: Float
    }

    /// Scenes flatter than this (relative to their distance) look like a screen.
    var maxScreenPlaneError: Float = 0.035
    /// Screens are photographed up close. Anything farther away is treated as a real scene,
    /// because iPhone depth becomes too coarse to judge flatness at long range.
    var maxScreenDistance: Float = 2.0
    var minValidFraction: Float = 0.3
    /// Samples at most this many points per side, to keep the check fast.
    var gridSize = 48

    /// - Parameter depth: row-major depth values in meters; zero, negative or non-finite means unknown.
    func evaluate(depth: [Float], width: Int, height: Int) -> Result {
        precondition(depth.count == width * height, "depth size doesn't match width × height")
        guard width > 1, height > 1 else {
            return Result(verdict: .inconclusive, medianDepth: 0, relativePlaneError: 0, validSampleFraction: 0)
        }

        let stepX = max(1, width / gridSize)
        let stepY = max(1, height / gridSize)
        var xs: [Double] = [], ys: [Double] = [], zs: [Double] = []
        var total = 0
        for row in stride(from: 0, to: height, by: stepY) {
            for col in stride(from: 0, to: width, by: stepX) {
                total += 1
                let z = depth[row * width + col]
                guard z.isFinite, z > 0 else { continue }
                xs.append(Double(col) / Double(width - 1))
                ys.append(Double(row) / Double(height - 1))
                zs.append(Double(z))
            }
        }

        let validFraction = Float(zs.count) / Float(max(total, 1))
        guard validFraction >= minValidFraction, zs.count >= 16 else {
            return Result(verdict: .inconclusive, medianDepth: 0, relativePlaneError: 0, validSampleFraction: validFraction)
        }

        let median = Float(zs.sorted()[zs.count / 2])
        guard let plane = Self.fitPlane(xs: xs, ys: ys, zs: zs) else {
            return Result(verdict: .inconclusive, medianDepth: median, relativePlaneError: 0, validSampleFraction: validFraction)
        }

        var absError = 0.0
        for i in zs.indices {
            absError += abs(zs[i] - (plane.a * xs[i] + plane.b * ys[i] + plane.c))
        }
        let relativeError = Float(absError / Double(zs.count)) / median

        let verdict: Verdict = (median <= maxScreenDistance && relativeError <= maxScreenPlaneError)
            ? .likelyScreen : .likelyReal
        return Result(verdict: verdict, medianDepth: median, relativePlaneError: relativeError, validSampleFraction: validFraction)
    }

    /// Least-squares fit of z = a·x + b·y + c.
    private static func fitPlane(xs: [Double], ys: [Double], zs: [Double]) -> (a: Double, b: Double, c: Double)? {
        var sxx = 0.0, sxy = 0.0, syy = 0.0, sx = 0.0, sy = 0.0
        var sxz = 0.0, syz = 0.0, sz = 0.0
        let n = Double(zs.count)
        for i in zs.indices {
            let x = xs[i], y = ys[i], z = zs[i]
            sxx += x * x; sxy += x * y; syy += y * y; sx += x; sy += y
            sxz += x * z; syz += y * z; sz += z
        }
        // Solve the 3×3 normal equations with Cramer's rule.
        let m = [[sxx, sxy, sx], [sxy, syy, sy], [sx, sy, n]]
        let v = [sxz, syz, sz]
        func det(_ m: [[Double]]) -> Double {
            m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
                - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
                + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
        }
        let d = det(m)
        guard abs(d) > 1e-12 else { return nil }
        func replacing(column: Int) -> [[Double]] {
            (0..<3).map { r in (0..<3).map { c in c == column ? v[r] : m[r][c] } }
        }
        return (det(replacing(column: 0)) / d, det(replacing(column: 1)) / d, det(replacing(column: 2)) / d)
    }
}
