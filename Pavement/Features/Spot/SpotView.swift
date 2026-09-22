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

    #if DEBUG
    /// Debug builds can use a photo file as a stand-in camera (the simulator has none):
    /// launch with `-previewCameraImage /path/to/photo.jpg`.
    private let debugImage = UserDefaults.standard.string(forKey: "previewCameraImage").flatMap(UIImage.init(contentsOfFile:))
    #else
    private let debugImage: UIImage? = nil
    #endif

    @ViewBuilder private var preview: some View {
        if let debugImage {
            // Fill the screen without making the layout wider than it.
            Color.clear.overlay(Image(uiImage: debugImage).resizable().scaledToFill()).clipped()
        } else {
            CameraPreview(session: camera.session)
        }
    }

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
                preview.ignoresSafeArea(edges: .top)
                ViewfinderFrame().padding(.horizontal, 28).padding(.vertical, 140).allowsHitTesting(false)
                VStack {
                    Text(isCapturing ? "Looking for cars…" : "Point at cars and tap")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 70)
                    Spacer()
                    ShutterButton(isBusy: isCapturing, action: capture)
                        .padding(.bottom, 28)
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
            if debugImage != nil { status = .running; return }
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
                let shot: CameraController.Capture
                #if DEBUG
                if let still = debugImage.flatMap(CameraController.Capture.init(stillImage:)) {
                    shot = still
                } else {
                    shot = try await camera.capture()
                }
                #else
                shot = try await camera.capture()
                #endif
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

/// Corner brackets that frame the camera view.
private struct ViewfinderFrame: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, l: CGFloat = 36
            Path { p in
                for (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (w, 0, -1, 1), (0, h, 1, -1), (w, h, -1, -1)] {
                    p.move(to: CGPoint(x: x, y: y + dy * l)); p.addLine(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x + dx * l, y: y))
                }
            }
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
    }
}

/// The shutter: a white ring with a yellow core, which spins while photos are processed.
private struct ShutterButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 5).frame(width: 82, height: 82)
                Circle().fill(Theme.accent.opacity(isBusy ? 0.35 : 1)).frame(width: 64, height: 64)
                if isBusy { ProgressView().tint(.black) }
            }
        }
        .disabled(isBusy)
        .accessibilityLabel(isBusy ? "Processing photo" : "Take photo")
    }
}
