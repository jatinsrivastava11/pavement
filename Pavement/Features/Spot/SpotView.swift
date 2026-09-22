import SwiftUI

/// The Spot tab: live camera, shutter, and the screen check on every photo.
struct SpotView: View {
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
        let report: ScreenDetector.Report
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
        .sheet(item: $result) { SpotResultView(result: $0) }
    }

    private func capture() {
        guard driving.access == .allowed else { return }
        isCapturing = true
        Task {
            defer { isCapturing = false }
            do {
                let shot = try await camera.capture()
                let report = await Task.detached(priority: .userInitiated) {
                    ScreenDetector().evaluate(depth: shot.depth, luminance: shot.luminance,
                                              width: shot.width, height: shot.height)
                }.value
                result = CaptureResult(image: UIImage(cgImage: shot.image, scale: 1, orientation: .right), report: report)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }
}

/// Shows whether the photo passed the screen check. The numbers are for calibrating on real phones.
private struct SpotResultView: View {
    let result: SpotView.CaptureResult

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Image(uiImage: result.image).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Section {
                    switch result.report.decision {
                    case .accept:
                        Label("Looks like a real scene", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    case .reject(let reason):
                        Label(reason, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                    }
                }
                Section("Screen check details") {
                    if let depth = result.report.depth {
                        LabeledContent("Depth verdict", value: "\(depth.verdict)")
                        LabeledContent("Distance", value: String(format: "%.2f m", depth.medianDepth))
                        LabeledContent("Flatness error", value: String(format: "%.3f", depth.relativePlaneError))
                        LabeledContent("Depth coverage", value: String(format: "%.0f%%", depth.validSampleFraction * 100))
                    } else {
                        LabeledContent("Depth", value: "Not available on this iPhone")
                    }
                    LabeledContent("Stripe score", value: String(format: "%.2f", result.report.pattern.stripeScore))
                    LabeledContent("Stripe contrast", value: String(format: "%.3f", result.report.pattern.stripeContrast))
                }
            }
            .navigationTitle("Spot check")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
