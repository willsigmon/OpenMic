import SwiftUI

// MARK: - Spotlight Target ID

/// Identifies spotlight targets for OpenMic feature onboarding
public enum SpotlightTargetID: String, CaseIterable, Hashable, Sendable {
    case micButton
    case providerBadge
    case topicsTab
    case settingsTab

    public var displayName: String {
        switch self {
        case .micButton: return "Mic Button"
        case .providerBadge: return "Provider Badge"
        case .topicsTab: return "Topics"
        case .settingsTab: return "Settings"
        }
    }
}

// MARK: - Spotlight Preference Key

/// Collects spotlight target bounds via anchor preferences.
/// Anchors resolve correctly regardless of safe area insets or
/// tab bar overlays because the geometry is read at the coordinator level.
public struct SpotlightPreferenceKey: PreferenceKey {
    nonisolated(unsafe) public static var defaultValue: [SpotlightTargetID: Anchor<CGRect>] = [:]

    public static func reduce(
        value: inout [SpotlightTargetID: Anchor<CGRect>],
        nextValue: () -> [SpotlightTargetID: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
