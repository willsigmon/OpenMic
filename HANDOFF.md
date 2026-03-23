# OpenMic — Handoff (March 23, 2026)

## What this is
Voice-first AI assistant for iOS with CarPlay, Watch app, 7 AI providers, 8 TTS engines.

## What shipped this session

### Architecture
1. **Shared ConversationBubbleDescriptor** — extracted into `OpenMic/Shared/`, used by both Phone and CarPlay
2. **ConversationBubble moved to Shared/** — single source of truth

### Features
3. **Mid-conversation provider switching** — tap provider badge in top bar, picker sheet, session restart with system marker bubble
4. **Mid-conversation persona switching** — tap persona name in top bar, picker sheet, updates default persona and conversation record
5. **Conversation export** — long-press in History for Share/Copy Transcript; share button in active conversation top bar
6. **System bubble rendering** — centered divider markers for provider/persona switches
7. **Watch complications** — WidgetKit extension with 4 families (circular, rectangular, inline, corner)

### Ship
8. **TestFlight build 7** — archived and uploaded to App Store Connect

## Tests
34 tests across 6 suites, all passing.

## Commits this session
- `b9c59a6` feat: share ConversationBubbleDescriptor between Phone and CarPlay
- `fa7b598` refactor: move ConversationBubble to Shared/
- `64bf5f6` feat: mid-conversation provider switching
- `9401ec3` chore: bump build to 7
- `eb56a5a` feat: conversation export via share sheet and clipboard
- `931d55c` feat: mid-conversation persona switching
- `daec415` feat: add watch complications via WidgetKit
- `b46de2f` fix: add CFBundleDisplayName to watch widget plist

## What's next
1. **Watch complication deep links** — URL scheme to launch directly into voice mode
2. **Conversation search** — search across conversation history
3. **Provider-per-message display** — show which provider answered each bubble
4. **Persona editor improvements** — edit voice settings per-persona inline

## Build
```bash
xcodegen generate && xcodebuild -project OpenMic.xcodeproj -scheme OpenMic -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
