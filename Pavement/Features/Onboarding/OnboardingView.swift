import SwiftUI

/// Three screens shown once, before the first spot: what Pavement is, safety, and why it asks for
/// camera, motion and location.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    struct Page {
        let symbol: String
        let title: String
        let body: String
        let tint: Color
    }

    static let pages = [
        Page(symbol: "camera.viewfinder", title: "Spot cars. Earn Octane.",
             body: "Snap any street and Pavement finds the cars in it. Rarer cars earn more Octane, from Common all the way to Legendary.",
             tint: Theme.accent),
        Page(symbol: "car.fill", title: "Passengers only.",
             body: "Never spot while driving. If Pavement senses a moving car, it asks if you're a passenger, and stays locked if you're driving.",
             tint: RarityTier.exotic.color),
        Page(symbol: "lock.shield", title: "What Pavement uses",
             body: "Camera: to take spots (no uploads, so every car is real).\nMotion and location: to tell when you're in a moving car, and to show the city on share cards.\nYour photos never leave your phone.",
             tint: RarityTier.niche.color),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Self.pages.indices, id: \.self) { i in
                    let p = Self.pages[i]
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: p.symbol).font(.system(size: 72, weight: .semibold)).foregroundStyle(p.tint)
                        Text(p.title).font(.largeTitle.weight(.heavy)).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(p.body).font(.body).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(32)
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page < Self.pages.count - 1 { withAnimation { page += 1 } } else { onFinish() }
            } label: {
                Text(page < Self.pages.count - 1 ? "Next" : "Start spotting")
                    .font(.headline).frame(maxWidth: .infinity).padding()
                    .foregroundStyle(.black)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            }
            .padding(Theme.spacing)
        }
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}

#Preview { OnboardingView {} }
