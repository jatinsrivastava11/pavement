import SwiftUI
import Testing
import UIKit
@testable import Pavement

@MainActor
struct ShareCardTests {
    let car = CarModel(id: "ferrari-f40", make: "Ferrari", model: "F40", tier: .exotic, engine: .v8, body: .supercar, approxBuilt: 1315)

    @Test("Renders a 1080×1350 image")
    func size() throws {
        let image = try #require(ShareCardView(car: car, photo: nil, city: "Chicago").render())
        #expect(image.size == ShareCardView.size)
    }

    @Test("The rendered card isn't blank: it has many distinct colors")
    func notBlank() throws {
        let image = try #require(ShareCardView(car: car, photo: nil, city: nil).render()?.cgImage)
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var colors = Set<UInt32>()
        for i in stride(from: 0, to: pixels.count, by: 4 * 97) {
            colors.insert(UInt32(pixels[i]) << 16 | UInt32(pixels[i + 1]) << 8 | UInt32(pixels[i + 2]))
        }
        #expect(colors.count > 50)
    }

    @Test("Shows the city at most, never coordinates")
    func privacy() {
        let card = ShareCardView(car: car, photo: nil, city: "Chicago")
        #expect(card.visibleText.contains("Chicago"))
        #expect(!card.visibleText.contains { $0.range(of: #"-?\d+\.\d{3,}"#, options: .regularExpression) != nil })
    }
}
