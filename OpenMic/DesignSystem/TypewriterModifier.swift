//
//  TypewriterModifier.swift
//  OpenMic
//
//  Character-by-character text reveal with a blinking cursor at the end.
//  Respects accessibilityReduceMotion: shows full text instantly when on.
//

import SwiftUI

// MARK: - TypewriterModifier

struct TypewriterModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var visibleCount: Int = 0
    @State private var showCursor: Bool = false
    @State private var cursorOpacity: Double = 1
    @State private var typewriterTask: Task<Void, Never>?

    let text: String
    let speed: Double

    init(text: String, speed: Double = 0.03) {
        self.text = text
        self.speed = speed
    }

    func body(content: Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(String(text.prefix(visibleCount)))
            if showCursor && !reduceMotion {
                Text("|")
                    .opacity(cursorOpacity)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                        value: cursorOpacity
                    )
            }
        }
        .onAppear { startTypewriter() }
        .onChange(of: text) { _, _ in
            typewriterTask?.cancel()
            visibleCount = 0
            showCursor = false
            startTypewriter()
        }
        .onDisappear { typewriterTask?.cancel() }
    }

    // MARK: - Private

    private func startTypewriter() {
        guard !text.isEmpty else { return }

        if reduceMotion {
            visibleCount = text.count
            return
        }

        typewriterTask = Task { @MainActor in
            for index in 0...text.count {
                guard !Task.isCancelled else { return }
                visibleCount = index
                if index < text.count {
                    try? await Task.sleep(for: .milliseconds(Int(speed * 1_000)))
                }
            }
            // Reveal complete — show blinking cursor, fade it after 1s
            showCursor = true
            cursorOpacity = 0
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                showCursor = false
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Character-by-character text reveal with a cursor blink at completion.
    /// - Parameters:
    ///   - text: The full string to reveal.
    ///   - speed: Seconds per character (default 0.03s).
    func typewriter(text: String, speed: Double = 0.03) -> some View {
        modifier(TypewriterModifier(text: text, speed: speed))
    }
}
