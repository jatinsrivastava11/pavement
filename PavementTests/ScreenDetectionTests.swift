import Foundation
import Testing
@testable import Pavement

/// Repeatable pseudo-random numbers, so noisy test images are identical on every run.
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    /// Uniform in -1...1.
    mutating func next() -> Float {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Float(state >> 40) / Float(1 << 23) - 1
    }
}

private let w = 160, h = 120

/// Builds a depth map in meters from a function of normalized (x, y), plus relative noise.
private func depthMap(noise: Float = 0.015, seed: UInt64 = 1, _ z: (Float, Float) -> Float) -> [Float] {
    var rng = SeededRandom(seed: seed)
    return (0..<(w * h)).map { i in
        let x = Float(i % w) / Float(w - 1), y = Float(i / w) / Float(h - 1)
        let d = z(x, y)
        return d * (1 + noise * rng.next())
    }
}

private func image(noise: Float = 0.02, seed: UInt64 = 2, _ v: (Int, Int) -> Float) -> [Float] {
    var rng = SeededRandom(seed: seed)
    return (0..<(w * h)).map { i in v(i % w, i / w) * (1 + noise * rng.next()) }
}

struct DepthFlatnessCheckTests {
    let check = DepthFlatnessCheck()

    @Test("Monitor straight on at 60 cm is a screen")
    func flatScreen() {
        let r = check.evaluate(depth: depthMap { _, _ in 0.6 }, width: w, height: h)
        #expect(r.verdict == .likelyScreen)
    }

    @Test("Laptop screen tilted away (50–90 cm) is still a screen")
    func tiltedScreen() {
        let r = check.evaluate(depth: depthMap { x, y in 0.5 + 0.25 * x + 0.15 * y }, width: w, height: h)
        #expect(r.verdict == .likelyScreen)
    }

    @Test("Street scene: road, a car and buildings behind is real")
    func streetScene() {
        let r = check.evaluate(depth: depthMap { x, y in
            if y < 0.35 { return 30 }                                    // buildings / sky
            if (0.3...0.7).contains(x) && (0.4...0.8).contains(y) { return 6 } // the car
            return 2 + (1 - y) * 25                                      // road getting farther away
        }, width: w, height: h)
        #expect(r.verdict == .likelyReal)
    }

    @Test("Parked car at 1.5 m with the street behind it is real")
    func closeCarWithBackground() {
        let r = check.evaluate(depth: depthMap { x, y in
            if y < 0.3 { return 12 }                                     // background above the roof
            return 1.5 + 0.4 * (x - 0.5) * (x - 0.5)                    // curved body panel
        }, width: w, height: h)
        #expect(r.verdict == .likelyReal)
    }

    @Test("A flat wall 5 m away is not called a screen (too far to judge)")
    func farFlatSurface() {
        let r = check.evaluate(depth: depthMap { _, _ in 5 }, width: w, height: h)
        #expect(r.verdict == .likelyReal)
    }

    @Test("Mostly missing depth is inconclusive")
    func missingDepth() {
        var values = depthMap { _, _ in 0.6 }
        for i in values.indices where i % 10 != 0 { values[i] = .nan }
        #expect(check.evaluate(depth: values, width: w, height: h).verdict == .inconclusive)
    }

    @Test("Heavier sensor noise on a screen still reads as a screen")
    func noisyScreen() {
        let r = check.evaluate(depth: depthMap(noise: 0.04, seed: 9) { _, _ in 0.8 }, width: w, height: h)
        #expect(r.verdict == .likelyScreen)
    }
}

struct ScreenPatternCheckTests {
    let check = ScreenPatternCheck()

    @Test("Horizontal refresh banding is detected")
    func refreshBanding() {
        let img = image { _, y in 0.5 * (1 + 0.04 * sin(Float(y) * 2 * .pi / 8)) }
        #expect(check.evaluate(luminance: img, width: w, height: h).looksLikeScreen)
    }

    @Test("Vertical moiré stripes over a gradient are detected")
    func moire() {
        let img = image { x, y in (0.3 + 0.4 * Float(y) / Float(h)) * (1 + 0.03 * sin(Float(x) * 2 * .pi / 5)) }
        #expect(check.evaluate(luminance: img, width: w, height: h).looksLikeScreen)
    }

    @Test("Plain sky-to-road gradient with sensor noise is not a screen")
    func naturalGradient() {
        let img = image { _, y in 0.8 - 0.5 * Float(y) / Float(h) }
        #expect(!check.evaluate(luminance: img, width: w, height: h).looksLikeScreen)
    }

    @Test("Blocky street scene (sky, building, car, road) is not a screen")
    func blockyScene() {
        let img = image(seed: 5) { x, y in
            if y < 40 { return 0.9 }
            if (50..<110).contains(x) && (55..<95).contains(y) { return 0.2 }
            if x < 30 && y < 90 { return 0.55 }
            return 0.4
        }
        #expect(!check.evaluate(luminance: img, width: w, height: h).looksLikeScreen)
    }
}

struct ScreenDetectorTests {
    let detector = ScreenDetector()
    let plain = image { _, y in 0.8 - 0.5 * Float(y) / Float(h) }
    let banded = image { _, y in 0.5 * (1 + 0.04 * sin(Float(y) * 2 * .pi / 8)) }
    let screenDepth = depthMap { _, _ in 0.6 }
    let streetDepth = depthMap { _, y in y < 0.4 ? 30 : 2 + (1 - y) * 25 }

    @Test("Flat close depth rejects even without stripes")
    func depthRejects() {
        let r = detector.evaluate(depth: (screenDepth, w, h), luminance: plain, width: w, height: h)
        #expect(r.decision == .reject(reason: ScreenDetector.screenMessage))
    }

    @Test("Real depth accepts even if stripes appear (a fence, blinds)")
    func depthOverridesStripes() {
        let r = detector.evaluate(depth: (streetDepth, w, h), luminance: banded, width: w, height: h)
        #expect(r.decision == .accept)
    }

    @Test("Without depth, stripes reject")
    func stripesRejectWithoutDepth() {
        let r = detector.evaluate(depth: nil, luminance: banded, width: w, height: h)
        #expect(r.decision == .reject(reason: ScreenDetector.screenMessage))
    }

    @Test("Without depth and without stripes, the photo is accepted")
    func acceptsPlainWithoutDepth() {
        #expect(detector.evaluate(depth: nil, luminance: plain, width: w, height: h).decision == .accept)
    }
}
