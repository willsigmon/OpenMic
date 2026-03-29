import SwiftUI

// MARK: - CelebrationValues

/// Animatable bundle for OpenMic keyframe celebrations.
/// Conforms to `Animatable` so `keyframeAnimator` can interpolate all three
/// properties as a single coordinated track group.
struct CelebrationValues: Animatable {
    var scale: CGFloat = 1.0
    var rotation: Double = 0.0
    var verticalOffset: CGFloat = 0.0

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, Double>, CGFloat> {
        get { AnimatablePair(AnimatablePair(scale, rotation), verticalOffset) }
        set {
            scale = newValue.first.first
            rotation = newValue.first.second
            verticalOffset = newValue.second
        }
    }
}

// MARK: - View Modifier

/// Keyframe celebration modifier tuned to OpenMic's `OpenMicTheme.Animation` tokens.
///
/// Timing intentionally matches `OpenMicTheme.Animation.bouncy` (response: 0.5, damping: 0.6)
/// for the scale spring, keeping OpenMic's cockpit aesthetic — fast rise, controlled bounce.
///
/// Reduces to a no-op instant transition when `accessibilityReduceMotion` is active.
struct OpenMicCelebrationKeyframesModifier<V: Equatable>: ViewModifier {
    let trigger: V

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Spring matching OpenMicTheme.Animation.bouncy
    private static var cardSpring: Spring { .init(response: 0.5, dampingRatio: 0.6) }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
                .animation(.linear(duration: 0.01), value: trigger)
        } else {
            content
                .keyframeAnimator(
                    initialValue: CelebrationValues(),
                    trigger: trigger
                ) { view, values in
                    view
                        .scaleEffect(values.scale)
                        .rotationEffect(.degrees(values.rotation))
                        .offset(y: values.verticalOffset)
                } keyframes: { _ in
                    // Scale: quick punch, compress, settle — cockpit "confirmation" feel
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(1.3, duration: 0.2, spring: Self.cardSpring)
                        SpringKeyframe(0.9, duration: 0.15)
                        SpringKeyframe(1.05, duration: 0.15)
                        SpringKeyframe(1.0, duration: 0.2)
                    }
                    // Rotation: tight mechanical tick
                    KeyframeTrack(\.rotation) {
                        LinearKeyframe(-5, duration: 0.1)
                        LinearKeyframe(5, duration: 0.1)
                        LinearKeyframe(-3, duration: 0.1)
                        LinearKeyframe(3, duration: 0.1)
                        LinearKeyframe(0, duration: 0.1)
                    }
                    // Vertical: jump up, gravity rebound to baseline
                    KeyframeTrack(\.verticalOffset) {
                        SpringKeyframe(-15, duration: 0.2, spring: Self.cardSpring)
                        SpringKeyframe(5, duration: 0.15)
                        SpringKeyframe(0, duration: 0.25, spring: Self.cardSpring)
                    }
                }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Plays OpenMic's keyframe celebration animation when `trigger` changes.
    ///
    /// Timing tokens source from `OpenMicTheme.Animation`. Respects
    /// `accessibilityReduceMotion` — passes through instantly when enabled.
    ///
    /// Usage at a milestone badge:
    /// ```swift
    /// milestoneBadge
    ///     .openMicCelebrationKeyframes(trigger: milestoneCount)
    /// ```
    func openMicCelebrationKeyframes<V: Equatable>(trigger: V) -> some View {
        modifier(OpenMicCelebrationKeyframesModifier(trigger: trigger))
    }
}
