# OpenMic — Handoff (March 23, 2026)

## What this is
Voice-first AI assistant for iOS with CarPlay, Watch app, 7 AI providers, 8 TTS engines.

## What shipped this session
1. **Shared ConversationBubbleDescriptor** — extracted into `OpenMic/Shared/`, used by both Phone and CarPlay for consistent bubble rendering
2. **ConversationBubble moved to Shared/** — single source of truth, no longer buried in ConversationViewModel
3. **Mid-conversation provider switching** — tap the provider badge in the top bar to open a picker sheet. Switching tears down the session, inserts a system marker bubble, and restarts.
4. **System bubble rendering** — centered divider-style markers in phone UI, list items in CarPlay
5. **Build 7** — version bumped for TestFlight

## Tests
34 tests across 6 suites, all passing.

## What's next
1. **Watch complications** — quick-launch voice session from watch face
2. **Conversation export** — share/export full conversation as text or PDF
3. **Per-conversation persona** — change persona mid-conversation
4. **TestFlight build 7** — archive and upload (build number already bumped)

## Build
```bash
xcodegen generate && xcodebuild -project OpenMic.xcodeproj -scheme OpenMic -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
