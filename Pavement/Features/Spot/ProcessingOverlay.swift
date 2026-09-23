import SwiftUI

/// Shown over the camera from the moment the shutter fires until the photo has been examined.
///
/// It exists for two reasons. It tells you the photo was taken, which a camera that simply pauses
/// does not. And it buys the recognizer a couple of seconds of honest working time, so identifying
/// a car can afford to be thorough (several models consulted, the car checked from several angles)
/// instead of being rushed into a snap answer.
struct ProcessingOverlay: View {
    /// What the app is busy with, so the wait says something rather than just spinning.
    let stage: Stage

    enum Stage: Equatable {
        case looking, identifying(Int)

        var message: String {
            switch self {
            case .looking: "Looking for cars…"
            case .identifying(let count): count == 1 ? "Identifying 1 car…" : "Identifying \(count) cars…"
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 18) {
                ring
                Text(stage.message)
                    .font(.headline)
                    // The blur behind this takes its lightness from the photo and the system
                    // appearance, so the label has to follow it rather than a fixed theme colour,
                    // or it turns white-on-white over a bright street.
                    .foregroundStyle(.primary)
                    .contentTransition(.opacity)
            }
        }
        .transition(.opacity)
        // One spoken announcement rather than a spinner VoiceOver cannot describe.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stage.message)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.3), lineWidth: 5)
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(sweep ? 360 : 0))
        }
        .frame(width: 58, height: 58)
        .onAppear {
            // A still ring would read as "stuck"; a slow sweep reads as "working".
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { sweep = true }
        }
    }
}

#Preview { ProcessingOverlay(stage: .identifying(2)).background(Theme.background) }
