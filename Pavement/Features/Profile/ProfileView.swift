import SwiftUI

/// Your profile: Octane, collection progress per tier, and sign out.
struct ProfileView: View {
    let auth: AuthModel
    let app: AppModel
    @AppStorage("appTheme") private var theme = AppTheme.asphalt.rawValue
    @State private var confirmingDelete = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    // A standard picker: it scales correctly with the reader's text size.
                    Picker(selection: $theme) {
                        ForEach(AppTheme.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    } label: {
                        Text("Look").foregroundStyle(Theme.textPrimary)
                    }
                    Text(AppTheme(rawValue: theme)?.subtitle ?? "")
                        .font(.footnote).foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.surface)
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

                .listRowBackground(Theme.surface)

                if case .signedIn(let email) = auth.state {
                    Section("Signed in as") { Text(email) }.listRowBackground(Theme.surface)
                }
                Section {
                    Button("Sign Out", role: .destructive) { Task { await auth.signOut() } }.foregroundStyle(Theme.danger)
                }
                .listRowBackground(Theme.surface)

                Section {
                    Button("Delete my account and data", role: .destructive) { confirmingDelete = true }.foregroundStyle(Theme.danger)
                } footer: {
                    Text("Removes your account, spots, photos and friends. This can't be undone.")
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Profile")
            .confirmationDialog("Delete your account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { Task { await deleteEverything() } }
            } message: {
                Text("Your account, spots, photos and friends will be permanently deleted.")
            }
            .alert("Couldn't delete your account", isPresented: .constant(deleteError != nil)) {
                Button("OK") { deleteError = nil }
            } message: { Text(deleteError ?? "") }
        }
    }

    private func deleteEverything() async {
        do {
            try await auth.deleteAccount()
            try app.spots.removeAll()
            try app.photos.removeAll()
        } catch {
            deleteError = "Check your connection and try again. Nothing on your phone was deleted."
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
