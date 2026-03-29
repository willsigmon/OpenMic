import SwiftUI

// MARK: - Shimmer Modifier

/// Applies a shimmer sweep to any view using `.screen` blendMode.
/// The `.screen` compositing produces a visible highlight on dark OpenMic surfaces
/// without blowing out light backgrounds — more realistic than a plain opacity overlay.
///
/// Respects `accessibilityReduceMotion` — substitutes a static center highlight.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if reduceMotion {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.2),
                            .init(color: .white.opacity(0.25), location: 0.5),
                            .init(color: .clear, location: 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                } else {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: max(0, phase - 0.3)),
                            .init(color: .white.opacity(0.4), location: phase),
                            .init(color: .clear, location: min(1, phase + 0.3))
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 1.5)
                            .repeatForever(autoreverses: false)
                        ) {
                            phase = 2.0
                        }
                    }
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// Applies the shimmer sweep effect.
    /// - Parameter isActive: Set to `false` to show the view without shimmer —
    ///   useful for toggling off after data loads without restructuring the view tree.
    @ViewBuilder
    func shimmer(isActive: Bool = true) -> some View {
        if isActive {
            modifier(ShimmerModifier())
        } else {
            self
        }
    }
}

// MARK: - Skeleton Shape

/// Generic skeleton placeholder with shimmer. Prefer over `.redacted(reason:)`
/// because it fits the Midnight Dashboard dark surface aesthetic.
struct SkeletonShape: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = OpenMicTheme.Radius.sm

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.quaternary)
            .frame(width: width, height: height)
            .shimmer()
    }
}
