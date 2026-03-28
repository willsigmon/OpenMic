import Testing
import Foundation
@testable import OpenMic

@Suite("Model Tests")
struct ModelTests {
    @Test("AIProviderType has correct properties")
    func providerProperties() {
        #expect(AIProviderType.openAI.displayName == "OpenAI")
        #expect(AIProviderType.openAI.supportsRealtimeVoice == true)
        #expect(AIProviderType.anthropic.supportsRealtimeVoice == false)
        #expect(AIProviderType.apple.supportsRealtimeVoice == false)
        #expect(AIProviderType.apple.minimumSupportedOSMajorVersion == 26)
        #expect(AIProviderType.apple.isAllowedForTier(.premium))
        #expect(!AIProviderType.apple.isAllowedForTier(.standard))
        #expect(AIProviderType.ollama.requiresAPIKey == false)
        #expect(AIProviderType.anthropic.requiresAPIKey == true)
        #expect(AIProviderType.grok.baseURL == "https://api.x.ai/v1")
    }

    @Test("Conversation initializes correctly")
    func conversationInit() {
        let conversation = Conversation(
            providerType: .anthropic,
            personaName: "Test"
        )
        #expect(conversation.title == AppConstants.Defaults.conversationTitle)
        #expect(conversation.provider == .anthropic)
        #expect(conversation.personaName == "Test")
        #expect(conversation.messages.isEmpty)
    }

    @Test("Message initializes correctly")
    func messageInit() {
        let message = Message(role: .user, content: "Hello")
        #expect(message.messageRole == .user)
        #expect(message.content == "Hello")
    }

    @Test("VoiceConfig defaults")
    func voiceConfigDefaults() {
        let config = VoiceConfig.default
        #expect(config.ttsEngine == .system)
        #expect(config.sttEnabled == true)
    }

    @Test("All providers have keychain keys")
    func keychainKeys() {
        for provider in AIProviderType.allCases {
            #expect(!provider.keychainKey.isEmpty)
        }
    }

    @Test("MessageRole raw values")
    func messageRoles() {
        #expect(MessageRole.user.rawValue == "user")
        #expect(MessageRole.assistant.rawValue == "assistant")
        #expect(MessageRole.system.rawValue == "system")
    }
}
