import CoreGraphics
import CoreML
import Vision

/// Suggests which car model a cropped car photo shows.
///
/// Knows 41 common and rare models plus an "other" category (trained on dozens of other models) so it
/// can say "not one I know". The app names the car itself (users can't choose), only when the model is
/// at least `minConfidence` sure, the answer isn't "other", and mirrored/zoomed views agree.
///
/// Measured on held-out photographers (cut-off chosen from a sweep): of 528 known test cars, 73 named
/// right and 6 wrong; of 61 cars from models it never saw, 1 wrongly named. When it names a car it's
/// right 91% of the time. Most cars are left unnamed rather than risk a wrong name.
final class CarIdentifier: @unchecked Sendable {
    struct Suggestion: Equatable, Sendable {
        let carID: String
        let confidence: Float
    }

    static let minConfidence: Float = 0.85

    private let model: VNCoreMLModel

    init() throws {
        let configuration = MLModelConfiguration()
        #if targetEnvironment(simulator)
        configuration.computeUnits = .cpuOnly   // the simulator can't run it on the GPU
        #endif
        model = try VNCoreMLModel(for: CarIdentifierPilot(configuration: configuration).model)
    }

    static let otherLabel = "other"

    /// Car IDs the bundled model can recognize, read from the model file (no need to load it).
    static let recognizableIDs: Set<String> = {
        guard let url = Bundle.main.url(forResource: "CarIdentifierPilot", withExtension: "mlmodelc"),
              let data = try? Data(contentsOf: url.appendingPathComponent("metadata.json")),
              let meta = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]],
              let labels = meta.first?["classLabels"] as? [String] else { return [] }
        return Set(labels).subtracting([otherLabel])
    }()

    /// Every car ID the model can recognize (not counting "other").
    var knownCarIDs: [String] {
        Self.labels(of: model).filter { $0 != Self.otherLabel }
    }

    /// The top `limit` suggestions for a cropped car image, best first.
    func suggestions(for car: CGImage, limit: Int = 3) throws -> [Suggestion] {
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .centerCrop
        #if targetEnvironment(simulator)
        if let cpu = MLComputeDevice.allComputeDevices.first(where: { if case .cpu = $0 { true } else { false } }) {
            request.setComputeDevice(cpu, for: .main)
        }
        #endif
        try VNImageRequestHandler(cgImage: car).perform([request])
        return (request.results as? [VNClassificationObservation] ?? [])
            .prefix(limit)
            .map { Suggestion(carID: $0.identifier, confidence: $0.confidence) }
    }

    /// Views of the same crop (mirrored, slightly zoomed) must agree at this confidence.
    static let agreementConfidence: Float = 0.85

    /// The model's answer if it's confident enough and it holds up when the photo is mirrored and
    /// slightly zoomed; otherwise nil ("couldn't identify"). Lucky one-off mistakes (a Beetle from
    /// behind read as a Bugatti) tend to fall apart under those small changes.
    func identify(_ car: CGImage) throws -> Suggestion? {
        guard let best = try suggestions(for: car, limit: 1).first, best.carID != Self.otherLabel,
              best.confidence >= Self.minConfidence else { return nil }
        for view in [Self.mirrored(car), Self.zoomed(car)].compactMap({ $0 }) {
            guard let other = try suggestions(for: view, limit: 1).first,
                  other.carID == best.carID, other.confidence >= Self.agreementConfidence else { return nil }
        }
        return best
    }

    static func mirrored(_ image: CGImage) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.translateBy(x: CGFloat(image.width), y: 0)
        ctx.scaleBy(x: -1, y: 1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage()
    }

    /// The middle 84% of the image.
    static func zoomed(_ image: CGImage) -> CGImage? {
        let w = Double(image.width), h = Double(image.height)
        return image.cropping(to: CGRect(x: w * 0.08, y: h * 0.08, width: w * 0.84, height: h * 0.84).integral)
    }

    private static func labels(of model: VNCoreMLModel) -> [String] {
        guard let url = Bundle.main.url(forResource: "CarIdentifierPilot", withExtension: "mlmodelc"),
              let ml = try? MLModel(contentsOf: url),
              let labels = ml.modelDescription.classLabels as? [String] else { return [] }
        return labels
    }
}
