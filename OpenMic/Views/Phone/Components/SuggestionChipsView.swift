import SwiftUI

struct SuggestionChipsView: View {
    let suggestions: [PromptSuggestions.Suggestion]
    let onTap: (PromptSuggestions.Suggestion) -> Void
    let onRefresh: (() -> Void)?
    var isLoading: Bool = false

    @State private var appeared = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: OpenMicTheme.Spacing.md) {
            HStack(spacing: OpenMicTheme.Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)

                Text("Ask me anything")
                    .font(OpenMicTheme.Typography.callout)
                    .foregroundStyle(OpenMicTheme.Colors.textSecondary)
            }
            .opacity(appeared && !isLoading ? 1 : 0)

            if isLoading {
                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in
                        SuggestionChipSkeleton()
                    }
                }
            } else {
                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                        PromptCard(suggestion: suggestion) {
                            Haptics.tap()
                            onTap(suggestion)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.82)
                                .delay(Double(index) * 0.05),
                            value: appeared
                        )
                    }
                }
            }

            if let onRefresh {
                Button {
                    Haptics.tap()
                    onRefresh()
                } label: {
                    Label("More ideas", systemImage: "arrow.clockwise")
                        .font(OpenMicTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.openMicActionPill(tone: .accent))
                .accessibilityIdentifier(
                    AppAccessibilityID.conversationSuggestionsRefresh
                )
                .padding(.top, OpenMicTheme.Spacing.xxs)
            }
        }
        .accessibilityIdentifier(AppAccessibilityID.conversationSuggestions)
        .onAppear {
            withAnimation {
                appeared = true
            }
        }
        .onChange(of: suggestions) { _, _ in
            appeared = false
            withAnimation(.easeOut(duration: 0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Individual Prompt Card

private struct PromptCard: View {
    let suggestion: PromptSuggestions.Suggestion
    let action: () -> Void

    private var tint: Color {
        TopicColor.color(for: suggestion.topic)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                // Large watermark icon in background
                Image(systemName: suggestion.icon)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(tint.opacity(0.08))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 8)
                    .padding(.bottom, 6)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.topic.uppercased())
                        .font(.system(size: 18, design: .rounded).weight(.heavy))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(suggestion.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .contentShape(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(PromptCardButtonStyle(tint: tint))
        .modifier(TiltCardModifier())
        .accessibilityIdentifier(
            AppAccessibilityID.suggestionCard(suggestion.id)
        )
        .accessibilityLabel(suggestion.text)
        .accessibilityHint("Sends this as a conversation starter")
    }
}

// MARK: - Button Style

private struct PromptCardButtonStyle: ButtonStyle {
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let isDark = colorScheme == .dark

        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(isDark ? 0.10 : 0.07),
                                tint.opacity(isDark ? 0.04 : 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isDark
                                ? Color.white.opacity(pressed ? 0.06 : 0.04)
                                : Color.black.opacity(pressed ? 0.04 : 0.02)
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        tint.opacity(pressed ? 0.35 : 0.18),
                        lineWidth: pressed ? 1.2 : 0.7
                    )
            )
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.75),
                value: pressed
            )
    }
}

// MARK: - Topic → Color Mapping

private enum TopicColor {
    static func color(for topic: String) -> Color {
        switch topic {
        case "News":          return Color(red: 0.30, green: 0.56, blue: 1.00)  // blue
        case "Weather":       return Color(red: 0.20, green: 0.75, blue: 0.85)  // sky
        case "Motivation":    return Color(red: 1.00, green: 0.60, blue: 0.20)  // orange
        case "Learn", "Learning":
                              return Color(red: 0.55, green: 0.40, blue: 0.95)  // purple
        case "Fun":           return Color(red: 1.00, green: 0.45, blue: 0.55)  // pink
        case "Trivia":        return Color(red: 0.40, green: 0.80, blue: 0.45)  // green
        case "Food":          return Color(red: 0.95, green: 0.50, blue: 0.30)  // coral
        case "Stories":       return Color(red: 0.65, green: 0.45, blue: 0.80)  // lavender
        case "Calm":          return Color(red: 0.35, green: 0.78, blue: 0.65)  // mint
        case "Entertainment": return Color(red: 0.85, green: 0.35, blue: 0.55)  // magenta
        case "Games":         return Color(red: 0.25, green: 0.70, blue: 0.95)  // cerulean
        case "Deep Talk":     return Color(red: 0.50, green: 0.35, blue: 0.75)  // indigo
        case "Outings":       return Color(red: 0.45, green: 0.80, blue: 0.35)  // lime
        case "Travel":        return Color(red: 0.20, green: 0.65, blue: 0.90)  // azure
        case "Podcasts":      return Color(red: 0.70, green: 0.30, blue: 0.90)  // violet
        case "Jokes":         return Color(red: 1.00, green: 0.72, blue: 0.20)  // gold
        case "Debate":        return Color(red: 0.90, green: 0.40, blue: 0.30)  // red-orange
        case "Ideas":         return Color(red: 0.00, green: 0.80, blue: 0.75)  // teal
        case "Life Hacks":    return Color(red: 0.80, green: 0.65, blue: 0.20)  // amber
        case "History":       return Color(red: 0.60, green: 0.50, blue: 0.40)  // bronze
        case "Roast":         return Color(red: 1.00, green: 0.35, blue: 0.20)  // fire
        default:              return OpenMicTheme.Colors.accentGradientStart
        }
    }
}
