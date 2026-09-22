import CoreGraphics
import simd
import UIKit

/// Repaints a car model's body color in its palette texture, leaving windows, lights and tyres alone.
///
/// Kenney's cars use a small palette texture: each part samples one flat color. The body paint is the
/// color covering the most surface area, so we measure that, then swap exactly that color.
enum BodyPaint {
    struct RGB: Hashable { let r, g, b: UInt8 }

    /// Pixels of an image as RGBA bytes (row 0 = top).
    static func pixels(of image: CGImage) -> [UInt8] {
        var px = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let ctx = CGContext(data: &px, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return px
    }

    /// Colors this close (RGB distance, 0–441) count as the same paint.
    static let sameColorDistance: Float = 48

    static func distance(_ a: RGB, _ b: RGB) -> Float {
        simd_distance(SIMD3(Float(a.r), Float(a.g), Float(a.b)), SIMD3(Float(b.r), Float(b.g), Float(b.b)))
    }

    /// The colorful color covering the most surface of the mesh (paint is colorful; the chassis,
    /// tyres and trim are grey or black and can cover more area). Near-identical colors are grouped,
    /// because a palette swatch isn't one exact pixel value.
    static func bodyColor(mesh: OBJMesh, texture: CGImage) -> RGB {
        let px = pixels(of: texture)
        var samples: [(RGB, Float)] = []
        for t in stride(from: 0, to: mesh.indices.count, by: 3) {
            let (a, b, c) = (Int(mesh.indices[t]), Int(mesh.indices[t + 1]), Int(mesh.indices[t + 2]))
            let triArea = simd_length(simd_cross(mesh.positions[b] - mesh.positions[a], mesh.positions[c] - mesh.positions[a])) / 2
            let uv = (mesh.uvs[a] + mesh.uvs[b] + mesh.uvs[c]) / 3
            // OBJ texture coordinates start at the bottom of the image.
            let x = min(texture.width - 1, max(0, Int(uv.x * Float(texture.width))))
            let y = min(texture.height - 1, max(0, Int((1 - uv.y) * Float(texture.height))))
            let i = (y * texture.width + x) * 4
            samples.append((RGB(r: px[i], g: px[i + 1], b: px[i + 2]), triArea))
        }
        func isColorful(_ c: RGB) -> Bool {
            var s: CGFloat = 0, b: CGFloat = 0
            UIColor(red: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1)
                .getHue(nil, saturation: &s, brightness: &b, alpha: nil)
            return s > 0.35 && b > 0.35
        }
        let candidates = samples.filter { isColorful($0.0) }
        let pool = candidates.isEmpty ? samples : candidates
        // For each candidate color, total the area of everything within `sameColorDistance`.
        let distinct = Array(Set(pool.map(\.0)))
        return distinct.max { a, b in
            pool.filter { distance($0.0, a) < sameColorDistance }.reduce(0) { $0 + $1.1 }
                < pool.filter { distance($0.0, b) < sameColorDistance }.reduce(0) { $0 + $1.1 }
        }!
    }

    /// A copy of the texture with the body paint (every pixel close to `body`) changed to `paint`,
    /// keeping each pixel's relative lightness so shading in the palette survives.
    static func repaint(texture: CGImage, body: RGB, paint: UIColor) -> CGImage? {
        var px = pixels(of: texture)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        paint.getRed(&r, green: &g, blue: &b, alpha: nil)
        let bodyLum = max(1, (Float(body.r) + Float(body.g) + Float(body.b)) / 3)
        for i in stride(from: 0, to: px.count, by: 4) {
            let c = RGB(r: px[i], g: px[i + 1], b: px[i + 2])
            guard distance(c, body) < sameColorDistance else { continue }
            let shade = ((Float(c.r) + Float(c.g) + Float(c.b)) / 3) / bodyLum
            px[i] = UInt8(min(255, Float(r) * 255 * shade))
            px[i + 1] = UInt8(min(255, Float(g) * 255 * shade))
            px[i + 2] = UInt8(min(255, Float(b) * 255 * shade))
        }
        let ctx = CGContext(data: &px, width: texture.width, height: texture.height, bitsPerComponent: 8, bytesPerRow: texture.width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        return ctx?.makeImage()
    }
}
