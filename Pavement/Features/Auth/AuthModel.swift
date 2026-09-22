import Foundation
import Observation
import Supabase

/// Tracks whether someone is signed in, and handles sign-in, sign-up and sign-out.
@MainActor
@Observable
final class AuthModel {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(email: String)
    }

    enum SignUpResult: Equatable {
        case signedIn
        case needsEmailConfirmation
    }

    private(set) var state: State = .loading
    private let client: SupabaseClient

    init(client: SupabaseClient = supabase) {
        self.client = client
    }

    /// Follows the saved session and every later sign-in or sign-out. Runs for the app's lifetime.
    func observeSession() async {
        for await (_, session) in client.auth.authStateChanges {
            if let session, !session.isExpired {
                state = .signedIn(email: session.user.email ?? "")
            } else {
                state = .signedOut
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: Self.normalized(email), password: password)
    }

    func signUp(email: String, password: String) async throws -> SignUpResult {
        let response = try await client.auth.signUp(email: Self.normalized(email), password: password)
        return response.session == nil ? .needsEmailConfirmation : .signedIn
    }

    /// Deletes the account on the server (profile, spots and friendships go with it), then signs out.
    /// Needs `supabase/migrations/0004_delete_account.sql`.
    func deleteAccount() async throws {
        try await client.rpc("delete_my_account").execute()
        try? await client.auth.signOut()
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    // MARK: - Validation and messages

    nonisolated static let minimumPasswordLength = 8

    nonisolated static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Returns a problem to show before contacting the server, or `nil` if the input looks fine.
    nonisolated static func validationError(email: String, password: String) -> String? {
        let email = normalized(email)
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        let looksLikeEmail = parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
            && !parts[1].hasPrefix(".") && !parts[1].hasSuffix(".")
        if !looksLikeEmail { return "Enter a valid email address." }
        if password.count < minimumPasswordLength {
            return "Password must be at least \(minimumPasswordLength) characters."
        }
        return nil
    }

    /// Turns a server error into something a person can act on.
    nonisolated static func message(for error: any Error) -> String {
        guard let authError = error as? AuthError else {
            return "Couldn't reach Pavement. Check your connection and try again."
        }
        switch authError.errorCode {
        case .invalidCredentials: return "Wrong email or password."
        case .emailNotConfirmed: return "Confirm your email first. Check your inbox for the link."
        case .userAlreadyExists, .emailExists: return "An account with this email already exists. Try signing in."
        case .weakPassword: return "That password is too weak. Try a longer one."
        case .overEmailSendRateLimit, .overRequestRateLimit: return "Too many attempts. Wait a minute and try again."
        default: return authError.message
        }
    }
}
