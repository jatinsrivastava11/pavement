import CoreGraphics
import Foundation
import ImageIO

/// Turns one photo into a list of cars: finds each car, crops it out, and suggests which model it is.
struct SpotPipeline: Sendable {
    struct FoundCar: Identifiable, Sendable {
        enum Verdict: Equatable, Sendable {
            /// Named by the app. Users can keep or skip it, never rename it.
            case identified(carID: String)
            /// Not confident enough, or not a model Pavement knows yet.
            case unidentified
            /// Too small to be a real car (measured with depth).
            case toy
        }

        let id = UUID()
        let crop: CGImage
        /// Top-left origin, normalized.
        let box: CGRect
        let verdict: Verdict
    }

    let detector: CarDetector
    let identifier: CarIdentifier
    let catalog: CarCatalog
    /// Cars smaller than this share of the photo are too small to identify.
    var minBoxArea: Double = 0.004

    init(catalog: CarCatalog) throws {
        detector = try CarDetector()
        identifier = try CarIdentifier()
        self.catalog = catalog
    }

    /// - Parameters:
    ///   - image: upright photo (see `CGImage.upright(orientation:)`).
    ///   - depth: upright depth map, when the iPhone has one; used to catch toy cars.
    ///   - horizontalFOV: camera field of view across the upright photo's width, in degrees.
    ///   - onCarsFound: called once with how many cars were found, before the slower work of naming
    ///     them begins, so the waiting screen can say what it is doing.
    func run(on image: CGImage, depth: DepthMap? = nil, horizontalFOV: Double? = nil,
             onCarsFound: (@Sendable (Int) -> Void)? = nil) throws -> [FoundCar] {
        let aspect = Double(image.height) / Double(image.width)
        let detections = try detector.detect(in: image)
            .filter { $0.box.width * $0.box.height >= minBoxArea }
            .sorted { $0.box.width * $0.box.height > $1.box.width * $1.box.height }   // biggest first
        onCarsFound?(detections.count)
        return try detections
            .compactMap { detection -> FoundCar? in
                guard let crop = Self.crop(image, to: detection.box) else { return nil }
                if CarSizeCheck.isToy(box: detection.box, depth: depth, horizontalFOV: horizontalFOV, aspect: aspect) == true {
                    return FoundCar(crop: crop, box: detection.box, verdict: .toy)
                }
                let verdict: FoundCar.Verdict = if let id = try identifier.identify(crop)?.carID, catalog.car(id: id) != nil {
                    .identified(carID: id)
                } else {
                    .unidentified
                }
                return FoundCar(crop: crop, box: detection.box, verdict: verdict)
            }
    }

    /// Crops a normalized top-left box (plus a little margin) out of the image.
    static func crop(_ image: CGImage, to box: CGRect, margin: Double = 0.06) -> CGImage? {
        let padded = box.insetBy(dx: -box.width * margin, dy: -box.height * margin)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        let w = Double(image.width), h = Double(image.height)
        let rect = CGRect(x: padded.minX * w, y: padded.minY * h, width: padded.width * w, height: padded.height * h).integral
        guard rect.width >= 8, rect.height >= 8 else { return nil }
        return image.cropping(to: rect)
    }
}

extension CGImage {
    /// Redraws the image so its pixels are upright, applying the camera's EXIF orientation.
    func upright(orientation: CGImagePropertyOrientation) -> CGImage? {
        if orientation == .up { return self }
        let rotated = [.left, .right, .leftMirrored, .rightMirrored].contains(orientation)
        let w = rotated ? height : width, h = rotated ? width : height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let W = CGFloat(w), H = CGFloat(h)
        switch orientation {
        case .right: ctx.concatenate(CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: H))
        case .left: ctx.concatenate(CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: W, ty: 0))
        case .down: ctx.concatenate(CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: W, ty: H))
        case .upMirrored: ctx.concatenate(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: W, ty: 0))
        case .downMirrored: ctx.concatenate(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: H))
        case .rightMirrored: ctx.concatenate(CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0))
        case .leftMirrored: ctx.concatenate(CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: W, ty: H))
        default: break
        }
        ctx.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}
