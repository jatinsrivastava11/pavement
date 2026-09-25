import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Pavement

struct CarSizeCheckTests {
    let fov = 50.0          // portrait width FOV of an iPhone main camera, roughly
    let aspect = 4.0 / 3.0  // portrait photo height ÷ width

    @Test("A 1:18 model car 30 cm away is a toy")
    func toyUpClose() {
        let size = CarSizeCheck.estimatedSize(box: CGRect(x: 0.2, y: 0.4, width: 0.6, height: 0.25), distance: 0.3, horizontalFOV: fov, aspect: aspect)
        #expect(size < CarSizeCheck.minRealCarSize, "\(size) m")
    }

    @Test("A real car 6 m away filling half the frame is real (~2.8 m)")
    func realCar() {
        let size = CarSizeCheck.estimatedSize(box: CGRect(x: 0.25, y: 0.4, width: 0.5, height: 0.2), distance: 6, horizontalFOV: fov, aspect: aspect)
        #expect(size > 2 && size < 4, "\(size) m")
    }

    @Test("A mostly hidden car far away still counts as real")
    func partlyHiddenFar() {
        // Only the roof shows over another car: 8% of the width, 30 m away.
        let size = CarSizeCheck.estimatedSize(box: CGRect(x: 0.5, y: 0.5, width: 0.08, height: 0.03), distance: 30, horizontalFOV: fov, aspect: aspect)
        #expect(size >= CarSizeCheck.minRealCarSize, "\(size) m")
    }

    @Test("No depth means no toy verdict (single-camera iPhones)")
    func noDepth() {
        #expect(CarSizeCheck.isToy(box: CGRect(x: 0, y: 0, width: 0.5, height: 0.5), depth: nil, horizontalFOV: fov, aspect: aspect) == nil)
    }

    @Test("Toy verdict from a depth map: toy on a table vs car in a street")
    func fromDepthMap() {
        let box = CGRect(x: 0.3, y: 0.4, width: 0.4, height: 0.2)
        let table = DepthMap(values: .init(repeating: 0.35, count: 40 * 30), width: 40, height: 30)
        let street = DepthMap(values: .init(repeating: 7, count: 40 * 30), width: 40, height: 30)
        #expect(CarSizeCheck.isToy(box: box, depth: table, horizontalFOV: fov, aspect: aspect) == true)
        #expect(CarSizeCheck.isToy(box: box, depth: street, horizontalFOV: fov, aspect: aspect) == false)
    }

    @Test("Median depth ignores missing values and the box edges")
    func median() {
        var values = [Float](repeating: 5, count: 10 * 10)
        values[55] = .nan; values[0] = 0.1   // corner is outside the box's centre
        let d = DepthMap(values: values, width: 10, height: 10).medianDepth(in: CGRect(x: 0, y: 0, width: 1, height: 1))
        #expect(d == 5)
    }

    @Test("Depth rotates the same way as the photo")
    func rotation() {
        // 3 wide × 2 tall, values = index. Rotating 90° clockwise ('right') gives 2 wide × 3 tall.
        let m = DepthMap(values: [0, 1, 2, 3, 4, 5], width: 3, height: 2).upright(orientation: .right)
        #expect(m.width == 2 && m.height == 3)
        // Top row after clockwise rotation is the old left column, bottom-to-top: [3, 0].
        #expect(Array(m.values.prefix(2)) == [3, 0])
        #expect(m.values == [3, 0, 4, 1, 5, 2])
        let back = DepthMap(values: m.values, width: 2, height: 3).upright(orientation: .left)
        #expect(back.values == [0, 1, 2, 3, 4, 5])
    }
}

struct AutoIdentifyTests {
    /// 0.8 comes from a sweep over held-out photographers, 12,319 photos of 356 cars plus 190
    /// photos of models the recognizer was never taught:
    ///
    ///     floor   named right   named wrong   unknown named   right when it speaks
    ///     0.5     6030          1604          102 of 190      78%
    ///     0.8     4111           338           53 of 190      91%
    ///     0.9     3055           131           29 of 190      95%
    ///
    /// Raising it names fewer cars and lies less often, so this number is a product decision about
    /// how often the app is allowed to be wrong, not a technical one. It shouldn't drift silently.
    @Test("The app names cars itself only above the measured confidence floor")
    func floor() throws {
        #expect(CarIdentifier.minConfidence == 0.8)
        #expect(CarIdentifier.minConfidence >= CarIdentifier.agreementConfidence,
                "the first answer should be held to at least the bar its mirrored/zoomed views are")
    }

    /// The simulator's image-feature model returns the same answer for every image, so identification
    /// quality is checked on the Mac instead (Tools/check_identifier.swift). Runs on real devices.
    #if targetEnvironment(simulator)
    static let realHardware = false
    #else
    static let realHardware = true
    #endif

    @Test("A model Pavement doesn't know (the park ranger's Chevy Tahoe) is never named",
          .enabled(if: realHardware, "Simulator gives the same output for every image; see Tools/check_identifier.swift"))
    func unknownModelRejected() throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "street01", withExtension: "jpg"))
        let src = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(src, 0, nil))
        let tahoe = try #require(SpotPipeline.crop(image, to: CGRect(x: 0.44, y: 0.35, width: 0.15, height: 0.18), margin: 0))
        let identifier = try CarIdentifier()
        #expect(try identifier.identify(tahoe) == nil)
        #expect(!identifier.knownCarIDs.contains(CarIdentifier.otherLabel))
    }

    @Test("Pipeline never offers choices: each car is identified, unidentified, or a toy")
    func verdicts() throws {
        let catalog = try CarCatalog.bundled()
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "street01", withExtension: "jpg"))
        let src = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(src, 0, nil))
        let cars = try SpotPipeline(catalog: catalog).run(on: image)
        #expect(!cars.isEmpty)
        for car in cars {
            if case .identified(let id) = car.verdict { #expect(catalog.car(id: id) != nil) }
        }
        // Without depth there's no toy verdict.
        #expect(!cars.contains { $0.verdict == .toy })
    }
}

private final class BundleToken {}
