import CoreGraphics
import CoreML
import Vision

/// Finds every car in a photo, including small, distant and partly hidden ones.
///
/// Runs YOLOv3-Tiny on the whole photo plus a 3×3 grid of overlapping tiles, so distant cars get
/// enough pixels, and the full YOLOv3 on the whole photo, which is better at big cars cut off by the
/// photo edge. Then merges duplicate boxes. Everything runs on the phone.
/// Vision models are safe to share across threads once loaded.
final class CarDetector: @unchecked Sendable {
    struct Detection: Equatable, Sendable {
        /// Normalized to 0...1, origin at the top-left (UIKit/SwiftUI style).
        var box: CGRect
        var confidence: Float
        /// "car", "truck" or "bus".
        var label: String
    }

    static let vehicleLabels: Set = ["car", "truck", "bus"]

    let minConfidence: Float = 0.3
    let gridSize = 3

    private let model: VNCoreMLModel
    private let fullFrameModel: VNCoreMLModel

    init() throws {
        let configuration = MLModelConfiguration()
        model = try VNCoreMLModel(for: CarDetectorYOLOv3Tiny(configuration: configuration).model)
        fullFrameModel = try VNCoreMLModel(for: CarDetectorYOLOv3(configuration: configuration).model)
    }

    func detect(in image: CGImage, orientation: CGImagePropertyOrientation = .up) throws -> [Detection] {
        var found: [Detection] = []
        let passes = Self.regions(gridSize: gridSize).map { (model, $0) } + [(fullFrameModel, CGRect(x: 0, y: 0, width: 1, height: 1))]
        for (passModel, region) in passes {
            let request = VNCoreMLRequest(model: passModel)
            request.imageCropAndScaleOption = .scaleFill
            request.regionOfInterest = region
            try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
            for observation in request.results as? [VNRecognizedObjectObservation] ?? [] {
                guard let top = observation.labels.first, Self.vehicleLabels.contains(top.identifier),
                      top.confidence >= minConfidence else { continue }
                let local = observation.boundingBox
                if region.width < 1 && Self.isCutByTileEdge(local, region: region) { continue }
                let global = CGRect(x: region.minX + local.minX * region.width,
                                    y: region.minY + local.minY * region.height,
                                    width: local.width * region.width, height: local.height * region.height)
                // Vision uses a bottom-left origin; flip to top-left, and keep boxes inside the photo
                // (cars cut off by the photo edge get boxes that spill past it).
                let flipped = CGRect(x: global.minX, y: 1 - global.maxY, width: global.width, height: global.height)
                    .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
                guard !flipped.isNull, flipped.width > 0, flipped.height > 0 else { continue }
                found.append(Detection(box: flipped, confidence: top.confidence, label: top.identifier))
            }
        }
        return Self.merge(found)
    }

    /// The full frame plus an overlapping grid of tiles (Vision coordinates).
    static func regions(gridSize: Int) -> [CGRect] {
        var regions = [CGRect(x: 0, y: 0, width: 1, height: 1)]
        guard gridSize > 1 else { return regions }
        let size = 1.6 / Double(gridSize)
        let step = (1 - size) / Double(gridSize - 1)
        for gy in 0..<gridSize {
            for gx in 0..<gridSize {
                regions.append(CGRect(x: Double(gx) * step, y: Double(gy) * step, width: size, height: size))
            }
        }
        return regions
    }

    /// A box touching a tile edge that isn't the photo edge is a car cut in half by the tile;
    /// the full-frame pass or a neighbouring tile sees it whole.
    static func isCutByTileEdge(_ box: CGRect, region: CGRect, margin: Double = 0.01) -> Bool {
        (box.minX < margin && region.minX > 0) || (box.maxX > 1 - margin && region.maxX < 1)
            || (box.minY < margin && region.minY > 0) || (box.maxY > 1 - margin && region.maxY < 1)
    }

    /// Keeps the most confident box and drops others that show the same car.
    static func merge(_ detections: [Detection]) -> [Detection] {
        var kept: [Detection] = []
        for d in detections.sorted(by: { $0.confidence > $1.confidence }) where !kept.contains(where: { sameCar($0.box, d.box) }) {
            kept.append(d)
        }
        return kept
    }

    /// Two boxes show the same car when they overlap a lot and are a similar size, or one sits almost
    /// entirely inside the other (a tile that only saw part of a big car). A big nearby car's box
    /// doesn't swallow a small car further back unless it covers it almost completely.
    static func sameCar(_ a: CGRect, _ b: CGRect) -> Bool {
        let i = a.intersection(b)
        let (aa, ba) = (a.width * a.height, b.width * b.height)
        guard !i.isNull, aa > 0, ba > 0 else { return false }
        let inter = i.width * i.height
        let iou = inter / (aa + ba - inter)
        let containment = inter / min(aa, ba)
        let sizeRatio = min(aa, ba) / max(aa, ba)
        return iou > 0.45 || (containment > 0.8 && sizeRatio > 0.4) || containment > 0.9
    }
}
