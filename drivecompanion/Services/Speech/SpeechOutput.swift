//
//  SpeechOutput.swift
//  drivecompanion
//
//  Created by Revan Ferdinand on 02/07/26.
//

import AVFoundation

final class SpeechOutput: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice = SpeechOutput.bestVoice(for: "id-ID")
    var onFinish: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    private static func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let matches = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == language }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
        return matches.first ?? AVSpeechSynthesisVoice(language: language)
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

extension SpeechOutput: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish?()
    }
}
