import Foundation
import Supabase

enum SupabaseConfig {
    /// Load from Info.plist (set via xcconfig or build settings)
    static let url: URL = {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            return url
        }
        // Fallback for development — set your project URL here or via xcconfig
        return URL(string: "https://jzkqowkvvvhiyktkaisb.supabase.co")!
    }()

    static let anonKey: String = {
        if let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
           !key.isEmpty {
            return key
        }
        // Fallback for development — set your anon key here or via xcconfig
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6a3Fvd2t2dnZoaXlrdGthaXNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEyNzE4MTgsImV4cCI6MjA4Njg0NzgxOH0.BMzW-LZsQtAGrTNvi_g57u-kAHFO9TehHpVH-v2DVXM"
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
