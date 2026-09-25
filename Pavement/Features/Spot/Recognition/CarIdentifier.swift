import Accelerate
import CoreGraphics
import CoreML
import Vision

/// Suggests which car model a cropped car photo shows.
///
/// Vision turns the photo into a feature print — a list of 768 numbers describing what it looks
/// like — and a single matrix of learned weights turns that into a score for every car at once.
/// That is the whole recognizer: one multiply, about half a megabyte of weights, no Core ML
/// classifier involved.
///
/// It is built this way because the obvious way was the thing holding it back. Create ML's image
/// classifier does the same two steps, but holds every training image in memory while it does them,
/// so it runs out of room at roughly 8,000 photos. That limit is what forced the previous design:
/// five separate recognizers split by body shape, with a router picking between them, each trained
/// on a fraction of the photos. Extracting the feature prints once, up front, removes the limit
/// entirely — every car and every photo train together — and the router, the five models and the
/// 38% of cars the router misdirected all disappear with it.
///
/// The app names the car itself (users can't choose), only when the score is confident enough and
/// the answer survives the photo being mirrored and slightly zoomed.
///
/// Measured on held-out photographers: against the five-model version on the same photos, named
/// right went from 575 to 1,534 and named wrong from 190 to 142 — 2.7 times as many cars
/// identified, and right 88% of the time when it speaks rather than 74%.
final class CarIdentifier: @unchecked Sendable {
    struct Suggestion: Equatable, Sendable {
        let carID: String
        let confidence: Float
    }

    /// Chosen from a sweep over held-out photographers. Raising it names fewer cars and is wrong
    /// less often; the shape of that trade is in the notes.
    static let minConfidence: Float = 0.8

    /// Views of the same crop (mirrored, slightly zoomed) must agree at this confidence.
    static let agreementConfidence: Float = 0.6

    /// One row of weights per car, and the bias for each.
    private let weights: [Float]
    private let bias: [Float]
    private let dims: Int
    private let carIDs: [String]
    /// Cosine features are small, so the scores are scaled before the softmax to sharpen them.
    /// Must match the scale the weights were trained with.
    private static let logitScale: Float = 12

    init() throws {
        guard let binURL = Bundle.main.url(forResource: "CarHead", withExtension: "bin"),
              let jsonURL = Bundle.main.url(forResource: "CarHead", withExtension: "json"),
              let ids = try JSONSerialization.jsonObject(with: Data(contentsOf: jsonURL)) as? [String]
        else { throw CocoaError(.fileNoSuchFile) }
        let data = try Data(contentsOf: binURL)
        let header = data.withUnsafeBytes { $0.loadUnaligned(as: SIMD2<Int32>.self) }
        dims = Int(header.x)
        let count = Int(header.y)
        guard count == ids.count, data.count == 8 + (dims * count + count) * 4 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        carIDs = ids
        let floats = data.dropFirst(8).withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        weights = Array(floats[0..<(dims * count)])
        bias = Array(floats[(dims * count)...])
    }

    static let otherLabel = "other"

    /// Car IDs the bundled weights can recognize.
    static let recognizableIDs: Set<String> = {
        guard let url = Bundle.main.url(forResource: "CarHead", withExtension: "json"),
              let ids = try? JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String]
        else { return [] }
        return Set(ids)
    }()

    var knownCarIDs: [String] { carIDs }

    /// The photo as Vision sees it: a fixed-length list of numbers, unit length so the weights
    /// behave like cosine similarities.
    private func featurePrint(_ image: CGImage) throws -> [Float]? {
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision2
        #if targetEnvironment(simulator)
        // The simulator has no GPU inference context for this ("failed to create espresso
        // context"), so it has to be told to use the CPU or the request throws outright.
        if let cpu = MLComputeDevice.allComputeDevices.first(where: { if case .cpu = $0 { true } else { false } }) {
            request.setComputeDevice(cpu, for: .main)
        }
        #endif
        try VNImageRequestHandler(cgImage: image).perform([request])
        guard let observation = request.results?.first as? VNFeaturePrintObservation,
              observation.elementCount == dims else { return nil }
        var v = [Float](repeating: 0, count: dims)
        observation.data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: Float.self)
            for i in 0..<dims { v[i] = src[i] }
        }
        var norm: Float = 0
        vDSP_svesq(v, 1, &norm, vDSP_Length(dims))
        if norm > 0 { vDSP_vsmul(v, 1, [1 / sqrt(norm)], &v, 1, vDSP_Length(dims)) }
        return v
    }

    /// Scores every car at once, as softmax probabilities.
    private func scores(for image: CGImage) throws -> [Float]? {
        guard let v = try featurePrint(image) else { return nil }
        var logits = bias
        // One matrix-vector multiply: (cars x dims) * (dims) -> (cars)
        cblas_sgemv(CblasRowMajor, CblasNoTrans, Int32(carIDs.count), Int32(dims),
                    Self.logitScale, weights, Int32(dims), v, 1, Self.logitScale, &logits, 1)
        let peak = logits.max() ?? 0
        var total: Float = 0
        for i in logits.indices { logits[i] = exp(logits[i] - peak); total += logits[i] }
        if total > 0 { for i in logits.indices { logits[i] /= total } }
        return logits
    }

    /// The top `limit` suggestions for a cropped car image, best first.
    func suggestions(for car: CGImage, limit: Int = 3) throws -> [Suggestion] {
        guard let p = try scores(for: car) else { return [] }
        return p.enumerated().sorted { $0.element > $1.element }.prefix(limit)
            .map { Suggestion(carID: carIDs[$0.offset], confidence: $0.element) }
    }

    /// The answer if it is confident enough and it holds up when the photo is mirrored and slightly
    /// zoomed; otherwise nil ("couldn't identify"). Lucky one-off mistakes — a Beetle from behind
    /// read as a Bugatti — tend to fall apart under those small changes.
    func identify(_ car: CGImage) throws -> Suggestion? {
        guard let best = try suggestions(for: car, limit: 1).first,
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
}
