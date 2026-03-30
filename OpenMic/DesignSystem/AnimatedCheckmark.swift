import SwiftUI

// MARK: - Animated Checkmark
// Checkmark stroke draws in via .trim animation.
// Circle ring fills simultaneously.
// Cyan accent from OpenMicTheme.
// Use for: API key validation success, conversation save confirmation.

struct AnimatedCheckmark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isComplete: Bool
    var size: CGFloat = 44
    var color: Color = OpenMicTheme.Colors.success
    var lineWidth: CGFloat = 3

    @State private var trimEnd: CGFloat = 0
    @State private var ringFill: CGFloat = 0
    @State private var bounceScale: CGFloat = 0.7

    var body: some View {
        ZStack {
            // Track ring – subtle
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Sweeping fill ring
            Circle()
                .trim(from: 0, to: ringFill)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Checkmark path
            OpenMicCheckmarkShape()
                .trim(from: 0, to: trimEnd)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .frame(width: size * 0.42, height: size * 0.42)
        }
        .scaleEffect(bounceScale)
        .onChange(of: isComplete) { _, newValue in
            if newValue {
                animateIn()
            } else {
                reset()
            }
        }
        .onAppear {
            if isComplete {
                if reduceMotion {
                    trimEnd = 1
                    ringFill = 1
                    bounceScale = 1
                } else {
                    animateIn()
                }
            }
        }
        .accessibilityLabel(isComplete ? "Validated" : "Pending")
        .accessibilityAddTraits(isComplete ? [.isSelected] : [])
    }

    private func animateIn() {
        if reduceMotion {
            trimEnd = 1
            ringFill = 1
            bounceScale = 1
            return
        }

        withAnimation(OpenMicTheme.Animation.bouncy) {
            bounceScale = 1.0
        }

        withAnimation(.easeOut(duration: 0.45).delay(0.05)) {
            ringFill = 1
        }

        withAnimation(
            .spring(response: 0.5, dampingFraction: 0.65).delay(0.15)
        ) {
            trimEnd = 1
        }
    }

    private func reset() {
        withAnimation(OpenMicTheme.Animation.fast) {
            trimEnd = 0
            ringFill = 0
            bounceScale = 0.7
        }
    }
}

// MARK: - Checkmark Shape

struct OpenMicCheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX * 0.75, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

// MARK: - Preview

#Preview("Animated Checkmark") {
    struct Demo: View {
        @State private var isComplete = false

        var body: some View {
            ZStack {
                Color(hex: 0x0A0A0F).ignoresSafeArea()

                VStack(spacing: 40) {
                    HStack(spacing: 32) {
                        AnimatedCheckmark(isComplete: isComplete, size: 32)
                        AnimatedCheckmark(isComplete: isComplete, size: 44)
                        AnimatedCheckmark(isComplete: isComplete, size: 60)
                    }

                    Button(isComplete ? "Reset" : "Mark Valid") {
                        isComplete.toggle()
                    }
                    .buttonStyle(.openMicPrimary)
                    .padding(.horizontal, 40)
                }
            }
        }
    }
    return Demo()
}
