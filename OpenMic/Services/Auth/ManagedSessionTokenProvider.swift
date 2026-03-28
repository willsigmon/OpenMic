import Foundation

enum ManagedSessionTokenProvider {
    static func accessToken() async throws -> String {
        try await tokenOnMainActor()
    }

    @MainActor
    private static func tokenOnMainActor() async throws -> String {
        if let supabase, let session = try? await supabase.auth.session {
            return session.accessToken
        }

        if let key = SupabaseConfig.anonKey {
            return key
        }

        return ""
    }
}
