//
//  TiltCardModifier.swift
//  OpenMic
//
//  3D tilt effect driven by DragGesture. Y-axis from horizontal drag,
//  X-axis from vertical drag, capped at ±5°. Uses .simultaneously so
//  NavigationLink taps still fire. Returns to flat with .interactiveSpring.
//  Respects accessibilityReduceMotion: disables tilt when on.
//
//  Ported from Modcaster/Features/Library/TiltCard.swift.
//

import SwiftUI

// MARK: - TiltCardModifier

struct TiltCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : Double(rotation.width / 5)),
                axis: (x: 0, y: 1, z: 0)
            )
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : Double(-rotation.height / 5)),
                axis: (x: 1, y: 0, z: 0)
            )
            .animation(.interactiveSpring, value: rotation)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        guard !reduceMotion else { return }
                        rotation = value.translation
                    }
                    .onEnded { _ in
                        guard !reduceMotion else { return }
                        rotation = .zero
                    }
            )
    }
}

// MARK: - View Extension

extension View {
    /// Adds a 3D tilt effect driven by drag. ±5° max, returns to flat with
    /// interactiveSpring physics. Disabled when reduceMotion is on.
    func tiltCard() -> some View {
        modifier(TiltCardModifier())
    }
}
