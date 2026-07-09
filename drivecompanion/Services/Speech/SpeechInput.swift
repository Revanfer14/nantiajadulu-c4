//
//  SpeechInput.swift
//  drivecompanion
//
//  Created by Revan Ferdinand on 02/07/26.
//

import Speech
import AVFoundation

final class SpeechInput {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "id-ID"))
    private let engine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var latestTranscript = ""
    private var onUtterance: ((String) -> Void)?
    private var isPaused = false

    static func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start(onUtterance: @escaping (String) -> Void) {
        self.onUtterance = onUtterance
        isPaused = false
        startRecognitionRequest()
    }

    func pause() {
        isPaused = true
        silenceTimer?.invalidate()
        silenceTimer = nil
        stopRecognitionRequest()
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        startRecognitionRequest()
    }

    func restart() {
        isPaused = false
        startRecognitionRequest()
    }

    func stop() {
        isPaused = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        stopRecognitionRequest()
        onUtterance = nil
    }

    private func startRecognitionRequest() {
        stopRecognitionRequest()
        latestTranscript = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            try engine.start()
        } catch {
            return
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, !self.isPaused else { return }
            if let result {
                self.latestTranscript = result.bestTranscription.formattedString
                self.resetSilenceTimer()
            }
        }
    }

    private func stopRecognitionRequest() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private static let silenceTimeout: TimeInterval = 1.0

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: Self.silenceTimeout, repeats: false) { [weak self] _ in
            guard let self, !self.isPaused else { return }
            let transcript = self.latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcript.isEmpty else { return }
            self.stopRecognitionRequest()
            self.onUtterance?(transcript)
            if !self.isPaused {
                self.startRecognitionRequest()
            }
        }
    }
}
