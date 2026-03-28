import SwiftUI
import SwiftData

struct PersonaSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Persona.createdAt) private var personas: [Persona]
    @State private var editingPersona: Persona?

    var body: some View {
        ZStack {
            OpenMicTheme.Colors.background.ignoresSafeArea()

            if personas.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: OpenMicTheme.Spacing.sm) {
                        ForEach(personas) { persona in
                            PersonaCard(
                                persona: persona,
                                onSetDefault: { setDefault(persona) },
                                onEdit: { editingPersona = persona }
                            )
                        }
                    }
                    .padding(.horizontal, OpenMicTheme.Spacing.md)
                    .padding(.top, OpenMicTheme.Spacing.sm)
                }
            }
        }
        .navigationTitle("Personas")
        .sheet(item: $editingPersona) { persona in
            PersonaEditSheet(persona: persona)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: OpenMicTheme.Spacing.md) {
            GradientIcon(
                systemName: "person.crop.circle.badge.plus",
                gradient: OpenMicTheme.Gradients.accent,
                size: 64,
                iconSize: 28,
                glowColor: OpenMicTheme.Colors.glowCyan
            )
            .accessibilityHidden(true)

            Text("No Personas")
                .font(OpenMicTheme.Typography.title)
                .foregroundStyle(OpenMicTheme.Colors.textPrimary)

            Text("The default Sigmon persona will be created on first launch.")
                .font(OpenMicTheme.Typography.body)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OpenMicTheme.Spacing.xxxl)
        }
        .accessibilityElement(children: .combine)
    }

    private func setDefault(_ persona: Persona) {
        Haptics.success()
        // Clear existing defaults
        for p in personas {
            p.isDefault = false
        }
        persona.isDefault = true
        try? modelContext.save()
    }
}

// MARK: - Persona Card

private struct PersonaCard: View {
    let persona: Persona
    let onSetDefault: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.md) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(OpenMicTheme.Colors.accentGradientStart.opacity(0.15))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        OpenMicTheme.Colors.accentGradientStart.opacity(0.3),
                                        lineWidth: 0.5
                                    )
                            )

                        Text(String(persona.name.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                    }

                    VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xxs) {
                        HStack(spacing: OpenMicTheme.Spacing.xs) {
                            Text(persona.name)
                                .font(OpenMicTheme.Typography.headline)
                                .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                            if persona.isDefault {
                                StatusBadge(
                                    text: "Default",
                                    color: OpenMicTheme.Colors.accentGradientStart
                                )
                            }
                        }

                        Text(persona.personality)
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if !persona.isDefault {
                        Button {
                            onSetDefault()
                        } label: {
                            Text("Set Default")
                                .font(OpenMicTheme.Typography.micro)
                                .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                                .padding(.horizontal, OpenMicTheme.Spacing.xs)
                                .padding(.vertical, OpenMicTheme.Spacing.xxs)
                                .glassBackground(cornerRadius: OpenMicTheme.Radius.pill)
                        }
                        .accessibilityLabel("Set \(persona.name) as default")
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(persona.name)\(persona.isDefault ? ", default persona" : ""). \(persona.personality)")
        .accessibilityHint("Tap to edit")
    }
}

// MARK: - Persona Edit Sheet

