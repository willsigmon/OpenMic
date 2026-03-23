# OpenMic — Handoff (March 23, 2026)

## What this is
Voice-first AI assistant for iOS with CarPlay, Watch app, 7 AI providers, 8 TTS engines.

## What shipped this session

### Testing
1. **End-to-end simulator testing with real API keys** — fetched Anthropic key from 1Password vault `Automation`, injected via env vars, ran in iPhone 17 Pro simulator
2. **UI test suite: OpenMicConversationUITests** — 2 tests:
   - `testProviderBadgeShowsClaude` — verifies Claude/Anthropic shows in provider badge (3.6s)
   - `testTappingSuggestionCardSendsToClaude` — taps suggestion card, verifies user bubble appears, waits for assistant response (6.3s) ✅
3. **Debug keychain seeder** (`AppServices.swift`) — reads `OPENMIC_SEED_*` env vars on bootstrap, injects keys into keychain, auto-completes onboarding

### Verified working in simulator
- Provider badge correctly shows "Claude" when Anthropic is selected
- Suggestion cards tap and send to conversation view
- Claude responds to prompts within ~6 seconds
- Provider switching UI works (OpenAI → Anthropic via `selectedProvider` UserDefaults)

## Running the tests
```bash
# With your Anthropic key in env:
xcodebuild test \
  -project OpenMic.xcodeproj \
  -scheme OpenMic-iOSOnly \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -only-testing "OpenMicUITests/OpenMicConversationUITests" \
  OPENMIC_TEST_ANTHROPIC_KEY="sk-ant-..."
```

Or using 1Password CLI:
```bash
ANTHROPIC_KEY=$(op item get "Anthropic API Key" --vault Automation --fields label=credential) && \
xcodebuild test ... OPENMIC_TEST_ANTHROPIC_KEY="$ANTHROPIC_KEY"
```

## Notes
- OpenAI key in `Automation` vault is over quota (HTTP 429) — use Anthropic for testing
- Apple Intelligence provider fails in simulator (FoundationModels not available)
- `selectedProvider` UserDefaults key controls active AI provider
- `byokMode` UserDefaults key enables BYOK flow (bypasses subscription check)

## Commits this session
- `e5638ea` test: add end-to-end conversation UI tests with Anthropic key seeding

## Previous session (March 23, 2026 earlier)
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
