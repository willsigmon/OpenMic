# Apple Provider Rollout QA Checklist

Use this checklist for release validation of Apple provider rollout across iPhone, CarPlay, and Watch.

## Local Build Gate (No watchOS runtime required)

1. Use scheme `OpenMic-iOSBuildOnly` for local compile checks on machines without watchOS 26.2 runtime.
2. Confirm iOS build succeeds before manual QA passes.

## Test Matrix

1. Device set A: iOS 18.6, Free tier.
2. Device set B: iOS 18.6, Premium tier.
3. Device set C: iOS 26.4 beta, Premium tier.
4. Device set D: iOS 26.4 beta, BYOK tier.
5. CarPlay enabled profile on test builds.
6. Watch paired to iPhone for watch messaging path checks.

## Settings and Onboarding Visibility

1. Open provider settings on iOS 18.6.
2. Confirm Apple provider is not shown in On-Device providers.
3. Open onboarding provider step on iOS 18.6.
4. Confirm Apple provider chip is not shown.
5. Open provider settings on iOS 26.4 beta with Free or Standard.
6. Confirm Apple provider is not shown due to tier restriction.
7. Open provider settings on iOS 26.4 beta with Premium.
8. Confirm Apple provider is shown.
9. Open onboarding provider step on iOS 26.4 beta with Premium.
10. Confirm Apple chip is shown and selectable.

## iPhone Runtime Resolution and Fallback

1. Save selected provider as Apple on iOS 18.6.
2. Start a conversation.
3. Confirm session starts with fallback provider and app stays functional.
4. Confirm one-line fallback status is shown in conversation UI.
5. Confirm selected provider preference remains Apple after fallback.
6. Save selected provider as Apple on iOS 26.4 beta Premium.
7. Start a conversation with Apple Intelligence unavailable or disabled.
8. Confirm fallback happens automatically without crash.
9. Confirm fallback status message is shown and user can continue chatting.
10. Enable Apple Intelligence and retry.
11. Confirm Apple responds end to end.

## CarPlay Runtime Resolution and Fallback

1. Launch CarPlay voice flow with selected provider Apple on iOS 18.6.
2. Confirm automatic fallback and successful session startup.
3. Launch CarPlay voice flow with selected provider Apple on iOS 26.4 beta Premium.
4. Confirm Apple path works when available.
5. Disable Apple Intelligence runtime availability and retry.
6. Confirm automatic fallback still starts voice session.
7. Confirm no blocking error is shown for fallback case.

## Watch Path Consistency

1. Send watch chat request with selected provider Apple on iOS 18.6 host.
2. Confirm fallback provider returns response.
3. Send watch chat request with selected provider Apple on iOS 26.4 beta Premium.
4. Confirm Apple path responds when available.
5. Make Apple unavailable at runtime and resend.
6. Confirm fallback provider returns response and watch remains responsive.

## Fallback Determinism and Config Rules

1. Set `lastWorkingProvider` to a valid configured provider.
2. Force Apple denial condition and start a session.
3. Confirm fallback uses `lastWorkingProvider` first.
4. Clear `lastWorkingProvider` and keep selected non-Apple provider configured.
5. Force Apple denial condition and start a session.
6. Confirm fallback uses selected non-Apple provider.
7. Remove key or required config from fallback candidates.
8. Confirm policy skips unconfigured candidates and picks next valid provider.
9. Confirm hard error only occurs when no configured providers exist.

## Logging and Safety

1. Confirm provider resolution logs include requested, effective, and reason.
2. Confirm no user-facing raw internal errors leak into UI.
3. Confirm fallback messaging is short and action oriented.

## Release Gate

1. iPhone path validated on iOS 18.6 and iOS 26.4 beta.
2. CarPlay path validated with entitlement profile refresh.
3. Watch path validated through phone relay flow.
4. Apple provider usable only on iOS 26+ with Premium or BYOK.
5. Fallback works for tier, OS, runtime unavailability, and missing config.
