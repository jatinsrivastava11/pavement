import Foundation

/// Combines the screen checks into one decision for a captured photo.
struct ScreenDetector: Sendable {
    enum Decision: Equatable, Sendable {
        case accept
        case reject(reason: String)
    }

    struct Report: Equatable, Sendable {
        var decision: Decision
        /// `nil` when the phone didn't provide depth (single-camera iPhones).
        var depth: DepthFlatnessCheck.Result?
        var pattern: ScreenPatternCheck.Result
    }

    var depthCheck = DepthFlatnessCheck()
    var patternCheck = ScreenPatternCheck()

    static let screenMessage = "This looks like a photo of a screen. Spot real cars only."

    func evaluate(
        depth: (values: [Float], width: Int, height: Int)?,
        luminance: [Float], width: Int, height: Int
    ) -> Report {
        let depthResult = depth.map { depthCheck.evaluate(depth: $0.values, width: $0.width, height: $0.height) }
        let pattern = patternCheck.evaluate(luminance: luminance, width: width, height: height)

        // Depth is the stronger signal, so a confident "real" from depth overrides the stripe check.
        let decision: Decision = switch depthResult?.verdict {
        case .likelyScreen: .reject(reason: Self.screenMessage)
        case .likelyReal: .accept
        case .inconclusive, nil: pattern.looksLikeScreen ? .reject(reason: Self.screenMessage) : .accept
        }
        return Report(decision: decision, depth: depthResult, pattern: pattern)
    }
}
