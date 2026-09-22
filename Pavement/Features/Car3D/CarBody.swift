import CoreGraphics
import Foundation
import UIKit

/// Which Kenney car model represents each body style.
enum CarBody {
    static func modelName(for body: BodyStyle, tier: RarityTier) -> String {
        switch body {
        case .sedan, .wagon: "kenney-sedan"
        case .coupe, .convertible, .supercar: "kenney-sedan-sports"
        case .hatchback: "kenney-hatchback-sports"
        case .suv: [.legendary, .exotic, .rare].contains(tier) ? "kenney-suv-luxury" : "kenney-suv"
        case .pickup: "kenney-truck"
        case .van: "kenney-van"
        }
    }

    static func mesh(named name: String, in bundle: Bundle = .main) throws -> OBJMesh {
        guard let url = bundle.url(forResource: name, withExtension: "carmesh", subdirectory: nil)
                ?? bundle.url(forResource: name, withExtension: "carmesh", subdirectory: "Cars3D") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try OBJMesh(text: String(contentsOf: url, encoding: .utf8))
    }
}

/// The main paint color of a car in a photo crop: the most common strongly colored hue in the
/// middle of the crop, or a grey/white/black if the car isn't colorful.
enum CarColor {
    static func dominant(in image: CGImage) -> UIColor {
        let size = 48
        var px = [UInt8](repeating: 0, count: size * size * 4)
        guard let ctx = CGContext(data: &px, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return .gray }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        var hueBins = [Int](repeating: 0, count: 12)
        var hueSamples = [[UIColor]](repeating: [], count: 12)
        var greys: [CGFloat] = []
        // The middle of the crop, where the body usually is (edges are road and background).
        for y in size / 4..<(size * 3 / 4) {
            for x in size / 6..<(size * 5 / 6) {
                let i = (y * size + x) * 4
                let c = UIColor(red: CGFloat(px[i]) / 255, green: CGFloat(px[i + 1]) / 255, blue: CGFloat(px[i + 2]) / 255, alpha: 1)
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
                c.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
                if s > 0.35 && b > 0.2 {
                    let bin = min(11, Int(h * 12)); hueBins[bin] += 1; hueSamples[bin].append(c)
                } else {
                    greys.append(b)
                }
            }
        }
        let total = hueBins.reduce(0, +) + greys.count
        if let best = hueBins.indices.max(by: { hueBins[$0] < hueBins[$1] }), total > 0,
           Double(hueBins[best]) / Double(total) > 0.2 {
            return average(hueSamples[best])
        }
        let median = greys.sorted()[greys.count / 2]
        return UIColor(white: median, alpha: 1)
    }

    private static func average(_ colors: [UIColor]) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        for c in colors { var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0; c.getRed(&cr, green: &cg, blue: &cb, alpha: nil); r += cr; g += cg; b += cb }
        let n = CGFloat(max(colors.count, 1))
        return UIColor(red: r / n, green: g / n, blue: b / n, alpha: 1)
    }
}
