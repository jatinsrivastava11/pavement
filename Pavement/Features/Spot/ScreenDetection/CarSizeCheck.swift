import CoreGraphics
import Foundation
import ImageIO

/// A depth map in meters, row-major, with its own width and height.
struct DepthMap: Sendable {
    var values: [Float]
    var width: Int
    var height: Int

    /// Rotates the map the same way `CGImage.upright(orientation:)` rotates the photo,
    /// so photo boxes line up with depth.
    func upright(orientation: CGImagePropertyOrientation) -> DepthMap {
        switch orientation {
        case .right:   // 90° clockwise: new(x, y) = old(y, H-1-x)
            var out = [Float](repeating: 0, count: values.count)
            for y in 0..<width { for x in 0..<height { out[y * height + x] = values[(height - 1 - x) * width + y] } }
            return DepthMap(values: out, width: height, height: width)
        case .left:    // 90° counter-clockwise: new(x, y) = old(W-1-y, x)
            var out = [Float](repeating: 0, count: values.count)
            for y in 0..<width { for x in 0..<height { out[y * height + x] = values[x * width + (width - 1 - y)] } }
            return DepthMap(values: out, width: height, height: width)
        case .down:
            return DepthMap(values: values.reversed(), width: width, height: height)
        default:
            return self
        }
    }

    /// Median depth inside the central half of a normalized top-left box, or nil if there's none.
    func medianDepth(in box: CGRect) -> Float? {
        let inner = box.insetBy(dx: box.width / 4, dy: box.height / 4)
        let x0 = max(0, Int(inner.minX * Double(width))), x1 = min(width, Int(ceil(inner.maxX * Double(width))))
        let y0 = max(0, Int(inner.minY * Double(height))), y1 = min(height, Int(ceil(inner.maxY * Double(height))))
        guard x1 > x0, y1 > y0 else { return nil }
        var samples: [Float] = []
        for y in y0..<y1 { for x in x0..<x1 {
            let d = values[y * width + x]
            if d.isFinite, d > 0 { samples.append(d) }
        } }
        guard !samples.isEmpty else { return nil }
        samples.sort()
        return samples[samples.count / 2]
    }
}

/// Estimates how big a detected car really is, to catch toy and model cars.
///
/// Real size = distance × the angle the car takes up in the photo. A real car is at least ~1.2 m
/// in its biggest visible dimension even when partly hidden; a 1:18 model is ~25 cm.
enum CarSizeCheck {
    /// Anything smaller than this (biggest visible dimension) is treated as a toy or model.
    static let minRealCarSize: Double = 0.45

    /// - Parameters:
    ///   - box: normalized, top-left origin, in the upright photo.
    ///   - distance: meters to the car.
    ///   - horizontalFOV: camera field of view across the upright photo's width, in degrees.
    ///   - aspect: upright photo height ÷ width.
    static func estimatedSize(box: CGRect, distance: Double, horizontalFOV: Double, aspect: Double) -> Double {
        let halfW = tan(horizontalFOV * .pi / 360)
        let sceneWidth = 2 * distance * halfW                  // meters across the photo at that distance
        let sceneHeight = sceneWidth * aspect
        return max(box.width * sceneWidth, box.height * sceneHeight)
    }

    static func isToy(box: CGRect, depth: DepthMap?, horizontalFOV: Double?, aspect: Double) -> Bool? {
        guard let depth, let horizontalFOV, let d = depth.medianDepth(in: box) else { return nil }
        return estimatedSize(box: box, distance: Double(d), horizontalFOV: horizontalFOV, aspect: aspect) < minRealCarSize
    }
}
