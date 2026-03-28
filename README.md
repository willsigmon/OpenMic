# OpenMic

## Release Notes

- Apple provider support now requires `iOS 26+` at runtime.
- CarPlay conversational voice entitlement is **not enabled in-repo yet**. Re-enable `com.apple.developer.carplay-audio` and refresh provisioning profiles before device or CarPlay testing.
- Real app/test scheme: use `OpenMic`.
- Local compile-check fallback: use scheme `OpenMic-iOSBuildOnly` on machines that do not have watchOS 26.2 runtime installed. It is intentionally build-only and does not replace the main app/test scheme.
