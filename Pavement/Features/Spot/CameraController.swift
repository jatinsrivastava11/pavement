@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage

/// Runs the live camera and captures photos, with depth when the iPhone supports it.
///
/// Photos can only come from here. The app has no photo-library picker, so screenshots and saved
/// images can't be spotted.
final class CameraController: NSObject, @unchecked Sendable {
    /// What a capture hands to the screen check.
    struct Capture: Sendable {
        var image: CGImage
        var luminance: [Float]
        var width: Int
        var height: Int
        var depth: (values: [Float], width: Int, height: Int)?
    }

    enum CameraError: LocalizedError {
        case unavailable, permissionDenied, captureFailed

        var errorDescription: String? {
            switch self {
            case .unavailable: "No camera available on this device."
            case .permissionDenied: "Pavement needs the camera to spot cars. Turn it on in Settings → Pavement."
            case .captureFailed: "Couldn't take the photo. Try again."
            }
        }
    }

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "pavement.camera")
    private var isConfigured = false
    private var pending: CheckedContinuation<AVCapturePhoto, any Error>?
    private(set) var supportsDepth = false

    /// Asks for camera permission if needed, then sets up and starts the camera.
    func start() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { throw CameraError.permissionDenied }
        default: throw CameraError.permissionDenied
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            queue.async {
                do {
                    try self.configureIfNeeded()
                    if !self.session.isRunning { self.session.startRunning() }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    /// Prefers cameras that can measure depth; falls back to the plain wide camera.
    private func configureIfNeeded() throws {
        guard !isConfigured else { return }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInLiDARDepthCamera, .builtInTripleCamera, .builtInDualWideCamera,
                          .builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video, position: .back
        )
        guard let device = discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: device) else { throw CameraError.unavailable }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else { throw CameraError.unavailable }
        session.addInput(input)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .balanced
        supportsDepth = photoOutput.isDepthDataDeliverySupported
        photoOutput.isDepthDataDeliveryEnabled = supportsDepth
        isConfigured = true
    }

    func capture() async throws -> Capture {
        let photo: AVCapturePhoto = try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.isConfigured, self.pending == nil else {
                    continuation.resume(throwing: CameraError.captureFailed)
                    return
                }
                self.pending = continuation
                let settings = AVCapturePhotoSettings()
                settings.isDepthDataDeliveryEnabled = self.supportsDepth
                settings.photoQualityPrioritization = .balanced
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
        guard let image = photo.cgImageRepresentation() else { throw CameraError.captureFailed }
        let (luminance, width, height) = Self.luminance(of: image, maxSide: 1024)
        return Capture(image: image, luminance: luminance, width: width, height: height,
                       depth: photo.depthData.flatMap(Self.depthValues))
    }

    /// Grayscale pixels, scaled down so the longest side is at most `maxSide`.
    static func luminance(of image: CGImage, maxSide: Int) -> ([Float], Int, Int) {
        let scale = min(1, Double(maxSide) / Double(max(image.width, image.height)))
        let width = max(1, Int(Double(image.width) * scale)), height = max(1, Int(Double(image.height) * scale))
        var bytes = [UInt8](repeating: 0, count: width * height)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: CGImageAlphaInfo.none.rawValue)
            context?.interpolationQuality = .medium
            context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return (bytes.map { Float($0) / 255 }, width, height)
    }

    /// Depth in meters. Disparity-based depth (dual cameras) is converted to distance.
    static func depthValues(from data: AVDepthData) -> (values: [Float], width: Int, height: Int)? {
        let converted = data.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let buffer = converted.depthDataMap
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        var values = [Float](repeating: 0, count: width * height)
        for row in 0..<height {
            let line = (base + row * rowBytes).assumingMemoryBound(to: Float32.self)
            for col in 0..<width { values[row * width + col] = line[col] }
        }
        return (values, width, height)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        queue.async {
            let continuation = self.pending
            self.pending = nil
            if let error { continuation?.resume(throwing: error) } else { continuation?.resume(returning: photo) }
        }
    }
}
