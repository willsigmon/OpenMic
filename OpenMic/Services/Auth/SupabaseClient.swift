import Foundation
import Supabase

enum SupabaseConfig {
    /// Whether Supabase is configured (both URL and key present in Info.plist)
    static let isConfigured: Bool = {
        url != nil && anonKey != nil
    }()

    /// Load from Info.plist (set via xcconfig or build settings). Nil when unconfigured.
    static let url: URL? = {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !urlString.isEmpty,
              urlString != "$(SUPABASE_URL)" else {
            return nil
        }
        return URL(string: urlString)
    }()

    static let anonKey: String? = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty,
              key != "$(SUPABASE_ANON_KEY)" else {
            return nil
        }
        return key
    }()

    static var functionsBaseURL: URL? {
        url?
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
    }

    static var realtimeProxyURL: URL? {
        functionsBaseURL?.appendingPathComponent("realtime-proxy")
    }

    static var managedChatFunctionURL: URL? {
        functionsBaseURL?.appendingPathComponent("managed-chat")
    }
}

/// Lazily initialized Supabase client. Nil when SUPABASE_URL / SUPABASE_ANON_KEY are missing.
@MainActor
let supabase: SupabaseClient? = {
    guard let url = SupabaseConfig.url, let key = SupabaseConfig.anonKey else {
        return nil
    }
    return SupabaseClient(
        supabaseURL: url,
        supabaseKey: key,
        options: .init(
            auth: .init(
                redirectToURL: URL(string: "com.willsigmon.openmic://auth-callback"),
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}()
