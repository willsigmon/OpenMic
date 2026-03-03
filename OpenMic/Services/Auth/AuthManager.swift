import Foundation
import AuthenticationServices
import Supabase

enum AuthState: Sendable, Equatable {
    case anonymous
    case authenticated(userID: String)
    case byok

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }

    var isBYOK: Bool {
        if case .byok = self { return true }
        return false
    }

    var userDisplayName: String {
        switch self {
        case .anonymous: "Guest"
        case .authenticated: "Signed In"
        case .byok: "Power User"
        }
    }
}

enum AuthManagerError: LocalizedError {
    case notAuthenticated
    case deleteAccountFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be signed in to delete your account."
        case let .deleteAccountFailed(reason):
            return "Account deletion failed: \(reason)"
        }
    }
}

@Observable
@MainActor
final class AuthManager {
    private(set) var authState: AuthState = .anonymous
    private(set) var currentUserID: String?
    private(set) var currentEmail: String?

    private let deviceID: String

    init() {
        self.deviceID = Self.getOrCreateDeviceID()
        // Check for BYOK mode
        if UserDefaults.standard.bool(forKey: "byokMode") {
            authState = .byok
        }
    }

    // MARK: - Session Restoration

    func restoreSession() async {
        // Check BYOK first
        if UserDefaults.standard.bool(forKey: "byokMode") {
            authState = .byok
            return
        }

        do {
            let session = try await supabase.auth.session
            currentUserID = session.user.id.uuidString
            currentEmail = session.user.email
            authState = .authenticated(userID: session.user.id.uuidString)
        } catch {
            // No valid session — stay anonymous
            authState = .anonymous
            currentUserID = nil
        }
    }

    // MARK: - Sign In with Apple

    func signInWithApple(
        idToken: String,
        nonce: String
    ) async throws {
        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        currentUserID = session.user.id.uuidString
        currentEmail = session.user.email
        authState = .authenticated(userID: session.user.id.uuidString)

        // Merge anonymous usage into authenticated account
        await mergeAnonymousUsage(userID: session.user.id.uuidString)
    }

    // MARK: - Anonymous Auth

    func ensureAnonymousSession() async {
        guard authState == .anonymous, currentUserID == nil else { return }

        do {
            let session = try await supabase.auth.signInAnonymously()
            currentUserID = session.user.id.uuidString
            authState = .anonymous
        } catch {
            // Stay anonymous without Supabase session — use device ID for quota
            currentUserID = nil
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            // Best effort
        }
        currentUserID = nil
        currentEmail = nil
        authState = .anonymous
    }

    // MARK: - Account Deletion

    func deleteAccount() async throws {
        guard authState.isAuthenticated else {
            throw AuthManagerError.notAuthenticated
        }

        do {
            let session = try await supabase.auth.session
            try await supabase.functions.invoke(
                "delete-account",
                options: .init(
                    method: .post,
                    headers: [
                        "Authorization": "Bearer \(session.accessToken)"
                    ]
                )
            )
        } catch {
            throw AuthManagerError.deleteAccountFailed(
                reason: error.localizedDescription
            )
        }

        currentUserID = nil
        currentEmail = nil
        authState = .anonymous
        UserDefaults.standard.set(false, forKey: "byokMode")

        do {
            try await supabase.auth.signOut()
        } catch {
            // Best effort. Session may already be invalidated after deletion.
        }
    }

    // MARK: - BYOK Mode

    func enableBYOKMode() {
        UserDefaults.standard.set(true, forKey: "byokMode")
        authState = .byok
    }

    func disableBYOKMode() {
        UserDefaults.standard.set(false, forKey: "byokMode")
        Task {
            await restoreSession()
        }
    }

    // MARK: - Device ID

    var effectiveDeviceID: String { deviceID }

    private static func getOrCreateDeviceID() -> String {
        let key = "openmic.device.id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: key)
        return newID
    }

    // MARK: - Usage Migration

    private func mergeAnonymousUsage(userID: String) async {
        // Transfer any anonymous usage_events to the authenticated user
        do {
            try await supabase.rpc(
                "merge_anonymous_usage",
                params: [
                    "p_device_id": deviceID,
                    "p_user_id": userID,
                ]
            ).execute()
        } catch {
            // Non-critical — anonymous usage data may be lost
        }
    }
}
