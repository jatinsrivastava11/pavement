import SwiftUI

/// Covers the camera while spotting isn't allowed, and asks the passenger question.
struct PassengerCheckView: View {
    let access: SpotGate.Access
    let onPassenger: () -> Void
    let onDriver: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            switch access {
            case .askPassenger:
                Image(systemName: "car.fill").font(.system(size: 48))
                Text("Looks like you're in a moving car").font(.title2.bold()).multilineTextAlignment(.center)
                Text("Only passengers can spot. Never spot while driving.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                SlideToConfirm(label: "Slide if you're a passenger", action: onPassenger)
                Button("I'm driving", role: .destructive, action: onDriver).font(.headline)
            case .blockedDriving:
                Image(systemName: "steeringwheel").font(.system(size: 48))
                Text("Spotting paused while you drive").font(.title2.bold()).multilineTextAlignment(.center)
                Text("It unlocks once the car has stopped for a few minutes.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            case .blockedCarPlay:
                Image(systemName: "carplay").font(.system(size: 48))
                Text("Spotting is off with CarPlay").font(.title2.bold()).multilineTextAlignment(.center)
                Text("This phone looks like the driver's. Spotting unlocks when the car stops.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            case .allowed:
                EmptyView()
            }
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

/// A slider that must be dragged all the way across, so it can't be tapped without looking.
struct SlideToConfirm: View {
    let label: String
    let action: () -> Void
    @State private var offset: CGFloat = 0
    private let knob: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let maxOffset = geo.size.width - knob
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Text(label).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                    .opacity(1 - offset / max(maxOffset, 1))
                Circle().fill(.tint).frame(width: knob, height: knob)
                    .overlay(Image(systemName: "chevron.right.2").foregroundStyle(.white))
                    .offset(x: offset)
                    .gesture(DragGesture()
                        .onChanged { offset = min(max(0, $0.translation.width), maxOffset) }
                        .onEnded { _ in
                            if offset > maxOffset * 0.95 { action() }
                            withAnimation(.spring) { offset = 0 }
                        })
            }
        }
        .frame(height: knob)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Confirm") { action() }
    }
}
