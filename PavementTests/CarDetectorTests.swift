import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Pavement

private final class BundleToken {}

private func fixture(_ name: String) throws -> CGImage {
    let url = try #require(Bundle(for: BundleToken.self).url(forResource: name, withExtension: "jpg"))
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
}

struct CarDetectorMergeTests {
    private func d(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: Float) -> CarDetector.Detection {
        .init(box: CGRect(x: x, y: y, width: w, height: h), confidence: c, label: "car")
    }

    @Test("Duplicate boxes of one car merge into the most confident one")
    func mergesDuplicates() {
        let merged = CarDetector.merge([d(0.1, 0.1, 0.2, 0.2, 0.5), d(0.11, 0.1, 0.19, 0.2, 0.9)])
        #expect(merged.count == 1)
        #expect(merged.first?.confidence == 0.9)
    }

    @Test("Two cars side by side stay separate")
    func keepsNeighbours() {
        let merged = CarDetector.merge([d(0.1, 0.1, 0.2, 0.2, 0.8), d(0.28, 0.1, 0.2, 0.2, 0.7)])
        #expect(merged.count == 2)
    }

    @Test("A tile that saw only part of a big car doesn't become a second car")
    func partInsideBigCar() {
        let merged = CarDetector.merge([d(0.3, 0.3, 0.3, 0.3, 0.9), d(0.35, 0.4, 0.08, 0.06, 0.6)])
        #expect(merged.count == 1)
    }

    @Test("A small car further back, only half behind a big car's box, stays separate")
    func smallCarBehind() {
        let merged = CarDetector.merge([d(0.3, 0.3, 0.3, 0.3, 0.9), d(0.55, 0.25, 0.1, 0.08, 0.6)])
        #expect(merged.count == 2)
    }

    @Test("A box cut by an inner tile edge is dropped; one at the photo edge is kept")
    func tileEdges() {
        let innerTile = CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)
        #expect(CarDetector.isCutByTileEdge(CGRect(x: 0, y: 0.4, width: 0.2, height: 0.2), region: innerTile))
        let cornerTile = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        #expect(!CarDetector.isCutByTileEdge(CGRect(x: 0, y: 0.4, width: 0.2, height: 0.2), region: cornerTile))
    }

    @Test("Grid covers the whole photo: full frame + 9 tiles")
    func regions() {
        let r = CarDetector.regions(gridSize: 3)
        #expect(r.count == 10)
        #expect(r.map(\.maxX).max()! >= 0.999 && r.map(\.maxY).max()! >= 0.999)
    }
}

/// Real public-domain photos (see Fixtures/Streets/CREDITS.md). Expected counts are by eye;
/// the floors are what the detector must reach, not the true totals.
struct CarDetectorPhotoTests {
    let detector: CarDetector
    init() throws { detector = try CarDetector() }

    @Test("Finds cars in real photos", arguments: [
        ("street01", 5),   // Yellowstone road: ~6 cars
        ("street05", 8),   // apartment lot: ~11, some small and far
        ("street16", 4),   // tree-lined street: ~6, all tiny and distant
        ("street02", 12),  // traffic jam: ~30, heavily overlapping
    ])
    func findsCars(name: String, minimum: Int) throws {
        let found = try detector.detect(in: fixture(name))
        #expect(found.count >= minimum, "\(name): found \(found.count), need \(minimum)")
    }

    @Test("Finds the big white Tahoe cut off by the right edge of the traffic-jam photo")
    func bigCarAtEdge() throws {
        let found = try detector.detect(in: fixture("street02"))
        #expect(found.contains { $0.box.minX > 0.6 && $0.box.midY > 0.5 && $0.box.width * $0.box.height > 0.1 })
    }

    @Test("The apartment lot isn't flooded with duplicates (~11 cars by eye)")
    func noDuplicateFlood() throws {
        let n = try detector.detect(in: fixture("street05")).count
        #expect((8...14).contains(n), "\(n)")
    }

    @Test("Finds nothing in a photo with no cars (Milky Way)")
    func noCars() throws {
        #expect(try detector.detect(in: fixture("street15")).isEmpty)
    }

    @Test("Boxes are in the top-left coordinate space and inside the photo")
    func boxesInsidePhoto() throws {
        for d in try detector.detect(in: fixture("street01")) {
            #expect(d.box.minX >= 0 && d.box.maxX <= 1 && d.box.minY >= 0 && d.box.maxY <= 1, "\(d.box)")
        }
        // The ranger truck sits in the upper-middle of this photo, so its box centre is above y = 0.7.
        let found = try detector.detect(in: fixture("street01"))
        #expect(found.contains { $0.box.midY < 0.7 })
    }
}