private struct PersonaEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let persona: Persona

    @State private var editedName: String = ""
    @State private var editedPersonality: String = ""
    @State private var editedSystemPrompt: String = ""
    @State private var showVoiceSettings = false

    // Voice IDs
    @State private var openAIRealtimeVoice: String = "alloy"
    @State private var geminiVoice: String = "Kore"
    @State private var openAITTSVoice: String = "nova"
    @State private var elevenLabsVoiceID: String = ""
    @State private var systemTTSVoice: String = ""

    private static let openAIRealtimeVoices = ["alloy", "ash", "ballad", "coral", "echo", "sage", "shimmer", "verse"]
    private static let openAITTSVoices = ["alloy", "echo", "fable", "nova", "onyx", "shimmer"]
    private static let geminiVoices = ["Aoede", "Charon", "Fenrir", "Kore", "Puck"]

    var body: some View {
        NavigationStack {
            ZStack {
                OpenMicTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OpenMicTheme.Spacing.md) {
                        // Name field
                        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                            Text("NAME")
                                .font(OpenMicTheme.Typography.micro)
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                                .padding(.horizontal, OpenMicTheme.Spacing.xs)
                                .accessibilityAddTraits(.isHeader)

                            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                                TextField("Persona name", text: $editedName)
                                    .font(OpenMicTheme.Typography.headline)
                                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                                    .tint(OpenMicTheme.Colors.accentGradientStart)
                            }
                        }

                        // Personality field
                        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                            Text("PERSONALITY")
                                .font(OpenMicTheme.Typography.micro)
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                                .padding(.horizontal, OpenMicTheme.Spacing.xs)
                                .accessibilityAddTraits(.isHeader)

                            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                                TextField("Describe the personality...", text: $editedPersonality, axis: .vertical)
                                    .font(OpenMicTheme.Typography.body)
                                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                                    .lineLimit(3...8)
                                    .tint(OpenMicTheme.Colors.accentGradientStart)
                            }
                        }

                        // System prompt field
                        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                            Text("SYSTEM PROMPT")
                                .font(OpenMicTheme.Typography.micro)
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                                .padding(.horizontal, OpenMicTheme.Spacing.xs)
                                .accessibilityAddTraits(.isHeader)

                            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                                TextField("Instructions for the AI...", text: $editedSystemPrompt, axis: .vertical)
                                    .font(OpenMicTheme.Typography.body)
                                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                                    .lineLimit(3...12)
                                    .tint(OpenMicTheme.Colors.accentGradientStart)
                            }
                        }

                        // Voice settings toggle
                        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                            Button {
                                withAnimation(OpenMicTheme.Animation.fast) {
                                    showVoiceSettings.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("VOICE SETTINGS")
                                        .font(OpenMicTheme.Typography.micro)
                                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                                    Spacer()
                                    Image(systemName: showVoiceSettings ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                                }
                                .padding(.horizontal, OpenMicTheme.Spacing.xs)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Voice settings")
                            .accessibilityHint(showVoiceSettings ? "Collapse" : "Expand")

                            if showVoiceSettings {
                                voiceSettingsSection
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .padding(.horizontal, OpenMicTheme.Spacing.md)
                    .padding(.top, OpenMicTheme.Spacing.sm)
                    .padding(.bottom, OpenMicTheme.Spacing.xxxl)
                }
            }
            .navigationTitle("Edit Persona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                    .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            editedName = persona.name
            editedPersonality = persona.personality
            editedSystemPrompt = persona.systemPrompt
            openAIRealtimeVoice = persona.openAIRealtimeVoice
            geminiVoice = persona.geminiVoice
            openAITTSVoice = persona.openAITTSVoice ?? "nova"
            elevenLabsVoiceID = persona.elevenLabsVoiceID ?? ""
            systemTTSVoice = persona.systemTTSVoice ?? ""
        }
    }

    // MARK: - Voice Settings

    @ViewBuilder
    private var voiceSettingsSection: some View {
        VStack(spacing: OpenMicTheme.Spacing.sm) {
            // OpenAI Realtime Voice
            voicePicker(
                label: "OpenAI Realtime",
                selection: $openAIRealtimeVoice,
                options: Self.openAIRealtimeVoices
            )

            // OpenAI TTS Voice
            voicePicker(
                label: "OpenAI TTS",
                selection: $openAITTSVoice,
                options: Self.openAITTSVoices
            )

            // Gemini Voice
            voicePicker(
                label: "Gemini",
                selection: $geminiVoice,
                options: Self.geminiVoices
            )

            // ElevenLabs Voice ID (free text)
            voiceTextField(label: "ElevenLabs Voice ID", text: $elevenLabsVoiceID)

            // System TTS Voice (free text)
            voiceTextField(label: "System TTS Voice", text: $systemTTSVoice)
        }
    }

    @ViewBuilder
    private func voicePicker(label: String, selection: Binding<String>, options: [String]) -> some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
            HStack {
                Text(label)
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                Spacer()
                Picker(label, selection: selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(OpenMicTheme.Colors.accentGradientStart)
                .labelsHidden()
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func voiceTextField(label: String, text: Binding<String>) -> some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
            HStack {
                Text(label)
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                Spacer()
                TextField("Optional", text: text)
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 160)
                    .tint(OpenMicTheme.Colors.accentGradientStart)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Save

    private func saveChanges() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        persona.name = trimmedName
        persona.personality = editedPersonality.trimmingCharacters(in: .whitespaces)
        persona.systemPrompt = editedSystemPrompt.trimmingCharacters(in: .whitespaces)
        persona.openAIRealtimeVoice = openAIRealtimeVoice
        persona.geminiVoice = geminiVoice
        persona.openAITTSVoice = openAITTSVoice
        persona.elevenLabsVoiceID = elevenLabsVoiceID.isEmpty ? nil : elevenLabsVoiceID
        persona.systemTTSVoice = systemTTSVoice.isEmpty ? nil : systemTTSVoice
        Haptics.success()
        try? modelContext.save()
    }
}

// MARK: - Status Badge (Reusable)

struct StatusBadge: View {
    let text: String
    let color: Color
    var isActive: Bool = true

    var body: some View {
        HStack(spacing: OpenMicTheme.Spacing.xxs) {
            if isActive {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            }

            Text(text)
                .font(OpenMicTheme.Typography.micro)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
}
