import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ConversationView: View {
    @Binding var initialPrompt: String?
    @Binding var resumeConversation: Conversation?
    @Environment(AppServices.self) private var appServices
    @AppStorage("audioOutputMode") private var audioOutputMode = AudioOutputMode.defaultMode.rawValue
    @State private var viewModel: ConversationViewModel?
    @State private var showSuggestions = false
    @State private var suggestions: [PromptSuggestions.Suggestion] = []
    @State private var statusLabel = Microcopy.Status.label(for: .idle)
    @State private var showSettings = false
    @State private var showProviderPicker = false
    @State private var showPersonaPicker = false
    @State private var availableProviders: [(provider: AIProviderType, ready: Bool)] = []
    @State private var bubbleReactions: [UUID: String] = [:]
    @State private var micOffset: CGSize = .zero
    @State private var micRestPosition: CGSize = .zero
    @State private var isDraggingMic = false
    private let micBottomPadding: CGFloat = 24
    private let micTrailingPadding: CGFloat = 16
    // Enough room for the floating mic even at bottom-right
    private let contentBottomInset: CGFloat = 110

    var body: some View {
        Group {
            if let viewModel {
                voiceContent(viewModel)
            } else {
                loadingState
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ConversationViewModel(appServices: appServices)
            }
        }
    }

    // MARK: - Loading State

    @ViewBuilder
    private var loadingState: some View {
        ZStack {
            OpenMicTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: OpenMicTheme.Spacing.md) {
                Image(systemName: "car.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(OpenMicTheme.Gradients.accent)
                    .symbolEffect(.pulse.byLayer, options: .repeating)
                    .accessibilityHidden(true)

                Text(Microcopy.Loading.message)
                    .font(OpenMicTheme.Typography.callout)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Microcopy.Loading.message)
    }

    @ViewBuilder
    private func voiceContent(_ vm: ConversationViewModel) -> some View {
        ZStack {
            // Immersive animated background
            AmbientBackground(state: vm.voiceState)

            // Floating particles
            FloatingParticles(
                count: 20,
                isActive: vm.voiceState.isActive,
                color: particleColor(for: vm.voiceState)
            )

            VStack(spacing: 0) {
                topBar(vm)
                    .padding(.horizontal, OpenMicTheme.Spacing.xl)
                    .padding(.top, OpenMicTheme.Spacing.sm)

                if !vm.voiceState.isActive && showSuggestions && vm.bubbles.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        SuggestionChipsView(
                            suggestions: suggestions,
                            onTap: { suggestion in
                                withAnimation(OpenMicTheme.Animation.fast) {
                                    showSuggestions = false
                                }
                                vm.sendPrompt(suggestion.text)
                            },
                            onRefresh: {
                                refreshSuggestions()
                            }
                        )
                        .padding(.horizontal, OpenMicTheme.Spacing.md)
                        .padding(.top, OpenMicTheme.Spacing.sm)
                        .padding(.bottom, contentBottomInset)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    statusIndicator(vm)
                        .padding(.top, OpenMicTheme.Spacing.xl)
                        .padding(.bottom, OpenMicTheme.Spacing.sm)

                    if vm.bubbles.isEmpty {
                        VoiceWaveformView(level: vm.audioLevel, state: vm.voiceState)
                            .frame(height: 150)
                            .padding(.horizontal, OpenMicTheme.Spacing.xl)
                            .padding(.top, OpenMicTheme.Spacing.sm)
                            .padding(.bottom, contentBottomInset)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        bubbleChatArea(vm)
                            .padding(.top, OpenMicTheme.Spacing.xxs)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .transition(.opacity)
                    }
                }

                // Error banner
                if let error = vm.errorMessage {
                    errorBanner(error)
                        .padding(.horizontal, OpenMicTheme.Spacing.xl)
                        .padding(.top, OpenMicTheme.Spacing.xs)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let fallbackMessage = vm.providerFallbackMessage, !fallbackMessage.isEmpty {
                    fallbackBanner(fallbackMessage)
                        .padding(.horizontal, OpenMicTheme.Spacing.xl)
                        .padding(.top, OpenMicTheme.Spacing.xs)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(OpenMicTheme.Animation.fast, value: vm.voiceState)
        .overlay(alignment: .bottomTrailing) {
            MicButton(state: vm.voiceState, action: { vm.toggleListening() }, isDragging: isDraggingMic)
            .offset(x: micRestPosition.width + micOffset.width,
                    y: micRestPosition.height + micOffset.height)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        if !isDraggingMic {
                            isDraggingMic = true
                            Haptics.tap()
                        }
                        micOffset = value.translation
                    }
                    .onEnded { value in
                        // Clamp to screen bounds to prevent dragging off-screen
                        let screenWidth = UIScreen.main.bounds.width
                        let screenHeight = UIScreen.main.bounds.height
                        let maxOffset: CGFloat = 200
                        let newRest = CGSize(
                            width: max(-screenWidth + maxOffset, min(0, micRestPosition.width + value.translation.width)),
                            height: max(-screenHeight + maxOffset, min(0, micRestPosition.height + value.translation.height))
                        )
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6, blendDuration: 0.1)) {
                            micRestPosition = newRest
                            micOffset = .zero
                            isDraggingMic = false
                        }
                        Haptics.tap()
                    }
            )
            .padding(.bottom, micBottomPadding)
            .padding(.trailing, micTrailingPadding)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                APIKeySettingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showSettings = false }
                                .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                        }
                    }
            }
        }
        .sheet(isPresented: $showProviderPicker) {
            ProviderPickerSheet(
                currentProvider: vm.activeProvider,
                providers: availableProviders,
                onSelect: { provider in
                    vm.switchProvider(to: provider)
                }
            )
        }
        .sheet(isPresented: $showPersonaPicker) {
            PersonaPickerSheet(
                currentPersonaID: vm.conversation?.personaName == nil
                    ? nil
                    : fetchCurrentPersonaID(vm),
                onSelect: { persona in
                    vm.switchPersona(to: persona)
                }
            )
        }
        .onChange(of: vm.voiceState) { oldState, newState in
            // Haptic per state transition with sound companions
            Haptics.voiceStateChanged(to: newState)
            switch newState {
            case .listening where oldState == .idle:
                Haptics.listeningStartSound()
            case .speaking where oldState != .speaking:
                Haptics.speakingStartSound()
            case .error:
                Haptics.errorSound()
            default:
                break
            }

            // Refresh status label on each transition
            withAnimation(OpenMicTheme.Animation.fast) {
                statusLabel = Microcopy.Status.label(for: newState)
            }

            // Refresh suggestions when returning to idle
            if newState == .idle && oldState != .idle {
                refreshSuggestions()
                withAnimation(OpenMicTheme.Animation.smooth) {
                    showSuggestions = true
                }
            }
        }
        .onAppear {
            refreshSuggestions()
            // Delayed entrance
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(OpenMicTheme.Animation.smooth) {
                    showSuggestions = true
                }
            }
        }
        .onChange(of: initialPrompt) { _, newPrompt in
            if let prompt = newPrompt, !prompt.isEmpty {
                initialPrompt = nil
                vm.sendPrompt(prompt)
            }
        }
        .onChange(of: resumeConversation?.id) { _, newID in
            if let conversation = resumeConversation {
                resumeConversation = nil
                vm.loadConversation(conversation)
            }
        }
    }

    // MARK: - Top Bar

    @ViewBuilder
    private func topBar(_ vm: ConversationViewModel) -> some View {
        HStack {
            // App branding
            HStack(spacing: OpenMicTheme.Spacing.xs) {
                Image(systemName: "car.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                    .accessibilityHidden(true)

                Text("OpenMic")
                    .font(OpenMicTheme.Typography.callout)
                    .foregroundStyle(OpenMicTheme.Colors.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("OpenMic")

            if let conversation = vm.conversation {
                Button { showPersonaPicker = true } label: {
                    Text(conversation.personaName)
                        .font(OpenMicTheme.Typography.caption.weight(.medium))
                        .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                        .padding(.horizontal, OpenMicTheme.Spacing.xs)
                        .padding(.vertical, 5)
                        .glassBackground(cornerRadius: OpenMicTheme.Radius.pill)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Persona: \(conversation.personaName)")
                .accessibilityHint("Tap to switch persona")
            }

            Spacer()

            if let conversation = vm.conversation, !conversation.messages.isEmpty {
                ShareLink(
                    item: ConversationExporter.plainText(from: conversation),
                    subject: Text(conversation.displayTitle)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .padding(8)
                        .glassBackground(cornerRadius: OpenMicTheme.Radius.pill)
                }
                .accessibilityLabel("Share conversation")
            }

            Button {
                Task {
                    availableProviders = await vm.availableProviders()
                    showProviderPicker = true
                }
            } label: {
                ProviderBadge(provider: vm.activeProvider)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Tap to switch AI provider")

            Menu {
                ForEach(AudioOutputMode.allCases) { mode in
                    Button {
                        audioOutputMode = mode.rawValue
                        AudioSessionManager.shared.setPreferredOutputMode(mode)
                        Haptics.tap()
                    } label: {
                        Label(
                            mode.displayName,
                            systemImage: mode == currentOutputMode ? "checkmark" : "speaker.wave.2"
                        )
                    }
                }
            } label: {
                HStack(spacing: OpenMicTheme.Spacing.xxxs) {
                    Image(systemName: outputModeIconName)
                    Text(outputModeDisplayName)
                        .font(OpenMicTheme.Typography.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(outputModeColor)
                .padding(.horizontal, OpenMicTheme.Spacing.xs)
                .padding(.vertical, 7)
                .glassBackground(cornerRadius: OpenMicTheme.Radius.pill)
            }
            .accessibilityLabel("Audio output: \(outputModeDisplayName)")
            .accessibilityHint("Opens audio output options including speakerphone mode")

            // Voice state badge
            VoiceStateBadge(state: vm.voiceState)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("OpenMic, \(vm.voiceState.isActive ? "Live" : "Ready")")
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private func statusIndicator(_ vm: ConversationViewModel) -> some View {
        HStack(spacing: OpenMicTheme.Spacing.xs) {
            VoiceStateIcon(state: vm.voiceState)

            Text(statusLabel)
                .font(OpenMicTheme.Typography.statusLabel)
                .foregroundStyle(stateColor(for: vm.voiceState))
                .contentTransition(.numericText())
                .id(statusLabel)
        }
        .padding(.horizontal, OpenMicTheme.Spacing.md)
        .padding(.vertical, OpenMicTheme.Spacing.xs)
        .glassBackground(cornerRadius: OpenMicTheme.Radius.pill)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(statusLabel)")
    }

    // MARK: - Bubble Chat

    @ViewBuilder
    private func bubbleChatArea(_ vm: ConversationViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: OpenMicTheme.Spacing.sm) {
                    ForEach(vm.bubbles) { bubble in
                        ConversationBubbleRow(
                            bubble: bubble,
                            reaction: bubbleReactions[bubble.id],
                            onReaction: { reaction in
                                bubbleReactions[bubble.id] = reaction
                                Haptics.tap()
                            },
                            onCopy: {
                                copyToPasteboard(bubble.text)
                            }
                        )
                        .id(bubble.id)
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.md)
                .padding(.top, OpenMicTheme.Spacing.sm)
                .padding(.bottom, contentBottomInset)
            }
            .onAppear {
                if let lastID = vm.bubbles.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
            .onChange(of: vm.bubbles.last?.id) { _, newID in
                guard let newID else { return }
                withAnimation(OpenMicTheme.Animation.fast) {
                    proxy.scrollTo(newID, anchor: .bottom)
                }
            }
            .onChange(of: vm.bubbles.last?.isFinal) { _, isFinal in
                guard isFinal == true, let lastID = vm.bubbles.last?.id else { return }
                withAnimation(OpenMicTheme.Animation.micro) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Error Banner

    private func isAPIKeyError(_ error: String) -> Bool {
        let normalized = error.lowercased()
        return normalized.contains("api") || normalized.contains("key") || normalized.contains("auth")
            || normalized.contains("401") || normalized.contains("403")
            || normalized.contains("configured providers")
            || normalized.contains("configure in settings")
    }

    private var currentProviderPortalURL: URL? {
        guard let provider = viewModel?.activeProvider else { return nil }
        guard provider.requiresAPIKey else { return nil }
        return provider.apiKeyPortalURL
    }

    @ViewBuilder
    private func fallbackBanner(_ message: String) -> some View {
        HStack(spacing: OpenMicTheme.Spacing.xs) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                .accessibilityHidden(true)

            Text(message)
                .font(OpenMicTheme.Typography.caption)
                .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                .lineLimit(2)

            Spacer(minLength: OpenMicTheme.Spacing.xs)

            Button("Setup") {
                showSettings = true
            }
            .buttonStyle(.openMicActionPill(tone: .accent))
        }
        .padding(.horizontal, OpenMicTheme.Spacing.md)
        .padding(.vertical, OpenMicTheme.Spacing.xs)
        .glassBackground(cornerRadius: OpenMicTheme.Radius.md)
    }

    @ViewBuilder
    private func errorBanner(_ error: String) -> some View {
        VStack(spacing: OpenMicTheme.Spacing.xs) {
            HStack(spacing: OpenMicTheme.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(OpenMicTheme.Colors.error)
                    .accessibilityHidden(true)

                Text(error)
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.error.opacity(0.9))
                    .lineLimit(2)

                Spacer()
            }

            HStack(spacing: OpenMicTheme.Spacing.xs) {
                Button {
                    viewModel?.startListening()
                } label: {
                    HStack(spacing: OpenMicTheme.Spacing.xxs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                        Text("Try Again")
                            .font(OpenMicTheme.Typography.caption)
                    }
                }
                .buttonStyle(.openMicActionPill(tone: .danger))
                .accessibilityLabel("Try again")
                .accessibilityHint("Retries the voice conversation")

                if isAPIKeyError(error) {
                    Button {
                        showSettings = true
                    } label: {
                        HStack(spacing: OpenMicTheme.Spacing.xxs) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Settings")
                                .font(OpenMicTheme.Typography.caption)
                        }
                    }
                    .buttonStyle(.openMicActionPill(tone: .accent))
                    .accessibilityLabel("Open settings")
                    .accessibilityHint("Configure your API key")

                    if let portalURL = currentProviderPortalURL {
                        Link(destination: portalURL) {
                            HStack(spacing: OpenMicTheme.Spacing.xxs) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Get Key")
                                    .font(OpenMicTheme.Typography.caption)
                            }
                        }
                        .buttonStyle(.openMicActionPill(tone: .accent))
                        .accessibilityLabel("Get API key")
                        .accessibilityHint("Opens provider website to create an API key")
                    }
                }

                Spacer()
            }
        }
        .padding(OpenMicTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.sm)
                .fill(OpenMicTheme.Colors.error.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: OpenMicTheme.Radius.sm)
                        .strokeBorder(OpenMicTheme.Colors.error.opacity(0.2), lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(error)")
    }

    // MARK: - Helpers

    private func particleColor(for state: VoiceSessionState) -> Color {
        switch state {
        case .idle: OpenMicTheme.Colors.accentGradientStart
        case .listening: OpenMicTheme.Colors.listening
        case .processing: OpenMicTheme.Colors.processing
        case .speaking: OpenMicTheme.Colors.speaking
        case .error: OpenMicTheme.Colors.error
        }
    }

    private func stateColor(for state: VoiceSessionState) -> Color {
        switch state {
        case .idle: OpenMicTheme.Colors.textTertiary
        case .listening: OpenMicTheme.Colors.listening
        case .processing: OpenMicTheme.Colors.processing
        case .speaking: OpenMicTheme.Colors.speaking
        case .error: OpenMicTheme.Colors.error
        }
    }

    private var outputModeDisplayName: String {
        currentOutputMode.displayName
    }

    private var outputModeIconName: String {
        switch currentOutputMode {
        case .automatic:
            return "point.3.connected.trianglepath.dotted"
        case .speakerphone:
            return "speaker.wave.3.fill"
        }
    }

    private var outputModeColor: Color {
        switch currentOutputMode {
        case .automatic:
            return OpenMicTheme.Colors.textTertiary
        case .speakerphone:
            return OpenMicTheme.Colors.accentGradientStart
        }
    }

    private var currentOutputMode: AudioOutputMode {
        AudioOutputMode(rawValue: audioOutputMode) ?? .defaultMode
    }

    private func refreshSuggestions() {
        suggestions = PromptSuggestions.current(count: 8)
    }

    private func copyToPasteboard(_ text: String) {
#if canImport(UIKit)
        UIPasteboard.general.string = text
#endif
        Haptics.tap()
    }

    private func fetchCurrentPersonaID(_ vm: ConversationViewModel) -> UUID? {
        let context = appServices.modelContainer.mainContext
        let descriptor = FetchDescriptor<Persona>(
            predicate: #Predicate { $0.isDefault == true }
        )
        return (try? context.fetch(descriptor))?.first?.id
    }
}

// MARK: - Voice State Badge

private struct VoiceStateBadge: View {
    let state: VoiceSessionState

    private var color: Color {
        switch state {
        case .idle: OpenMicTheme.Colors.textTertiary
        case .listening: OpenMicTheme.Colors.listening
        case .processing: OpenMicTheme.Colors.processing
        case .speaking: OpenMicTheme.Colors.speaking
        case .error: OpenMicTheme.Colors.error
        }
    }

    var body: some View {
        StatusBadge(
            text: state.isActive ? "Live" : "Ready",
            color: color,
            isActive: state.isActive
        )
        .glassBackground(cornerRadius: OpenMicTheme.Radius.pill)
    }
}

