import SwiftUI

/// The signed-in user's profile. For now: who's signed in, and a sign-out button.
struct ProfileView: View {
    let auth: AuthModel

    var body: some View {
        NavigationStack {
            List {
                if case .signedIn(let email) = auth.state {
                    Section("Signed in as") { Text(email) }
                }
                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
