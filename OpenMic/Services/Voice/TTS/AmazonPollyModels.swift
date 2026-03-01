import Foundation

// MARK: - Amazon Polly Voice

struct AmazonPollyVoice: Identifiable, Sendable {
    let id: String
    let name: String
    let gender: String
    let engine: String
    let languageName: String

    var displayName: String { name }

    var engineLabel: String {
        engine == "neural" ? "Neural" : "Standard"
    }
}

// MARK: - Built-in Voice Catalog (no API call needed)

enum AmazonPollyVoiceCatalog {
    static let englishVoices: [AmazonPollyVoice] = [
        AmazonPollyVoice(id: "Joanna", name: "Joanna", gender: "Female", engine: "neural", languageName: "US English"),
        AmazonPollyVoice(id: "Matthew", name: "Matthew", gender: "Male", engine: "neural", languageName: "US English"),
        AmazonPollyVoice(id: "Salli", name: "Salli", gender: "Female", engine: "neural", languageName: "US English"),
        AmazonPollyVoice(id: "Joey", name: "Joey", gender: "Male", engine: "neural", languageName: "US English"),
        AmazonPollyVoice(id: "Kendra", name: "Kendra", gender: "Female", engine: "neural", languageName: "US English"),
        AmazonPollyVoice(id: "Kimberly", name: "Kimberly", gender: "Female", engine: "neural", languageName: "US English"),
        AmazonPollyVoice(id: "Kevin", name: "Kevin", gender: "Male", engine: "neural", languageName: "US English"),
        AmazonPollyVoice(id: "Ruth", name: "Ruth", gender: "Female", engine: "neural", languageName: "US English"),
        AmazonPollyVoice(id: "Stephen", name: "Stephen", gender: "Male", engine: "neural", languageName: "US English"),
        AmazonPollyVoice(id: "Amy", name: "Amy", gender: "Female", engine: "neural", languageName: "British English"),
        AmazonPollyVoice(id: "Brian", name: "Brian", gender: "Male", engine: "neural", languageName: "British English"),
        AmazonPollyVoice(id: "Emma", name: "Emma", gender: "Female", engine: "neural", languageName: "British English"),
        AmazonPollyVoice(id: "Arthur", name: "Arthur", gender: "Male", engine: "neural", languageName: "British English"),
        AmazonPollyVoice(id: "Olivia", name: "Olivia", gender: "Female", engine: "neural", languageName: "Australian English"),
    ]
}

// MARK: - Errors

enum AmazonPollyError: LocalizedError {
    case synthesizeFailed
    case invalidCredentials
    case credentialsMissing
    case rateLimited
    case emptyResponse
    case signingFailed
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .synthesizeFailed: "Amazon Polly synthesis failed"
        case .invalidCredentials: "Invalid AWS credentials"
        case .credentialsMissing: "AWS credentials not configured"
        case .rateLimited: "Amazon Polly rate limit reached — wait a moment"
        case .emptyResponse: "Amazon Polly returned empty audio data"
        case .signingFailed: "AWS request signing failed"
        case .networkError(let msg): "Amazon Polly: \(msg)"
        }
    }
}
