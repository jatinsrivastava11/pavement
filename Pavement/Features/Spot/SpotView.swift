import SwiftUI

/// The Spot tab: live camera, shutter, and the screen check on every photo.
struct SpotView: View {
    let app: AppModel
    @State private var camera = CameraController()
    @State private var driving = DrivingMonitor()
    @State private var status: Status = .starting
    @State private var isCapturing = false
    @State private var result: CaptureResult?

    private enum Status: Equatable {
        case starting, running, failed(String)
    }

    struct CaptureResult: Identifiable {
        let id = UUID()
        let image: UIImage
        let report: ScreenDetector.Report?
        let cars: [SpotPipeline.FoundCar]
    }
    @State private var pipeline: SpotPipeline?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch status {
            case .starting:
                ProgressView().tint(.white)
            case .failed(let message):
                ContentUnavailableView("Camera unavailable", systemImage: "camera.fill", description: Text(message))
                    .foregroundStyle(.white)
            case .running:
                CameraPreview(session: camera.session).ignoresSafeArea(edges: .top)
                VStack {
                    Spacer()
                    Button(action: capture) {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .background(Circle().fill(.white.opacity(isCapturing ? 0.3 : 0.9)).padding(6))
                            .frame(width: 76, height: 76)
                    }
                    .disabled(isCapturing)
                    .accessibilityLabel("Take photo")
                    .padding(.bottom, 24)
                }
            }
            if driving.access != .allowed {
                PassengerCheckView(access: driving.access,
                                   onPassenger: driving.confirmPassenger,
                                   onDriver: driving.declareDriver)
            }
        }
        .task {
            driving.start()
            do {
                try await camera.start()
                status = .running
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
        .onDisappear {
            camera.stop()
            driving.stop()
        }
        .sheet(item: $result) { r in
            SpotReviewView(app: app, photo: r.image, report: r.report, cars: r.cars,
                           location: driving.lastLocation.map { ($0.coordinate.latitude, $0.coordinate.longitude) })
        }
    }

    private func capture() {
        guard driving.access == .allowed else { return }
        isCapturing = true
        Task {
            defer { isCapturing = false }
            do {
                let shot = try await camera.capture()
                if pipeline == nil { pipeline = try SpotPipeline(catalog: app.catalog) }
                let pipeline = self.pipeline!
                let (report, cars) = try await Task.detached(priority: .userInitiated) {
                    let report = ScreenDetector().evaluate(depth: shot.depth, luminance: shot.luminance,
                                                           width: shot.width, height: shot.height)
                    if case .reject = report.decision { return (report, [SpotPipeline.FoundCar]()) }
                    return (report, try pipeline.run(on: shot.image, depth: shot.uprightDepth, horizontalFOV: shot.horizontalFOV))
                }.value
                result = CaptureResult(image: UIImage(cgImage: shot.image), report: report, cars: cars)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }
}
