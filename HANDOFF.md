# OpenMic — Handoff (March 8, 2026)

## What this is
Voice-first AI assistant for iOS with CarPlay, Watch app, 7 AI providers, 8 TTS engines.

## Where we left off
**Conversation UI components.** Just committed:
- `ConversationBubbleRow.swift` — new chat bubble component for phone view
- `ProviderBadge.swift` — visual indicator showing which AI provider answered
- `ConversationView.swift` — updated to use new components
- `APIKeySettingsView.swift` — settings refinements
- `SelfHostedProviderCard.swift` — new provider card for Ollama/OpenClaw

## What's next
1. **Wire ConversationBubbleRow into CarPlay** — phone view uses it, CarPlay still has old layout
2. **Provider switching UX** — mid-conversation provider swap (user requested)
3. **Watch complications** — quick-launch voice session from watch face
4. **TestFlight build 6** — last was build 5 pre-bubble-components

## Build
```bash
xcodegen generate && xcodebuild -project OpenMic.xcodeproj -scheme OpenMic -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
