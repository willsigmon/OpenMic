import SwiftUI

// MARK: - Animated Mesh Gradient Background
// iOS 18+: true MeshGradient with 3x3 grid, cyan/navy/dark palette from OpenMicTheme.
// iOS 17 fallback: drifting blurred circles.
// Replaces / enhances AmbientBackground for the onboarding flow.

struct AnimatedMeshBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if #available(iOS 18.0, *) {
            MeshGradientLayer(reduceMotion: reduceMotion)
                .ignoresSafeArea()
        } else {
            BlobFallbackLayer(reduceMotion: reduceMotion)
                .ignoresSafeArea()
        }
    }
}

// MARK: - iOS 18 Mesh Gradient

@available(iOS 18.0, *)
private struct MeshGradientLayer: View {
    let reduceMotion: Bool

    @State private var phase: CGFloat = 0

    // The centre point (index 4) pulses horizontally for a fluid shift.
    private var meshPoints: [SIMD2<Float>] {
        let cx = reduceMotion ? Float(0.5) : Float(0.5 + 0.09 * sin(.pi * phase))
        let cy = reduceMotion ? Float(0.5) : Float(0.5 + 0.05 * cos(.pi * phase * 0.7))
        return [
            SIMD2(0, 0),    SIMD2(0.5, 0),  SIMD2(1, 0),
            SIMD2(0, 0.5),  SIMD2(cx, cy),  SIMD2(1, 0.5),
            SIMD2(0, 1),    SIMD2(0.5, 1),  SIMD2(1, 1)
        ]
    }

    // Cyan / midnight-navy / near-black palette drawn from OpenMicTheme.Colors.
    // accentGradientStart = #00D4FF (cyan), accentGradientEnd = #0066FF (electric blue)
    private let meshColors: [Color] = [
        Color(hex: 0x00D4FF).opacity(0.60),   // [0,0] – bright cyan
        Color(hex: 0x0088CC).opacity(0.55),   // [0.5,0] – mid cyan-blue
        Color(hex: 0x0066FF).opacity(0.50),   // [1,0] – electric blue
        Color(hex: 0x001A33),                  // [0,0.5] – deep navy
        Color(hex: 0x00AADD).opacity(0.45),   // [0.5,0.5] – animated cyan core
        Color(hex: 0x003366),                  // [1,0.5] – dark navy
        Color(hex: 0x0A0A0F),                  // [0,1] – near-black
        Color(hex: 0x00070F),                  // [0.5,1] – near-black navy
        Color(hex: 0x050510)                   // [1,1] – darkest
    ]

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: meshPoints,
            colors: meshColors
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}

// MARK: - iOS 17 Blob Fallback

private struct BlobFallbackLayer: View {
    let reduceMotion: Bool

    @State private var blob1Phase: CGFloat = 0
    @State private var blob2Phase: CGFloat = 0
    @State private var blob3Phase: CGFloat = 0

    var body: some View {
        ZStack {
            Color(hex: 0x0A0A0F)

            // Blob 1 – cyan, upper-left
            Circle()
                .fill(Color(hex: 0x00D4FF).opacity(0.25))
                .frame(width: 280, height: 280)
                .blur(radius: 65)
                .offset(
                    x: -70 + blob1Phase * 25,
                    y: -200 + blob1Phase * -18
                )

            // Blob 2 – electric blue, centre-right
            Circle()
                .fill(Color(hex: 0x0066FF).opacity(0.20))
                .frame(width: 220, height: 220)
                .blur(radius: 55)
                .offset(
                    x: 100 + blob2Phase * -20,
                    y: 60 + blob2Phase * 25
                )

            // Blob 3 – mid-cyan, bottom
            Circle()
                .fill(Color(hex: 0x0088CC).opacity(0.22))
                .frame(width: 190, height: 190)
                .blur(radius: 50)
                .offset(
                    x: -30 + blob3Phase * 15,
                    y: 210 + blob3Phase * -12
                )
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blob1Phase = 1
            }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true).delay(1.5)) {
                blob2Phase = 1
            }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true).delay(3.0)) {
                blob3Phase = 1
            }
        }
    }
}

// MARK: - Preview

#Preview("Mesh – iOS 18+") {
    if #available(iOS 18.0, *) {
        MeshGradientLayer(reduceMotion: false)
            .ignoresSafeArea()
    } else {
        Text("Requires iOS 18")
    }
}

#Preview("Blob Fallback") {
    BlobFallbackLayer(reduceMotion: false)
        .ignoresSafeArea()
}
