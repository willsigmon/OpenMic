import SwiftUI

// MARK: - Spotlight Target View Modifier

/// Registers a view as a spotlight target by reporting its bounds
/// through the anchor preference system.
public struct SpotlightTargetModifier: ViewModifier {
    let id: SpotlightTargetID

    public func body(content: Content) -> some View {
        content
            .anchorPreference(
                key: SpotlightPreferenceKey.self,
                value: .bounds
            ) { anchor in
                [id: anchor]
            }
    }
}

// MARK: - View Extension

public extension View {
    /// Marks this view as a spotlight target for feature onboarding.
    /// - Parameter id: The unique identifier for this spotlight target.
    func spotlightTarget(_ id: SpotlightTargetID) -> some View {
        modifier(SpotlightTargetModifier(id: id))
    }
}
