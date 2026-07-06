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

    private var pendingCount = 0
    private var streamEnded = false

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

    func enqueue(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.postUtteranceDelay = 0.20
        pendingCount += 1
        synthesizer.speak(utterance)
    }

    func endStream() {
        streamEnded = true
        checkFinished()
    }

    func speak(_ text: String) {
        enqueue(text)
        endStream()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        pendingCount = 0
        streamEnded = false
    }

    private func checkFinished() {
        guard pendingCount == 0, streamEnded else { return }
        streamEnded = false
        onFinish?()
    }
}

extension SpeechOutput: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        pendingCount = max(0, pendingCount - 1)
        checkFinished()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        pendingCount = max(0, pendingCount - 1)
        checkFinished()
    }
}
