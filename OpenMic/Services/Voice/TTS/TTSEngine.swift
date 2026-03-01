import Foundation

@MainActor
protocol TTSEngineProtocol: AnyObject {
    var isSpeaking: Bool { get }
    var audioRequirement: TTSAudioRequirement { get }

    func speak(_ text: String) async
    func stop()
}
