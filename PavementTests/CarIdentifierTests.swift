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
