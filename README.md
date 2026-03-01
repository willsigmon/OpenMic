# OpenMic

## Release Notes

- Apple provider support now requires `iOS 26+` at runtime.
- CarPlay conversational voice entitlement is enabled. Refresh provisioning profiles before testing on `iOS 26.4 beta` devices.
- Local compile check fallback: use scheme `OpenMic-iOSBuildOnly` on machines that do not have watchOS 26.2 runtime installed.
