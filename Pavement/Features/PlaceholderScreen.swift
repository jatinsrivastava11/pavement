import SwiftUI

/// Temporary screen shown in a tab until the real feature replaces it.
struct PlaceholderScreen: View {
    let title: String
    let owner: String
    let icon: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                title,
                systemImage: icon,
                description: Text("Coming soon. Built by \(owner).")
            )
            .navigationTitle(title)
        }
    }
}
