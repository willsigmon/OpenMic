import Foundation
import SwiftData

@Model
final class Persona {
    var id: UUID
    var name: String
    var personality: String
    var systemPrompt: String
    var isDefault: Bool
    var createdAt: Date

    var openAIRealtimeVoice: String
    var geminiVoice: String
    var elevenLabsVoiceID: String?
    var systemTTSVoice: String?
    var openAITTSVoice: String?
    var humeAIVoiceID: String?
    var googleCloudVoiceID: String?
    var cartesiaVoiceID: String?
    var amazonPollyVoiceID: String?
    var deepgramVoiceID: String?

    init(
        id: UUID = UUID(),
        name: String,
        personality: String,
        systemPrompt: String,
        isDefault: Bool = false,
        openAIRealtimeVoice: String = "alloy",
        geminiVoice: String = "Kore",
        elevenLabsVoiceID: String? = nil,
        systemTTSVoice: String? = nil,
        openAITTSVoice: String? = "nova",
        humeAIVoiceID: String? = nil,
        googleCloudVoiceID: String? = nil,
        cartesiaVoiceID: String? = nil,
        amazonPollyVoiceID: String? = nil,
        deepgramVoiceID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.personality = personality
        self.systemPrompt = systemPrompt
        self.isDefault = isDefault
        self.createdAt = Date()
        self.openAIRealtimeVoice = openAIRealtimeVoice
        self.geminiVoice = geminiVoice
        self.elevenLabsVoiceID = elevenLabsVoiceID
        self.systemTTSVoice = systemTTSVoice
        self.openAITTSVoice = openAITTSVoice
        self.humeAIVoiceID = humeAIVoiceID
        self.googleCloudVoiceID = googleCloudVoiceID
        self.cartesiaVoiceID = cartesiaVoiceID
        self.amazonPollyVoiceID = amazonPollyVoiceID
        self.deepgramVoiceID = deepgramVoiceID
    }
}
