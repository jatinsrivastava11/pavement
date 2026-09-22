import CoreGraphics
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

    @Test("Knows the 22 pilot models, and every one is in the catalog")
    func labelsInCatalog() {
        #expect(identifier.knownCarIDs.count == 22)
        for id in identifier.knownCarIDs {
            #expect(catalog.car(id: id) != nil, "\(id) isn't in the catalog")
        }
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
