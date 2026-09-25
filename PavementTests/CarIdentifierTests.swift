import CoreGraphics
import Vision
import CoreML
import Foundation
import ImageIO
import Testing
@testable import Pavement

private final class BundleToken {}

struct CarIdentifierTests {
    let identifier: CarIdentifier
    let catalog: CarCatalog
    init() throws {
        identifier = try CarIdentifier()
        catalog = try CarCatalog.bundled()
    }

    @Test("Every recognizable model is in the catalog, and the quick label list matches the model")
    func labelsInCatalog() {
        // The recognizer is split across experts, so this also proves every expert was found and
        // read: if one failed to load, the count would quietly drop to the other expert's cars.
        #expect(identifier.knownCarIDs.count >= 350)
        #expect(Set(identifier.knownCarIDs) == CarIdentifier.recognizableIDs)
        for id in identifier.knownCarIDs {
            #expect(catalog.car(id: id) != nil, "\(id) isn't in the catalog")
        }
    }

    @Test("The weights file matches the list of cars it is supposed to score")
    func weightsMatchCars() throws {
        // The head is a raw binary: a header, then one row of weights per car, then one bias each.
        // If it ever disagreed with the car list, every car would be scored as the wrong one, and
        // nothing else in the app would notice.
        let binURL = try #require(Bundle.main.url(forResource: "CarHead", withExtension: "bin"))
        let jsonURL = try #require(Bundle.main.url(forResource: "CarHead", withExtension: "json"))
        let ids = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: jsonURL)) as? [String])
        let data = try Data(contentsOf: binURL)
        let header = data.withUnsafeBytes { $0.loadUnaligned(as: SIMD2<Int32>.self) }
        let dims = Int(header.x), count = Int(header.y)
        #expect(count == ids.count, "\(count) rows of weights for \(ids.count) cars")
        #expect(dims == 768, "Vision's revision 2 feature print is 768 numbers; got \(dims)")
        #expect(data.count == 8 + (dims * count + count) * 4, "weights file is the wrong length")
        #expect(Set(ids).count == ids.count, "a car is listed twice")
    }

    @Test("Scores form a probability distribution over every car")
    func scoresAreProbabilities() throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "street01", withExtension: "jpg"))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        // Asking for every car back, the confidences must sum to 1: that is what makes the
        // confidence floor mean "how sure, out of everything it could have said".
        let all = try identifier.suggestions(for: image, limit: identifier.knownCarIDs.count)
        #expect(all.count == identifier.knownCarIDs.count)
        let total = all.reduce(Float(0)) { $0 + $1.confidence }
        #expect(abs(total - 1) < 0.01, "confidences summed to \(total)")
        #expect(all.allSatisfy { $0.confidence >= 0 && $0.confidence <= 1 })
    }

    @Test("Returns up to 3 distinct suggestions, best first")
    func suggestionsShape() throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "street01", withExtension: "jpg"))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let suggestions = try identifier.suggestions(for: image)
        #expect(suggestions.count == 3)
        #expect(Set(suggestions.map(\.carID)).count == 3)
        #expect(zip(suggestions, suggestions.dropFirst()).allSatisfy { $0.confidence >= $1.confidence })
    }
}

struct IdentifierViewsTests {
    private func marker() -> CGImage {
        let ctx = CGContext(data: nil, width: 100, height: 50, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 50))
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 50)) // left strip
        return ctx.makeImage()!
    }

    private func redAt(_ img: CGImage, x: Int) -> Bool {
        var px = [UInt8](repeating: 0, count: img.width * img.height * 4)
        let ctx = CGContext(data: &px, width: img.width, height: img.height, bitsPerComponent: 8, bytesPerRow: img.width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
        let i = (img.height / 2 * img.width + x) * 4
        return px[i] > 200 && px[i + 2] < 50
    }

    @Test("Mirrored view flips left and right")
    func mirror() throws {
        let m = try #require(CarIdentifier.mirrored(marker()))
        #expect(redAt(m, x: 95) && !redAt(m, x: 5))
    }

    @Test("Zoomed view is the middle 84%")
    func zoom() throws {
        let z = try #require(CarIdentifier.zoomed(marker()))
        #expect(z.width == 84 && z.height == 42)
    }
}

private extension Array {
    /// Every unordered pair, for checking each expert against each other expert.
    func combinations() -> [(Element, Element)] {
        indices.flatMap { i in self[(i + 1)...].map { (self[i], $0) } }
    }
}

