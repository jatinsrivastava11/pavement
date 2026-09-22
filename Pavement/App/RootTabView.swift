import SwiftUI

/// The app's five main sections. Each tab is a placeholder until its agent builds it.
struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Spot", systemImage: "camera.viewfinder") {
                PlaceholderScreen(title: "Spot", owner: "Lens", icon: "camera.viewfinder")
            }
            Tab("Spots", systemImage: "square.grid.2x2") {
                PlaceholderScreen(title: "Spots", owner: "Studio + Mechanic", icon: "square.grid.2x2")
            }
            Tab("Rankings", systemImage: "chart.bar") {
                PlaceholderScreen(title: "Rankings", owner: "Backbone + Scout", icon: "chart.bar")
            }
            Tab("Friends", systemImage: "person.2") {
                PlaceholderScreen(title: "Friends", owner: "Courier", icon: "person.2")
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                PlaceholderScreen(title: "Profile", owner: "Backbone", icon: "person.crop.circle")
            }
        }
    }
}

#Preview {
    RootTabView()
}
