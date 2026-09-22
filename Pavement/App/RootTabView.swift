import SwiftUI

/// The app's five main sections.
struct RootTabView: View {
    let auth: AuthModel
    let app: AppModel

    enum Section: String { case spot, spots, rankings, friends, profile }

    // Debug builds can open on a given tab with the launch argument `-initialTab spots`.
    @State private var selection = Section(rawValue: UserDefaults.standard.string(forKey: "initialTab") ?? "") ?? .spot

    var body: some View {
        TabView(selection: $selection) {
            Tab("Spot", systemImage: "camera.viewfinder", value: .spot) {
                SpotView(app: app)
            }
            Tab("Spots", systemImage: "square.grid.2x2", value: .spots) {
                SpotsView(app: app)
            }
            Tab("Rankings", systemImage: "chart.bar", value: .rankings) {
                PlaceholderScreen(title: "Rankings", owner: "Studio", icon: "chart.bar")
            }
            Tab("Friends", systemImage: "person.2", value: .friends) {
                PlaceholderScreen(title: "Friends", owner: "Courier", icon: "person.2")
            }
            Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
                ProfileView(auth: auth)
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootTabView(auth: AuthModel(), app: .demo())
}
