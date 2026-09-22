import Foundation

/// Looks for the regular stripes a camera picks up from a screen: refresh-rate banding and moiré.
///
/// Weaker than the depth check. Real scenes rarely contain perfectly repeating fine stripes, but
/// fences, blinds and grilles can, and a sharp, bright screen may show no stripes at all. It works on
/// every iPhone, so it's used as a backup.
struct ScreenPatternCheck: Sendable {
    struct Result: Equatable, Sendable {
        /// 0 = no repeating stripes, 1 = perfectly regular stripes.
        var stripeScore: Float
        /// Strength of the stripes relative to overall brightness.
        var stripeContrast: Float
        var looksLikeScreen: Bool
    }

    var minStripeScore: Float = 0.5
    var minStripeContrast: Float = 0.01
    /// Stripe periods (in pixels) considered: finer than this is sensor noise, coarser is scenery.
    var periodRange = 4...40

    /// - Parameter luminance: row-major brightness values (any scale), `width × height`.
    func evaluate(luminance: [Float], width: Int, height: Int) -> Result {
        precondition(luminance.count == width * height, "luminance size doesn't match width × height")
        var rows = [Float](repeating: 0, count: height)
        var cols = [Float](repeating: 0, count: width)
        for r in 0..<height {
            for c in 0..<width {
                let v = luminance[r * width + c]
                rows[r] += v
                cols[c] += v
            }
        }
        for r in rows.indices { rows[r] /= Float(width) }
        for c in cols.indices { cols[c] /= Float(height) }

        let a = Self.periodicity(of: rows, periods: periodRange)
        let b = Self.periodicity(of: cols, periods: periodRange)
        let best = a.score >= b.score ? a : b
        return Result(
            stripeScore: best.score,
            stripeContrast: best.contrast,
            looksLikeScreen: best.score >= minStripeScore && best.contrast >= minStripeContrast
        )
    }

    /// Removes slow brightness changes, then finds the strongest repeating period.
    private static func periodicity(of profile: [Float], periods: ClosedRange<Int>) -> (score: Float, contrast: Float) {
        let n = profile.count
        // Moving-average half-width: covers the longest period, but shrinks for short profiles.
        let half = min(periods.upperBound, (n - 1) / 4)
        guard half >= 8 else { return (0, 0) }

        // Subtract a centred moving average wider than the longest period, leaving only fine
        // detail. Edges without a full window are skipped, so they can't create fake detail.
        var prefix = [Float](repeating: 0, count: n + 1)
        for i in 0..<n { prefix[i + 1] = prefix[i] + profile[i] }
        let detail: [Float] = (half..<(n - half)).map { i in
            profile[i] - (prefix[i + half + 1] - prefix[i - half]) / Float(2 * half + 1)
        }
        let m = detail.count

        let mean = profile.reduce(0, +) / Float(n)
        let energy = detail.reduce(0) { $0 + $1 * $1 }
        guard energy > 0, mean > 0 else { return (0, 0) }
        let contrast = (energy / Float(m)).squareRoot() / mean

        func correlation(_ lag: Int) -> Float {
            guard lag > 0, lag < m else { return 0 }
            var sum: Float = 0
            for i in 0..<(m - lag) { sum += detail[i] * detail[i + lag] }
            return sum / energy * Float(m) / Float(m - lag)
        }

        // A true stripe pattern lines up with itself one period later and is opposite half a
        // period later. Smooth changes (sky, shadows, edges) line up at both, so they score ~0.
        var best: Float = 0
        for period in periods where period >= 4 && period <= half && period * 2 < m {
            let score = (correlation(period) - correlation(period / 2)) / 2
            best = max(best, score)
        }
        return (min(max(best, 0), 1), contrast)
    }
}
