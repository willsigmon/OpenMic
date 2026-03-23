import Foundation
import Testing
@testable import OpenMic

@Suite("Conversation Bubble Descriptor")
struct ConversationBubbleDescriptorTests {
    @Test("Assistant final bubbles keep the OpenMic label")
    func assistantFinalBubbleDescriptor() {
        let bubble = ConversationBubble(
            role: .assistant,
            text: "Take I-40 East for the next 10 miles.",
            isFinal: true
        )

        let descriptor = ConversationBubbleDescriptorFactory.make(from: bubble)

        #expect(descriptor.assistantHeader == "OpenMic")
        #expect(descriptor.carPlayTitle == "OpenMic")
        #expect(descriptor.carPlayDetail == "Take I-40 East for the next 10 miles.")
        #expect(descriptor.carPlaySystemImage == "bubble.left.fill")
        #expect(!descriptor.isUser)
    }

    @Test("Assistant live bubbles expose the live label for CarPlay")
    func assistantLiveBubbleDescriptor() {
        let bubble = ConversationBubble(
            role: .assistant,
            text: "Let me think through the fastest route.",
            isFinal: false
        )

        let descriptor = ConversationBubbleDescriptorFactory.make(from: bubble)

        #expect(descriptor.assistantHeader == "OpenMic • Live")
        #expect(descriptor.carPlayTitle == "OpenMic • Live")
        #expect(descriptor.carPlaySystemImage == "waveform")
    }

    @Test("User bubbles map to the You label")
    func userBubbleDescriptor() {
        let bubble = ConversationBubble(
            role: .user,
            text: "Find coffee near Durham.",
            isFinal: true
        )

        let descriptor = ConversationBubbleDescriptorFactory.make(from: bubble)

        #expect(descriptor.assistantHeader == nil)
        #expect(descriptor.carPlayTitle == "You")
        #expect(descriptor.carPlayDetail == "Find coffee near Durham.")
        #expect(descriptor.carPlaySystemImage == "person.fill")
        #expect(descriptor.isUser)
    }

    @Test("Descriptor collapses whitespace and truncates long text")
    func descriptorNormalizesDetailText() {
        let bubble = ConversationBubble(
            role: .assistant,
            text: """
            This has
            line breaks and enough extra words to force truncation once the formatter
            collapses whitespace and keeps the payload compact for CarPlay list rows.
            """,
            isFinal: true
        )

        let descriptor = ConversationBubbleDescriptorFactory.make(from: bubble)

        #expect(!descriptor.carPlayDetail.contains("\n"))
        #expect(descriptor.carPlayDetail.contains("line breaks"))
        #expect(descriptor.carPlayDetail.hasSuffix("…"))
    }
}
