import CoreGraphics
import CoreML
import Vision

/// Suggests which car model a cropped car photo shows.
///
/// One recognizer can only hold about 45 cars: quality comes from training each car on ~150 photos,
/// and only about 7,500 photos can be trained at once. So the work is split across five *experts*,
/// one per body shape, and a small *router* picks which of them should answer.
///
/// The router is not very good — it sends only about 62% of cars to the right expert, because a
/// hatchback and a saloon look alike in a photo. It works anyway, because each expert is also
/// trained on the other groups' cars, so an expert handed a car outside its group answers "other"
/// instead of guessing. A wrong route costs a refusal, not a wrong name. That was measured against
/// the alternatives: asking the two best-matching experts, or all five, finds more cars but brings
/// in far more wrong names (67% and 60% precision against this one's 74%).
///
/// The app names the car itself (users can't choose), only when the expert is at least
/// `minConfidence` sure, the answer isn't "other", and mirrored/zoomed views agree.
///
/// Measured on held-out photographers, 4,837 photos of 128 cars plus 61 photos of models it was
/// never taught: 575 named right, 190 wrong, 8 of the 61 unknown models wrongly named. The 75-car
/// recognizer this replaced managed 219 right and 330 wrong on the same photos, because it
/// confidently mislabels every car outside the 75 it knows.
final class CarIdentifier: @unchecked Sendable {
    struct Suggestion: Equatable, Sendable {
        let carID: String
        let confidence: Float
    }

    static let minConfidence: Float = 0.95

    /// Views of the same crop (mirrored, slightly zoomed) must agree at this confidence.
    static let agreementConfidence: Float = 0.85

    static let otherLabel = "other"

    /// The groups the router chooses between, and the expert bundled for each.
    static let groups = ["suv": "CarExpertSuv", "utility": "CarExpertUtility",
                         "compact": "CarExpertCompact", "saloon": "CarExpertSaloon",
                         "sporty": "CarExpertSporty"]

    /// Which body styles each expert was taught. Used by the tests to check every car really is
    /// with its own group, and to keep this list honest as cars are added.
    static let bodyStyles: [String: Set<String>] = [
        "suv": ["suv"], "utility": ["pickup", "van", "wagon"],
        "compact": ["hatchback"], "saloon": ["sedan"],
        "sporty": ["coupe", "supercar", "convertible"],
    ]

    private let router: VNCoreMLModel
    private let experts: [String: VNCoreMLModel]

    init() throws {
        let configuration = MLModelConfiguration()
        #if targetEnvironment(simulator)
        configuration.computeUnits = .cpuOnly   // the simulator can't run it on the GPU
        #endif
        router = try Self.load("CarRouter", configuration)
        experts = try Self.groups.mapValues { try Self.load($0, configuration) }
    }

    /// Models are loaded from the bundle by name rather than through Xcode's generated classes, so
    /// the set of experts can change without any code changing with it.
    private static func load(_ name: String, _ configuration: MLModelConfiguration) throws -> VNCoreMLModel {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try VNCoreMLModel(for: MLModel(contentsOf: url, configuration: configuration))
    }

    /// Car IDs the bundled experts can recognize, read from the model files (no need to load them).
    static let recognizableIDs: Set<String> = {
        var ids = Set<String>()
        for name in groups.values {
            guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
                  let data = try? Data(contentsOf: url.appendingPathComponent("metadata.json")),
                  let meta = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]],
                  let labels = meta.first?["classLabels"] as? [String] else { continue }
            ids.formUnion(labels)
        }
        return ids.subtracting([otherLabel])
    }()

    /// Every car ID the experts can recognize (not counting "other").
    var knownCarIDs: [String] {
        Set(Self.groups.values.flatMap { Self.labels(inBundledModel: $0) })
            .subtracting([Self.otherLabel]).sorted()
    }

    /// Which group the router thinks this car belongs to, and how sure it is. "other" is skipped:
    /// the router's job is only to choose a group, and refusing is the expert's job.
    func route(_ car: CGImage) throws -> (group: String, confidence: Float)? {
        try Self.top(router, car, limit: 3).first { $0.carID != Self.otherLabel }
            .map { (group: $0.carID, confidence: $0.confidence) }
    }

    /// The top `limit` suggestions for a cropped car image, best first, from whichever expert the
    /// router picks.
    func suggestions(for car: CGImage, limit: Int = 3) throws -> [Suggestion] {
        guard let group = try route(car)?.group, let expert = experts[group] else { return [] }
        return try Self.top(expert, car, limit: limit)
    }

    private static func top(_ model: VNCoreMLModel, _ image: CGImage, limit: Int) throws -> [Suggestion] {
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .centerCrop
        #if targetEnvironment(simulator)
        if let cpu = MLComputeDevice.allComputeDevices.first(where: { if case .cpu = $0 { true } else { false } }) {
            request.setComputeDevice(cpu, for: .main)
        }
        #endif
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results as? [VNClassificationObservation] ?? [])
            .prefix(limit)
            .map { Suggestion(carID: $0.identifier, confidence: $0.confidence) }
    }

    /// The expert's answer if it's confident enough and it holds up when the photo is mirrored and
    /// slightly zoomed; otherwise nil ("couldn't identify"). Lucky one-off mistakes (a Beetle from
    /// behind read as a Bugatti) tend to fall apart under those small changes. All three views are
    /// put to the one expert the router chose, so they are judged against the same set of cars.
    func identify(_ car: CGImage) throws -> Suggestion? {
        guard let group = try route(car)?.group, let expert = experts[group],
              let best = try Self.top(expert, car, limit: 1).first,
              best.carID != Self.otherLabel, best.confidence >= Self.minConfidence else { return nil }
        for view in [Self.mirrored(car), Self.zoomed(car)].compactMap({ $0 }) {
            guard let other = try Self.top(expert, view, limit: 1).first,
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

    private static func labels(inBundledModel name: String) -> [String] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
              let ml = try? MLModel(contentsOf: url),
              let labels = ml.modelDescription.classLabels as? [String] else { return [] }
        return labels
    }
}
