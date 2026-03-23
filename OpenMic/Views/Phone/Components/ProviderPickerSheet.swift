import SwiftUI

struct ProviderPickerSheet: View {
    let currentProvider: AIProviderType
    let providers: [(provider: AIProviderType, ready: Bool)]
    let onSelect: (AIProviderType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: OpenMicTheme.Spacing.xs) {
                    ForEach(providers, id: \.provider) { entry in
                        providerRow(entry.provider, ready: entry.ready)
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.md)
                .padding(.top, OpenMicTheme.Spacing.sm)
            }
            .background(OpenMicTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Switch Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func providerRow(_ provider: AIProviderType, ready: Bool) -> some View {
        let isSelected = provider == currentProvider

        Button {
            guard ready, !isSelected else { return }
            Haptics.tap()
            onSelect(provider)
            dismiss()
        } label: {
            HStack(spacing: OpenMicTheme.Spacing.sm) {
                BrandLogo(provider, size: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(OpenMicTheme.Typography.body)
                        .foregroundStyle(
                            ready
                                ? OpenMicTheme.Colors.textPrimary
                                : OpenMicTheme.Colors.textTertiary
                        )

                    Text(provider.tagline)
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                } else if !ready {
                    Text("No Key")
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(OpenMicTheme.Colors.surfaceGlass)
                        )
                }
            }
            .padding(.horizontal, OpenMicTheme.Spacing.sm)
            .padding(.vertical, OpenMicTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md, style: .continuous)
                    .fill(
                        isSelected
                            ? OpenMicTheme.Colors.providerColor(provider).opacity(0.10)
                            : OpenMicTheme.Colors.surfaceGlass.opacity(0.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md, style: .continuous)
                            .strokeBorder(
                                isSelected
                                    ? OpenMicTheme.Colors.providerColor(provider).opacity(0.4)
                                    : OpenMicTheme.Colors.borderMedium.opacity(0.3),
                                lineWidth: isSelected ? 1.2 : 0.6
                            )
                    )
            )
            .opacity(ready ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(provider.displayName)\(isSelected ? ", selected" : "")")
        .accessibilityHint(
            ready
                ? "Tap to switch to \(provider.displayName)"
                : "API key required. Configure in settings."
        )
    }
}
