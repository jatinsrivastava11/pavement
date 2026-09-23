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
        #expect(identifier.knownCarIDs.count >= 70)
        #expect(Set(identifier.knownCarIDs) == CarIdentifier.recognizableIDs)
        for id in identifier.knownCarIDs {
            #expect(catalog.car(id: id) != nil, "\(id) isn't in the catalog")
        }
    }

    @Test("Each expert covers its own group of cars, and the two do not overlap")
    func expertsAreDisjoint() throws {
        // "Tall" cars (SUVs, pickups, vans, wagons) and "low" ones (saloons, hatchbacks, coupés)
        // must be learned by different experts: if a car appeared in both, the router's choice
        // would stop mattering and the split would not be buying anything.
        var carsPerExpert: [String: Set<String>] = [:]
        for (group, name) in CarIdentifier.groups {
            let url = try #require(Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
                                   "expert \(name) is missing from the app")
            let model = try MLModel(contentsOf: url)
            let labels = try #require(model.modelDescription.classLabels as? [String])
            carsPerExpert[group] = Set(labels).subtracting([CarIdentifier.otherLabel])
        }
        #expect(carsPerExpert.count == CarIdentifier.groups.count)
        let tall = try #require(carsPerExpert["tall"]), low = try #require(carsPerExpert["low"])
        #expect(!tall.isEmpty && !low.isEmpty)
        #expect(tall.isDisjoint(with: low), "a car is taught to both experts: \(tall.intersection(low).sorted())")

        // And each expert's cars should really be of its own body shape.
        let tallBodies: Set = ["suv", "pickup", "van", "wagon"]
        for id in tall {
            let body = try #require(catalog.car(id: id)?.body.rawValue)
            #expect(tallBodies.contains(body), "\(id) is a \(body) but is taught to the tall expert")
        }
        for id in low {
            let body = try #require(catalog.car(id: id)?.body.rawValue)
            #expect(!tallBodies.contains(body), "\(id) is a \(body) but is taught to the low expert")
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
