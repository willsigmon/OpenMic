import Foundation

enum ManagedSessionTokenProvider {
    static func accessToken() async throws -> String {
        try await tokenOnMainActor()
    }

    @MainActor
    private static func tokenOnMainActor() async throws -> String {
        if let session = try? await supabase.auth.session {
            return session.accessToken
        }

        return SupabaseConfig.anonKey
    }
}
