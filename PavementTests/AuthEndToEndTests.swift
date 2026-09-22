import Foundation
import Testing
@testable import Pavement

/// Creates a real account in Supabase, so it only runs when asked:
/// `TEST_RUNNER_PAVEMENT_E2E=1 xcodebuild test ...`
/// Each run leaves one throwaway `e2e-…@pavement-test.dev` user behind.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["PAVEMENT_E2E"] == "1"), .serialized)
struct AuthEndToEndTests {
    @Test("Full account lifecycle: sign up, sign out, sign in, rejects bad password and duplicates")
    func accountLifecycle() async throws {
        let auth = AuthModel()
        let email = "e2e-\(UUID().uuidString.prefix(8).lowercased())@pavement-test.dev"
        let password = "Pavement-\(UUID().uuidString.prefix(8))"

        // Sign up signs you straight in (email confirmation is off).
        let result = try await auth.signUp(email: email, password: password)
        #expect(result == .signedIn)
        #expect(supabase.auth.currentSession?.user.email == email)

        await auth.signOut()
        #expect(supabase.auth.currentSession == nil)

        // Wrong password is rejected.
        await #expect(throws: (any Error).self) {
            try await auth.signIn(email: email, password: "wrong-password-123")
        }

        // Right password works.
        try await auth.signIn(email: email, password: password)
        #expect(supabase.auth.currentSession?.user.email == email)
        await auth.signOut()

        // Signing up again with the same email is refused with a clear message.
        do {
            _ = try await auth.signUp(email: email, password: password)
            Issue.record("Duplicate sign-up unexpectedly succeeded")
        } catch {
            #expect(AuthModel.message(for: error) == "An account with this email already exists. Try signing in.")
        }
        #expect(supabase.auth.currentSession == nil)
    }
}
