import SwiftUI

// MARK: - Contextual Tooltip
//
// Lightweight "first-use" tooltip anchored to any view.
// Gated by @AppStorage("hasSeenTooltip_<id>") — shows exactly once per installation.
// Spring entrance, auto-dismisses after 3 seconds, respects accessibilityReduceMotion.
// Styled with GlassBackground (OpenMic midnight-dashboard aesthetic).

// MARK: - Supporting Types

/// Which edge of the anchor the tooltip appears on.
public enum TooltipEdge: Sendable {
    case top, bottom, leading, trailing
}

// MARK: - Arrow Shape

private struct TooltipArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Tooltip View

private struct OpenMicTooltipView: View {
    let text: String
    let edge: TooltipEdge
    let onDismiss: () -> Void

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if edge == .bottom {
                arrowView.rotationEffect(.degrees(180))
            }

            tooltipCard

            if edge == .top {
                arrowView
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(entranceOffset)
        .onAppear {
            let animation: Animation = reduceMotion
                ? .linear(duration: 0.15)
                : .spring(response: 0.45, dampingFraction: 0.72)

            withAnimation(animation) {
                isVisible = true
            }
        }
    }

    private var tooltipCard: some View {
        HStack(spacing: 10) {
            Text(text)
                .font(OpenMicTheme.Typography.callout)
                .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, OpenMicTheme.Spacing.sm)
        .padding(.vertical, OpenMicTheme.Spacing.xs)
        .modifier(GlassBackground(cornerRadius: OpenMicTheme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md, style: .continuous)
                .strokeBorder(OpenMicTheme.Colors.accent.opacity(0.30), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
    }

    private var arrowView: some View {
        TooltipArrow()
            .fill(OpenMicTheme.Colors.surfaceGlass)
            .frame(width: 18, height: 9)
            .overlay(
                TooltipArrow()
                    .stroke(OpenMicTheme.Colors.accent.opacity(0.30), lineWidth: 0.75)
            )
    }

    private var entranceOffset: CGSize {
        guard !reduceMotion, !isVisible else { return .zero }
        switch edge {
        case .top:      return CGSize(width: 0, height: -8)
        case .bottom:   return CGSize(width: 0, height: 8)
        case .leading:  return CGSize(width: -8, height: 0)
        case .trailing: return CGSize(width: 8, height: 0)
        }
    }
}

// MARK: - View Modifier

private struct ContextualTooltipModifier: ViewModifier {
    let id: String
    let text: String
    let edge: TooltipEdge
    let condition: Bool

    @AppStorage private var hasSeen: Bool
    @State private var showTooltip = false
    @State private var tooltipTask: Task<Void, Never>?

    init(id: String, text: String, edge: TooltipEdge, condition: Bool) {
        self.id = id
        self.text = text
        self.edge = edge
        self.condition = condition
        self._hasSeen = AppStorage(wrappedValue: false, "hasSeenTooltip_\(id)")
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: overlayAlignment) {
                if showTooltip {
                    OpenMicTooltipView(text: text, edge: edge) {
                        dismiss()
                    }
                    .padding(overlayPadding)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .zIndex(999)
                }
            }
            .onAppear {
                guard condition, !hasSeen else { return }
                tooltipTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                        showTooltip = true
                    }
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    dismiss()
                }
            }
            .onDisappear {
                tooltipTask?.cancel()
                tooltipTask = nil
            }
    }

    private func dismiss() {
        tooltipTask?.cancel()
        tooltipTask = nil
        withAnimation(.easeOut(duration: 0.2)) {
            showTooltip = false
        }
        hasSeen = true
    }

    private var overlayAlignment: Alignment {
        switch edge {
        case .top:      return .top
        case .bottom:   return .bottom
        case .leading:  return .leading
        case .trailing: return .trailing
        }
    }

    private var overlayPadding: EdgeInsets {
        switch edge {
        case .top:      return EdgeInsets(top: 6, leading: 12, bottom: 0, trailing: 12)
        case .bottom:   return EdgeInsets(top: 0, leading: 12, bottom: 6, trailing: 12)
        case .leading:  return EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 0)
        case .trailing: return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 6)
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Attaches a one-time contextual tooltip anchored to the given edge.
    ///
    /// The tooltip is gated by `@AppStorage("hasSeenTooltip_<id>")` and shows once.
    /// Auto-dismisses after 3 seconds. The `isVisible` parameter acts as an additional
    /// guard — set to `false` to suppress the tooltip regardless of seen state.
    ///
    /// - Parameters:
    ///   - id:        Stable identifier used as the AppStorage key suffix.
    ///   - text:      Tooltip body text.
    ///   - edge:      Edge the tooltip appears on relative to the anchor view.
    ///   - isVisible: External condition; tooltip only fires when `true`.
    func contextualTooltip(
        id: String,
        text: String,
        edge: TooltipEdge = .bottom,
        isVisible: Bool = true
    ) -> some View {
        modifier(ContextualTooltipModifier(id: id, text: text, edge: edge, condition: isVisible))
    }
}

// MARK: - Preview

#Preview("Contextual Tooltip") {
    VStack(spacing: 60) {
        Button("Switch Provider") {}
            .buttonStyle(.borderedProminent)
            .tint(OpenMicTheme.Colors.accent)
            .contextualTooltip(
                id: "preview_provider_switch",
                text: "You can switch between AI providers anytime in Settings.",
                edge: .bottom
            )

        Button("Start Voice Session") {}
            .buttonStyle(.bordered)
            .contextualTooltip(
                id: "preview_voice_session",
                text: "Hold the mic button to start a hands-free conversation.",
                edge: .top
            )
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(OpenMicTheme.Colors.background)
}
