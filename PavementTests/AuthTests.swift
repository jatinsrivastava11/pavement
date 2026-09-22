import Foundation
import Testing
@testable import Pavement

struct AuthValidationTests {
    @Test("Accepts well-formed email and long enough password", arguments: [
        "driver@example.com", "  Driver@Example.com  ", "a.b+cars@mail.co.uk",
    ])
    func acceptsValidInput(email: String) {
        #expect(AuthModel.validationError(email: email, password: "12345678") == nil)
    }

    @Test("Rejects malformed emails", arguments: [
        "", "driver", "driver@", "@example.com", "driver@example", "driver@.com", "a@b@c.com",
    ])
    func rejectsBadEmail(email: String) {
        #expect(AuthModel.validationError(email: email, password: "12345678") == "Enter a valid email address.")
    }

    @Test("Password must be at least 8 characters")
    func passwordLength() {
        #expect(AuthModel.validationError(email: "a@b.com", password: "1234567") != nil)
        #expect(AuthModel.validationError(email: "a@b.com", password: "12345678") == nil)
    }

    @Test("Emails are trimmed and lowercased before sending")
    func normalizesEmail() {
        #expect(AuthModel.normalized("  Driver@Example.COM\n") == "driver@example.com")
    }
}

/// These talk to the real Supabase project, so they need an internet connection.
@MainActor
struct SupabaseAuthIntegrationTests {
    @Test("Signing in with a wrong password is rejected as invalid credentials")
    func wrongPasswordIsRejected() async {
        let auth = AuthModel()
        let email = "nobody-\(UUID().uuidString.prefix(8).lowercased())@pavement-test.dev"
        do {
            try await auth.signIn(email: email, password: "definitely-wrong-password")
            Issue.record("Sign-in unexpectedly succeeded")
        } catch {
            // A bad key or unreachable server produces a different message, so this also proves
            // the app is talking to the right project with a valid key.
            #expect(AuthModel.message(for: error) == "Wrong email or password.")
        }
    }
}
