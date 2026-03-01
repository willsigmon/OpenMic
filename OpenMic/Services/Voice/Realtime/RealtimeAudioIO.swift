@preconcurrency import AVFoundation

/// Shared audio capture/playback for all realtime voice providers.
/// Captures PCM16 at 24kHz from mic, plays received audio chunks.
@MainActor
final class RealtimeAudioIO {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    private var audioLevelContinuation: AsyncStream<Float>.Continuation?
    private var onAudioChunk: ((Data) -> Void)?

    let audioLevelStream: AsyncStream<Float>

    /// PCM16 mono at 24kHz — required by OpenAI Realtime API
    static let captureFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24000,
        channels: 1,
        interleaved: true
    )!

    /// Playback format matches capture
    static let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24000,
        channels: 1,
        interleaved: true
    )!

    init() {
        var cont: AsyncStream<Float>.Continuation!
        self.audioLevelStream = AsyncStream { cont = $0 }
        self.audioLevelContinuation = cont
    }

    deinit {
        audioLevelContinuation?.finish()
    }

    // MARK: - Start Capture

    func startCapture(onChunk: @escaping (Data) -> Void) throws {
        self.onAudioChunk = onChunk

        engine.attach(playerNode)
        engine.connect(
            playerNode,
            to: engine.mainMixerNode,
            format: Self.playbackFormat
        )

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on mic input
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: inputFormat
        ) { [weak self] buffer, _ in
            guard let self else { return }

            // Calculate audio level
            let level = self.calculateRMS(buffer: buffer)
            self.audioLevelContinuation?.yield(level)

            // Convert to PCM16 24kHz and send
            guard let converted = self.convertToPCM16(
                buffer: buffer,
                from: inputFormat
            ) else { return }

            self.onAudioChunk?(converted)
        }

        try engine.start()
        playerNode.play()
    }

    // MARK: - Stop Capture

    func stopCapture() {
        engine.inputNode.removeTap(onBus: 0)
        playerNode.stop()
        engine.stop()
        onAudioChunk = nil
    }

    // MARK: - Play Audio Chunk

    func playAudioChunk(_ data: Data) {
        guard !data.isEmpty else { return }

        let frameCount = UInt32(data.count) / 2 // PCM16 = 2 bytes per sample
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: Self.playbackFormat,
            frameCapacity: frameCount
        ) else { return }

        buffer.frameLength = frameCount

        data.withUnsafeBytes { rawBuffer in
            guard let source = rawBuffer.baseAddress else { return }
            if let dest = buffer.int16ChannelData?[0] {
                memcpy(dest, source, data.count)
            }
        }

        playerNode.scheduleBuffer(buffer)
    }

    // MARK: - Clear Playback (for barge-in)

    func clearPlaybackQueue() {
        playerNode.stop()
        playerNode.play()
    }

    // MARK: - Private Helpers

    private func convertToPCM16(
        buffer: AVAudioPCMBuffer,
        from sourceFormat: AVAudioFormat
    ) -> Data? {
        guard let converter = AVAudioConverter(
            from: sourceFormat,
            to: Self.captureFormat
        ) else { return nil }

        let ratio = Self.captureFormat.sampleRate / sourceFormat.sampleRate
        let outputFrameCount = UInt32(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: Self.captureFormat,
            frameCapacity: outputFrameCount
        ) else { return nil }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil else { return nil }

        let byteCount = Int(outputBuffer.frameLength) * 2
        guard let channelData = outputBuffer.int16ChannelData?[0] else { return nil }

        return Data(bytes: channelData, count: byteCount)
    }

    private func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }

        var sum: Float = 0
        for i in 0..<frameCount {
            sum += channelData[i] * channelData[i]
        }

        let rms = sqrt(sum / Float(frameCount))
        // Normalize to 0–1 range (typical speech RMS is 0.01–0.3)
        return min(1.0, rms * 5.0)
    }
}
