import CoreGraphics
import CoreML
import Vision

/// Suggests which car model a cropped car photo shows.
///
/// Pilot model: knows 22 models. Measured on photos from photographers it never saw: right first
/// guess 54%, right answer in the top 3 75%. Its confidence isn't reliable (it can be "100% sure"
/// and wrong), so the app always lets the user pick from the top suggestions instead of
/// auto-accepting.
final class CarIdentifier: @unchecked Sendable {
    struct Suggestion: Equatable, Sendable {
        let carID: String
        let confidence: Float
    }

    private let model: VNCoreMLModel

    init() throws {
        let configuration = MLModelConfiguration()
        #if targetEnvironment(simulator)
        configuration.computeUnits = .cpuOnly   // the simulator can't run it on the GPU
        #endif
        model = try VNCoreMLModel(for: CarIdentifierPilot(configuration: configuration).model)
    }

    /// Every car ID the model can recognize.
    var knownCarIDs: [String] {
        Self.labels(of: model)
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

    private static func labels(of model: VNCoreMLModel) -> [String] {
        guard let url = Bundle.main.url(forResource: "CarIdentifierPilot", withExtension: "mlmodelc"),
              let ml = try? MLModel(contentsOf: url),
              let labels = ml.modelDescription.classLabels as? [String] else { return [] }
        return labels
    }
}
