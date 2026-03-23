import SwiftUI
import SwiftData

struct PersonaPickerSheet: View {
    let currentPersonaID: UUID?
    let onSelect: (Persona) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Persona.createdAt) private var personas: [Persona]

    var body: some View {
        NavigationStack {
            ScrollView {
                if personas.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: OpenMicTheme.Spacing.xs) {
                        ForEach(personas) { persona in
                            personaRow(persona)
                        }
                    }
                    .padding(.horizontal, OpenMicTheme.Spacing.md)
                    .padding(.top, OpenMicTheme.Spacing.sm)
                }
            }
            .background(OpenMicTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Switch Persona")
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
    private var emptyState: some View {
        VStack(spacing: OpenMicTheme.Spacing.md) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)

            Text("No personas yet")
                .font(OpenMicTheme.Typography.body)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)

            Text("Create personas in Settings to customize voice and personality.")
                .font(OpenMicTheme.Typography.caption)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(OpenMicTheme.Spacing.xl)
    }

    @ViewBuilder
    private func personaRow(_ persona: Persona) -> some View {
        let isSelected = persona.id == currentPersonaID

        Button {
            guard !isSelected else { return }
            Haptics.tap()
            onSelect(persona)
            dismiss()
        } label: {
            HStack(spacing: OpenMicTheme.Spacing.sm) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        isSelected
                            ? OpenMicTheme.Colors.accentGradientStart
                            : OpenMicTheme.Colors.textTertiary
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(persona.name)
                        .font(OpenMicTheme.Typography.body)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                    Text(persona.personality)
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                }
            }
            .padding(.horizontal, OpenMicTheme.Spacing.sm)
            .padding(.vertical, OpenMicTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md, style: .continuous)
                    .fill(
                        isSelected
                            ? OpenMicTheme.Colors.accentGradientStart.opacity(0.08)
                            : OpenMicTheme.Colors.surfaceGlass.opacity(0.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md, style: .continuous)
                            .strokeBorder(
                                isSelected
                                    ? OpenMicTheme.Colors.accentGradientStart.opacity(0.4)
                                    : OpenMicTheme.Colors.borderMedium.opacity(0.3),
                                lineWidth: isSelected ? 1.2 : 0.6
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(persona.name)\(isSelected ? ", selected" : "")")
        .accessibilityHint("Tap to switch to \(persona.name)")
    }
}
