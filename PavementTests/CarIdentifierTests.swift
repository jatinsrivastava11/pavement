import CoreGraphics
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
        #expect(identifier.knownCarIDs.count >= 150)
        #expect(Set(identifier.knownCarIDs) == CarIdentifier.recognizableIDs)
        for id in identifier.knownCarIDs {
            #expect(catalog.car(id: id) != nil, "\(id) isn't in the catalog")
        }
    }

    /// The cars each bundled expert was taught.
    private func carsPerExpert() throws -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for (group, name) in CarIdentifier.groups {
            let url = try #require(Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
                                   "expert \(name) is missing from the app")
            let model = try MLModel(contentsOf: url)
            let labels = try #require(model.modelDescription.classLabels as? [String])
            result[group] = Set(labels).subtracting([CarIdentifier.otherLabel])
        }
        return result
    }

    @Test("Every expert is bundled, and no car is taught to two of them")
    func expertsAreDisjoint() throws {
        // If a car were taught to two experts, the router's choice would stop mattering for it and
        // the split would not be buying anything. This also proves each expert file is present and
        // loadable: a missing one would otherwise just quietly shrink the recognizer.
        let cars = try carsPerExpert()
        #expect(cars.count == CarIdentifier.groups.count)
        for (group, ids) in cars {
            #expect(!ids.isEmpty, "the \(group) expert knows no cars")
        }
        for (a, b) in cars.keys.sorted().combinations() {
            let shared = cars[a]!.intersection(cars[b]!)
            #expect(shared.isEmpty, "\(shared.sorted()) taught to both \(a) and \(b)")
        }
    }

    @Test("Each expert's cars really are of the body shapes it was meant to learn")
    func expertsMatchTheirBodyStyles() throws {
        // The router decides by body shape, so an expert holding a car of the wrong shape would be
        // unreachable for that car however confident it was.
        for (group, ids) in try carsPerExpert() {
            let expected = try #require(CarIdentifier.bodyStyles[group], "no body styles listed for \(group)")
            for id in ids {
                let body = try #require(catalog.car(id: id)?.body.rawValue, "\(id) isn't in the catalog")
                #expect(expected.contains(body), "\(id) is a \(body) but is taught to the \(group) expert")
            }
        }
    }

    @Test("The router answers with one of the groups the app has an expert for")
    func routerPicksAKnownGroup() throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "street01", withExtension: "jpg"))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let routed = try identifier.route(image)
        let route = try #require(routed, "the router refused to pick any group")
        #expect(CarIdentifier.groups.keys.contains(route.group), "unknown group \(route.group)")
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
