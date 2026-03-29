import SwiftUI

// MARK: - NavigationStack Zoom Transition Helpers
//
// These modifiers abstract the iOS 18 zoom navigation transition API.
// On iOS 17 and below they compile and run but produce no effect —
// the push transition degrades to the default slide.
//
// Usage:
//
//   NavigationLink {
//       DetailView()
//           .applyZoomTransition(id: item.id, namespace: ns)
//   } label: {
//       RowView()
//           .applyZoomTransitionSource(id: item.id, namespace: ns)
//   }
//
// Both modifiers must use the same id and namespace.

extension View {
    /// Marks this view as the **source** of a zoom navigation transition.
    /// The system morphs this view's frame into the destination when the
    /// NavigationLink is activated.
    ///
    /// Requires iOS 18+ — no-op on earlier versions.
    @ViewBuilder
    func applyZoomTransitionSource(id: some Hashable, namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Declares the **destination** view of a zoom navigation transition.
    /// The system morphs the source's frame into this view's frame during
    /// the push animation.
    ///
    /// Requires iOS 18+ — no-op on earlier versions.
    @ViewBuilder
    func applyZoomTransition(id: some Hashable, namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
