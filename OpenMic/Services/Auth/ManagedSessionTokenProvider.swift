import Foundation

enum ManagedSessionTokenProvider {
    static func accessToken() async throws -> String {
        try await tokenOnMainActor()
    }

    @MainActor
    private static func tokenOnMainActor() async throws -> String {
        guard let supabase else {
            throw AIProviderError.configurationMissing("Supabase not configured")
        }
        // This throws when no valid session exists — callers must handle the error
        // and surface it as "sign in required". Never fall back to the anon key,
        // which is a public credential and must not be used as a user auth token.
        let session = try await supabase.auth.session
        return session.accessToken
    }
}
