//
//  AIViewmodel.swift
//  drivecompanion
//
//  Created by Revan Ferdinand on 02/07/26.
//

import Foundation
import Network
import FoundationModels
import AVFoundation
import Combine

enum SessionMode: String, CaseIterable, Identifiable {
    case continuousProactive = "Terus-Menerus"
    case driverInitiated = "Hanya Merespons"
    case occasionalProactive = "Sesekali"

    var id: String { rawValue }

    var nextInterval: TimeInterval? {
        switch self {
        case .continuousProactive:
            return TimeInterval.random(in: 15...30)
        case .driverInitiated:
            return nil
        case .occasionalProactive:
            return TimeInterval.random(in: 60...120)
        }
    }
}

enum CompanionStatus: String {
    case idle = "Menunggu..."
    case listening = "Mendengarkan..."
    case thinking = "Lagi mikir..."
    case speaking = "Ngobrol..."
}

@available(iOS 26.0, *)
@MainActor
final class AIViewModel: ObservableObject {
    @Published var isRunning = false
    @Published var status: CompanionStatus = .idle
    @Published var selectedMode: SessionMode = .occasionalProactive
    @Published var permissionDenied = false
    @Published var activeModel: String = ""

    private static let systemPersona = """
    Kamu adalah teman ngobrol driver saat berkendara — santai, hangat, suportif.
    Sesekali ajak ngobrol ringan atau tanya kabar, tapi jangan mengganggu fokus
    berkendara. Jawaban singkat dan natural, dalam Bahasa Indonesia.

    Topik obrolan bebas dan general — boleh soal cuaca, olahraga, film/series, musik,
    teknologi, makanan, traveling, hewan, fakta unik, motivasi ringan, hobi, dan
    sejenisnya. Jangan mengulang topik yang sudah pernah dibahas di percakapan ini.
    Satu balasan cukup 1-3 kalimat, jangan bertele-tele.
    """

    private let gemini = GeminiRouter()
    private let speechInput = SpeechInput()
    private let speechOutput = SpeechOutput()
    private let monitor = NWPathMonitor()
    private var isOnline = true
    private var history: [ChatTurn] = []
    private var proactiveTask: Task<Void, Never>?

    private let historyLimit = 20
    private let proactiveCue = "(Waktunya kamu yang mulai ngobrol duluan. Pilih topik baru, jangan ulangi topik sebelumnya.)"
    private let sentenceEnders: Set<Character> = [".", "!", "?"]

    init() {
        let queue = DispatchQueue(label: "jaga.connectivity-monitor")
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isOnline = satisfied
            }
        }
        monitor.start(queue: queue)

        speechOutput.onFinish = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.status = .listening
                self.speechInput.resume()
                self.armProactiveTimer()
            }
        }
    }

    func start() async {
        let granted = await SpeechInput.requestAuthorization()
        guard granted else {
            permissionDenied = true
            return
        }
        permissionDenied = false

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return
        }

        history = []
        activeModel = ""
        isRunning = true
        status = .listening

        speechInput.start { [weak self] transcript in
            Task { @MainActor [weak self] in
                await self?.handleUtterance(transcript)
            }
        }

        armProactiveTimer()
    }

    func stop() {
        proactiveTask?.cancel()
        proactiveTask = nil
        speechInput.stop()
        speechOutput.stop()
        history = []
        activeModel = ""
        isRunning = false
        status = .idle

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func handleUtterance(_ text: String) async {
        appendHistory(ChatTurn(role: .user, text: text))
        speechInput.pause()
        status = .thinking

        let reply = await respond()
        appendHistory(ChatTurn(role: .model, text: reply))
    }

    private func armProactiveTimer() {
        proactiveTask?.cancel()
        guard let interval = selectedMode.nextInterval else { return }

        proactiveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard let self, !Task.isCancelled else { return }
            await self.handleProactiveTurn()
        }
    }

    private func handleProactiveTurn() async {
        guard isRunning else { return }
        appendHistory(ChatTurn(role: .user, text: proactiveCue))
        speechInput.pause()
        status = .thinking

        let reply = await respond()
        appendHistory(ChatTurn(role: .model, text: reply))
    }

    private func respond() async -> String {
        if isOnline {
            do {
                return try await streamAndSpeak()
            } catch {
                return await onDeviceReply()
            }
        } else {
            return await onDeviceReply()
        }
    }

    private func streamAndSpeak() async throws -> String {
        let stream = await gemini.streamReply(systemInstruction: Self.systemPersona, history: history)
        var fullText = ""
        var sentenceBuffer = ""
        var firstChunk = true

        for try await event in stream {
            switch event {
            case .metadata(let model, _):
                activeModel = model
            case .chunk(let text):
                if firstChunk {
                    status = .speaking
                    firstChunk = false
                }
                fullText += text
                sentenceBuffer += text
                flushSentences(&sentenceBuffer)
            }
        }

        let remaining = sentenceBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            speechOutput.enqueue(remaining)
        }
        speechOutput.endStream()

        await gemini.logUsageSummary()
        return fullText
    }

    private func flushSentences(_ buffer: inout String) {
        while let idx = buffer.firstIndex(where: { sentenceEnders.contains($0) }) {
            let end = buffer.index(after: idx)
            let sentence = String(buffer[..<end]).trimmingCharacters(in: .whitespaces)
            if !sentence.isEmpty {
                speechOutput.enqueue(sentence)
            }
            buffer = String(buffer[end...])
        }
    }

    private func onDeviceReply() async -> String {
        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: Self.systemPersona
        )
        let prompt = history.last?.text ?? ""
        do {
            let response = try await session.respond(to: prompt)
            activeModel = "Foundation Models (on-device)"
            let text = response.content
            status = .speaking
            speechOutput.speak(text)
            return text
        } catch {
            activeModel = "Fallback"
            let text = "Maaf, aku lagi susah connect nih. Yuk fokus dulu ke jalan ya."
            status = .speaking
            speechOutput.speak(text)
            return text
        }
    }

    private func appendHistory(_ turn: ChatTurn) {
        history.append(turn)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
    }
}
