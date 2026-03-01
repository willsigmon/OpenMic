import SwiftData
import SwiftUI

// MARK: - Shared View Builders for Voice Engine Sections

/// Reusable BYOK (Bring Your Own Key) card for API key entry.
struct BYOKKeyCard: View {
    let hasKey: Bool
    @Binding var isEditing: Bool
    @Binding var keyText: String
    let placeholder: String
    let providerURL: String
    let onSave: () -> Void

    var body: some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    LayeredFeatureIcon(
                        systemName: "key.fill",
                        color: OpenMicTheme.Colors.accentGradientStart,
                        accentShape: .none
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("API Key")
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        Text(hasKey
                             ? "Your key is securely stored in Keychain"
                             : "Get one at \(providerURL)")
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    }

                    Spacer()
                }

                if isEditing {
                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                        HStack(spacing: OpenMicTheme.Spacing.xs) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                            SecureField(placeholder, text: $keyText)
                                .font(OpenMicTheme.Typography.body)
                                .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .tint(OpenMicTheme.Colors.accentGradientStart)
                        }
                        .padding(OpenMicTheme.Spacing.xs)
                        .glassBackground(cornerRadius: OpenMicTheme.Radius.sm)

                        Button("Save") {
                            onSave()
                        }
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, OpenMicTheme.Spacing.sm)
                        .padding(.vertical, OpenMicTheme.Spacing.xs)
                        .background(Capsule().fill(OpenMicTheme.Gradients.accent))
                    }
                } else {
                    Button(hasKey ? "Update Key" : "Add Key") {
                        isEditing = true
                    }
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                }
            }
        }
    }
}

/// Error card shown when voice listing fails.
struct VoiceErrorCard: View {
    let error: String

    var body: some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
            HStack(spacing: OpenMicTheme.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(OpenMicTheme.Colors.error)
                Text(error)
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.textSecondary)
            }
        }
    }
}

/// Button to trigger loading available voices from an API.
struct LoadVoicesButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                    Text("Load Available Voices")
                        .font(OpenMicTheme.Typography.headline)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// A simple voice selection row with avatar initial, name, detail, and checkmark.
struct SimpleVoiceRow: View {
    let name: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(OpenMicTheme.Animation.fast) {
                action()
            }
        } label: {
            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(OpenMicTheme.Colors.speaking.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(OpenMicTheme.Colors.speaking)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        if !detail.isEmpty {
                            Text(detail)
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            isSelected
                                ? OpenMicTheme.Colors.accentGradientStart
                                : OpenMicTheme.Colors.textTertiary
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

/// Voice picker header with title and optional refresh / loading indicator.
struct VoicePickerHeader: View {
    let isLoading: Bool
    let hasVoices: Bool
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            Text("VOICE")
                .font(OpenMicTheme.Typography.micro)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)

            Spacer()

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(OpenMicTheme.Colors.accentGradientStart)
            } else if hasVoices {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                }
            }
        }
        .padding(.horizontal, OpenMicTheme.Spacing.xs)
    }
}

// MARK: - Persona Helper

/// Fetches the active (default) persona from the given model container.
@MainActor
func fetchActivePersona(from appServices: AppServices) -> Persona? {
    let context = appServices.modelContainer.mainContext
    let descriptor = FetchDescriptor<Persona>(
        predicate: #Predicate { $0.isDefault == true }
    )
    return (try? context.fetch(descriptor))?.first
}
