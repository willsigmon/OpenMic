import Foundation
import Supabase

enum SupabaseConfig {
    /// Load from Info.plist (set via xcconfig or build settings)
    static let url: URL = {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !urlString.isEmpty else {
            preconditionFailure("SUPABASE_URL missing from Info.plist — add it via xcconfig or build settings")
        }
        guard let url = URL(string: urlString) else {
            preconditionFailure("SUPABASE_URL in Info.plist is not a valid URL: \(urlString)")
        }
        return url
    }()

    static let anonKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty else {
            preconditionFailure("SUPABASE_ANON_KEY missing from Info.plist — add it via xcconfig or build settings")
        }
        return key
    }()

    static var functionsBaseURL: URL {
        url
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
    }

    static var realtimeProxyURL: URL {
        functionsBaseURL.appendingPathComponent("realtime-proxy")
    }

    static var managedChatFunctionURL: URL {
        functionsBaseURL.appendingPathComponent("managed-chat")
    }
}

@MainActor
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey,
    options: .init(
        auth: .init(
            redirectToURL: URL(string: "com.willsigmon.openmic://auth-callback"),
            emitLocalSessionAsInitialSession: true
        )
    )
)
