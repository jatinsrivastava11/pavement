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

/// Builds a w×h image whose top-left pixel is red and the rest blue, to check orientation.
private func marker(width: Int, height: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: height - 1, width: 1, height: 1)) // top-left
    return ctx.makeImage()!
}

private func isRed(_ image: CGImage, x: Int, y: Int) -> Bool {
    let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
    let i = (y * image.width + x) * 4          // memory rows run top to bottom
    return p[i] > 200 && p[i + 2] < 50
}

struct SpotPipelineTests {
    @Test("Finds the cars in a real photo, each with catalog suggestions and a real crop")
    func realPhoto() throws {
        let catalog = try CarCatalog.bundled()
        let pipeline = try SpotPipeline(catalog: catalog)
        let cars = try pipeline.run(on: fixture("street01"))
        #expect(cars.count >= 4)
        for car in cars {
            #expect(!car.suggestions.isEmpty)
            #expect(car.suggestions.allSatisfy { catalog.car(id: $0.carID) != nil })
            #expect(car.crop.width >= 8 && car.crop.height >= 8)
        }
        // Biggest car first.
        let areas = cars.map { $0.box.width * $0.box.height }
        #expect(areas == areas.sorted(by: >))
    }

    @Test("Crop stays inside the photo even for a box at the edge")
    func cropAtEdge() throws {
        let image = marker(width: 200, height: 100)
        let crop = try #require(SpotPipeline.crop(image, to: CGRect(x: 0.9, y: 0.9, width: 0.1, height: 0.1)))
        #expect(crop.width <= 22 && crop.height <= 12)   // margin is clipped at the photo edge (+1 px rounding)
        // Too small to identify: skipped.
        #expect(SpotPipeline.crop(image, to: CGRect(x: 0.5, y: 0.5, width: 0.02, height: 0.02)) == nil)
    }

    @Test("Camera photos (rotated 'right') become upright portrait images")
    func uprightRight() throws {
        // A phone held upright produces a landscape sensor image tagged .right.
        let sensor = marker(width: 40, height: 30)
        let upright = try #require(sensor.upright(orientation: .right))
        #expect(upright.width == 30 && upright.height == 40)
        // The sensor's top-left corner ends up at the top-right after rotating 90° clockwise.
        #expect(isRed(upright, x: 29, y: 0))
    }

    @Test("Already-upright images are unchanged")
    func uprightUp() throws {
        let image = marker(width: 40, height: 30)
        let same = try #require(image.upright(orientation: .up))
        #expect(isRed(same, x: 0, y: 0))
    }
}
