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
    case alerting = "Terdeteksi ngantuk"
}

//@available(iOS 26.0, *)
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

    private static let drowsyCue = "(Driver kamu mulai terlihat ngantuk — kedipan melambat dan kepala mulai turun. Tegur santai, tanya kabarnya, dan sarankan istirahat sebentar kalau memang perlu.)"
    private static let microsleepCue = "(PERINGATAN: driver kamu baru saja microsleep, matanya sempat tertutup beberapa detik saat menyetir. Ini serius — tegur dengan tegas tapi tetap suportif, dan dorong dia untuk berhenti/istirahat sekarang juga.)"
    private static let recoveryCue = "(Driver kamu baru saja kembali fokus setelah sempat mengantuk/microsleep. Tanya gimana kondisinya sekarang dengan hangat.)"
    
    private let gemini = GeminiRouter()
    private let speechInput = SpeechInput()
    private let speechOutput = SpeechOutput()
    private let monitor = NWPathMonitor()
    private let drowsinessMonitor: DrowsinessMonitor
    private var isOnline = true
    private var history: [ChatTurn] = []
    private var proactiveTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private var lastAnnouncedState: DrowsinessState = .alert
    private var pendingDrowsinessCue: String?
    
    private var isAlarmActive: Bool {
        drowsinessMonitor.state == .drowsy || drowsinessMonitor.state == .microsleep
    }
    
    private let historyLimit = 20
    private let proactiveCue = "(Waktunya kamu yang mulai ngobrol duluan. Pilih topik baru, jangan ulangi topik sebelumnya.)"
    private let sentenceEnders: Set<Character> = [".", "!", "?"]

    init(drowsinessMonitor: DrowsinessMonitor) {
        self.drowsinessMonitor = drowsinessMonitor
        
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
                self.speechInput.resume()
                self.status = self.isAlarmActive ? .alerting : .listening
                self.armProactiveTimer()
            }
        }
        
        drowsinessMonitor.$state
            .removeDuplicates()
            .sink { [weak self] newState in
                Task { @MainActor [weak self] in
                    self?.handleDrowsinessChange(newState)
                }
            }
            .store(in: &cancellables)
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
        lastAnnouncedState = drowsinessMonitor.state
        pendingDrowsinessCue = nil
        isRunning = true

        speechInput.start { [weak self] transcript in
            Task { @MainActor [weak self] in
                await self?.handleUtterance(transcript)
            }
        }
        armProactiveTimer()
        
        if isAlarmActive {
            pauseForAlarm()
            pendingDrowsinessCue = drowsinessMonitor.state == .microsleep ? Self.microsleepCue : Self.drowsyCue
        } else {
            status = .listening
        }
    }

    func stop() {
        proactiveTask?.cancel()
        proactiveTask = nil
        speechInput.stop()
        speechOutput.stop()
        history = []
        activeModel = ""
        lastAnnouncedState = .alert
        pendingDrowsinessCue = nil
        isRunning = false
        status = .idle

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func handleUtterance(_ text: String) async {
        guard !isAlarmActive else { return }
        appendHistory(ChatTurn(role: .user, text: text))
        speechInput.pause()
        status = .thinking

        let reply = await respond()
        appendHistory(ChatTurn(role: .model, text: reply))
    }
    
    private func handleDrowsinessChange(_ newState: DrowsinessState) {
        defer { lastAnnouncedState = newState }
        guard isRunning else { return }
        
        let alarmActive = newState == .drowsy || newState == .microsleep
        let wasAlarmActive = lastAnnouncedState == .drowsy || lastAnnouncedState == .microsleep
        
        if alarmActive {
            pauseForAlarm()
            pendingDrowsinessCue = newState == .microsleep ? Self.microsleepCue : Self.drowsyCue
            return
        }
        
        if wasAlarmActive {
            pendingDrowsinessCue = Self.recoveryCue
        }
        
        guard let cue = pendingDrowsinessCue else { return }
        pendingDrowsinessCue = nil
        Task { await deliverCue(cue) }
    }
    
    private func pauseForAlarm() {
        proactiveTask?.cancel()
        proactiveTask = nil
        speechOutput.stop()
        speechInput.pause()
        status = .alerting
    }
    
    private func deliverCue(_ cue: String) async {
        guard isRunning, !isAlarmActive else { return }
        appendHistory(ChatTurn(role: .user, text: cue))
        speechInput.pause()
        status = .thinking
        
        let reply = await respond()
        appendHistory(ChatTurn(role: .model, text: reply))
    }
    
    private func armProactiveTimer() {
        proactiveTask?.cancel()
        guard !isAlarmActive, let interval = selectedMode.nextInterval else { return }

        proactiveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard let self, !Task.isCancelled else { return }
            await self.handleProactiveTurn()
        }
    }

    private func handleProactiveTurn() async {
        guard isRunning, !isAlarmActive else { return }
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
                    if !isAlarmActive { status = .speaking }
                    firstChunk = false
                }
                fullText += text
                sentenceBuffer += text
                flushSentences(&sentenceBuffer)
            }
        }

        let remaining = sentenceBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            enqueueSpeech(remaining)
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
                enqueueSpeech(sentence)
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
            if !isAlarmActive { status = .speaking }
            speakIfNotAlarming(text)
            return text
        } catch {
            activeModel = "Fallback"
            let text = "Maaf, aku lagi susah connect nih. Yuk fokus dulu ke jalan ya."
            if !isAlarmActive { status = .speaking }
            speakIfNotAlarming(text)
            return text
        }
    }
    
    private func enqueueSpeech(_ text: String) {
        guard !isAlarmActive else { return }
        speechOutput.enqueue(text)
    }

    private func speakIfNotAlarming(_ text: String) {
        guard !isAlarmActive else { return }
        speechOutput.speak(text)
    }

    private func appendHistory(_ turn: ChatTurn) {
        history.append(turn)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
    }
}
