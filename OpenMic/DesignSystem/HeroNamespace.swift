import SwiftUI

// MARK: - Hero Namespace Environment Key

/// An `EnvironmentKey` that carries a `Namespace.ID` for shared-element
/// (matchedGeometryEffect) transitions between views that live in the same
/// view hierarchy simultaneously — e.g. a list row and a detail view that
/// are both rendered at the same time (overlay, sheet, ZStack).
///
/// IMPORTANT — cross-boundary constraint
/// `matchedGeometryEffect` requires both the source and destination views to
/// exist in the same SwiftUI render tree at the same time. It does NOT work:
///   - Across tab switches (the source tab is not in the render tree)
///   - Across sheet/fullScreenCover presentations (different render trees)
///
/// For `NavigationStack` push transitions on iOS 18+ use
/// `.matchedTransitionSource(id:in:)` on the source view and
/// `.navigationTransition(.zoom(sourceID:in:))` on the destination — that
/// is the correct API for NavigationLink-based hero transitions and is what
/// TopicsView uses below.
///
/// Usage (for same-tree shared-element effects):
/// ```swift
/// // Parent that owns the namespace
/// @Namespace private var heroNamespace
/// ChildView().environment(\.heroNamespace, heroNamespace)
///
/// // Source view
/// Image(...).matchedGeometryEffect(id: "avatar-\(id)", in: heroNamespace)
///
/// // Destination view (must be in the same tree simultaneously)
/// Image(...).matchedGeometryEffect(id: "avatar-\(id)", in: heroNamespace, isSource: false)
/// ```
private struct HeroNamespaceKey: EnvironmentKey {
    // nil default — consumers guard against nil before applying the effect.
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// The shared hero-animation namespace, injected by a parent view.
    var heroNamespace: Namespace.ID? {
        get { self[HeroNamespaceKey.self] }
        set { self[HeroNamespaceKey.self] = newValue }
    }
}
