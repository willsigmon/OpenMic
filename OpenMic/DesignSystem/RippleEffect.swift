import SwiftUI

// MARK: - Ripple Effect
//
// Material-style radial ripple originating from the precise tap location.
// Uses .simultaneousGesture so parent Button/tap handler fires normally.
// Respects accessibilityReduceMotion — skips animation entirely when set.

// MARK: - Ripple Data

private struct RippleData: Identifiable {
    let id = UUID()
    let position: CGPoint
    var scale: CGFloat = 0
    var opacity: Double = 0.30
}

// MARK: - Modifier

public struct RippleEffectModifier: ViewModifier {
    let color: Color
    let duration: Double

    @State private var ripples: [RippleData] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(color: Color = OpenMicTheme.Colors.accent, duration: Double = 0.55) {
        self.color = color
        self.duration = duration
    }

    public func body(content: Content) -> some View {
        content
            .overlay(rippleOverlay)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard ripples.isEmpty, !reduceMotion else { return }
                        spawnRipple(at: value.location)
                    }
            )
    }

    // MARK: - Private

    private var rippleOverlay: some View {
        GeometryReader { _ in
            ZStack {
                ForEach(ripples) { ripple in
                    Circle()
                        .fill(color.opacity(ripple.opacity))
                        .frame(width: 20, height: 20)
                        .scaleEffect(ripple.scale)
                        .position(ripple.position)
                        .allowsHitTesting(false)
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
    }

    private func spawnRipple(at location: CGPoint) {
        let ripple = RippleData(position: location)
        ripples.append(ripple)

        withAnimation(.spring(response: duration, dampingFraction: 0.85)) {
            guard let index = ripples.firstIndex(where: { $0.id == ripple.id }) else { return }
            ripples[index].scale = 15
            ripples[index].opacity = 0
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration + 0.05))
            ripples.removeAll { $0.id == ripple.id }
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Applies a Material-style ripple from the tap point.
    /// Defaults to the OpenMic cyan accent.
    /// Does not consume the tap — safe to combine with Button or .onTapGesture.
    func rippleEffect(
        color: Color = OpenMicTheme.Colors.accent,
        duration: Double = 0.55
    ) -> some View {
        modifier(RippleEffectModifier(color: color, duration: duration))
    }
}

// MARK: - Preview

#Preview("Ripple Effect") {
    VStack(spacing: 20) {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(OpenMicTheme.Colors.surfaceGlass)
            .frame(height: 64)
            .overlay(
                Label("Suggestion Chip", systemImage: "lightbulb")
                    .font(OpenMicTheme.Typography.callout)
            )
            .rippleEffect()

        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(OpenMicTheme.Colors.surfaceGlass)
            .frame(height: 80)
            .overlay(Text("Topic Card").font(OpenMicTheme.Typography.headline))
            .rippleEffect()
    }
    .padding()
    .background(OpenMicTheme.Colors.background)
}
