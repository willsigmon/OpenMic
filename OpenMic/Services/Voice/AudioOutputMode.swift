import Foundation

enum AudioOutputMode: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case speakerphone

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: "Auto Route"
        case .speakerphone: "Speakerphone"
        }
    }

    var subtitle: String {
        switch self {
        case .automatic:
            "Use system routing (Bluetooth/car when available)."
        case .speakerphone:
            "Force loudspeaker + built-in mic for call-style audio."
        }
    }

    static let defaultMode: Self = .speakerphone
}
