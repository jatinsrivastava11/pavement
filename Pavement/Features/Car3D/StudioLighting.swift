import CoreGraphics
import RealityKit
import SwiftUI
import UIKit

/// A small procedural photo-studio environment: a soft gradient with two bright "softbox" panels,
/// the way product photographers light a car to show its panel lines. Built entirely in code, so
/// chrome and glass have something believable to reflect without any downloaded asset.
enum StudioLighting {
    /// Renders the equirectangular environment image (spans the full turn horizontally, pole to
    /// pole vertically). `floor`/`ceiling` set the overall brightness, so the reflections can match
    /// a dark or light app theme.
    static func image(width: Int = 256, height: Int = 128, ceiling: Float = 0.88, floor: Float = 0.14) -> CGImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for y in 0..<height {
            let t = Float(y) / Float(height - 1)   // 0 = straight up, 1 = straight down
            let v: Float = t < 0.35 ? mix(ceiling * 0.82, ceiling, t / 0.35)
                          : t < 0.55 ? mix(ceiling, mix(floor, ceiling, 0.5), (t - 0.35) / 0.2)
                          : mix(mix(floor, ceiling, 0.5), floor, (t - 0.55) / 0.45)
            ctx.setFillColor(CGColor(red: CGFloat(v), green: CGFloat(v), blue: CGFloat(min(1, v * 1.03)), alpha: 1))
            ctx.fill(CGRect(x: 0, y: y, width: width, height: 1))
        }
        // Two soft highlight panels above the horizon, roughly where studio softboxes sit.
        for cx in [Float(width) * 0.28, Float(width) * 0.74] {
            let cy = Float(height) * 0.2
            let bw = Float(width) * 0.15, bh = Float(height) * 0.16
            let x0 = max(0, Int(cx - bw)), x1 = min(width, Int(cx + bw))
            let y0 = max(0, Int(cy - bh)), y1 = min(height, Int(cy + bh))
            guard x1 > x0, y1 > y0 else { continue }
            for y in y0..<y1 {
                for x in x0..<x1 {
                    let dx = (Float(x) - cx) / bw, dy = (Float(y) - cy) / bh
                    let falloff = max(0, 1 - (dx * dx + dy * dy))
                    guard falloff > 0.02 else { continue }
                    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: CGFloat(falloff) * 0.85))
                    ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        return ctx.makeImage()!
    }

    private static func mix(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * max(0, min(1, t)) }

    /// Adds a light source entity built from the studio image. Attach
    /// `ImageBasedLightReceiverComponent(imageBasedLight: <returned entity>)` to anything that
    /// should pick up its reflections; the entity itself stays invisible (no skybox is shown).
    @MainActor
    static func addEnvironment(to content: RealityViewCameraContent, dark: Bool) -> Entity? {
        guard let env = try? EnvironmentResource(equirectangular: image(ceiling: dark ? 0.55 : 0.94, floor: dark ? 0.05 : 0.22),
                                                 withName: "pavement-studio-\(dark ? "dark" : "light")") else { return nil }
        let lightSource = Entity()
        lightSource.components.set(ImageBasedLightComponent(source: .single(env), intensityExponent: 0.6))
        content.add(lightSource)
        return lightSource
    }
}
