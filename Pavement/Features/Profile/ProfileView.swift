import SwiftUI

/// Your profile: Octane, collection progress per tier, and sign out.
struct ProfileView: View {
    let auth: AuthModel
    let app: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Octane").font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                        OctaneLabel(amount: app.spots.totalOctane, font: .largeTitle)
                        Text("\(app.spots.spots.count) spots · \(app.spots.collection(catalog: app.catalog).count) models")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Theme.surface)

                Section("Collection by tier") {
                    ForEach(ProfileStats.tierProgress(collection: app.spots.collection(catalog: app.catalog), catalog: app.catalog), id: \.tier) { row in
                        HStack {
                            TierBadge(tier: row.tier)
                            Spacer()
                            Text("\(row.collected) / \(row.total)").monospacedDigit().foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
                .listRowBackground(Theme.surface)

                if case .signedIn(let email) = auth.state {
                    Section("Signed in as") { Text(email) }.listRowBackground(Theme.surface)
                }
                Section {
                    Button("Sign Out", role: .destructive) { Task { await auth.signOut() } }
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Profile")
        }
    }
}

enum ProfileStats {
    /// How many models of each tier you've collected, out of how many exist in the catalog.
    static func tierProgress(collection: [CollectionEntry], catalog: CarCatalog) -> [(tier: RarityTier, collected: Int, total: Int)] {
        RarityTier.allCases.map { tier in
            (tier, collection.filter { $0.car.tier == tier }.count, catalog.cars(in: tier).count)
        }
    }
}
