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

    var id: String { rawValue }

    var nextInterval: TimeInterval? {
        switch self {
        case .continuousProactive:
            return TimeInterval.random(in: 15...30)
        case .driverInitiated:
            return nil
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
    @Published var selectedMode: SessionMode = .continuousProactive
    @Published var permissionDenied = false
    @Published var activeModel: String = ""

    private static let systemPersona = """
    Kamu adalah sohib dekat yang lagi nemenin driver nyetir — santai, akrab, genuinely penasaran sama cerita dia. Ngobrolnya kayak teman lama, bukan asisten.

    Gaya bahasa: sehari-hari, boleh pakai "eh", "btw", "nih", "kan", "wkwk" atau ekspresi ringan lainnya — wajar aja, jangan lebay. Jangan pakai emoji, simbol, tanda bintang, atau format apapun karena semua output kamu diucapkan langsung.

    Cara ngobrol: nanggepin dulu apa yang driver bilang sebelum ganti topik, ajukan pertanyaan lanjutan yang relevan, variasikan cara kamu buka kalimat. Hindari sapaan yang sama terus atau pola yang terdengar template.

    Konten: topik bebas — cuaca, olahraga, film/series, musik, teknologi, makanan, traveling, hewan, fakta unik, motivasi ringan, hobi, dan sejenisnya. Jangan ulangi topik yang sudah dibahas di percakapan ini.

    Panjang: 1–3 kalimat, ringkas dan enak diucapkan. Tidak perlu bertele-tele.
    """

    private static let drowsyCue = "(Driver kamu mulai terlihat ngantuk — kedipan melambat dan kepala mulai turun. Tegur santai, tanya kabarnya, dan sarankan istirahat sebentar kalau memang perlu.)"
    private static let microsleepCue = "(PERINGATAN: driver kamu baru saja microsleep, matanya sempat tertutup beberapa detik saat menyetir. Ini serius — tegur dengan tegas tapi tetap suportif, dan dorong dia untuk berhenti/istirahat sekarang juga.)"
    private static let recoveryCue = "(Driver kamu baru saja kembali fokus setelah sempat mengantuk/microsleep. Tanya gimana kondisinya sekarang dengan hangat.)"
    
    private let gemini = GeminiService()
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
    private let sentenceEnders: Set<Character> = [".", "!", "?"]

    private var proactiveCue: String {
        let cues = [
            "(Waktunya kamu mulai ngobrol duluan. Buka dengan cara yang natural — bisa nanya kabar driver, nyeletuk sesuatu, atau angkat topik ringan baru yang belum pernah dibahas.)",
            "(Kamu yang memulai. Pilih pendekatan yang berbeda dari sebelumnya — mungkin tanya pendapat driver soal sesuatu, atau buka topik yang seru dan fresh.)",
            "(Giliran kamu duluan. Cari cara pembukaan yang santai dan variatif, jangan terkesan template. Topik harus baru, belum pernah dibahas di percakapan ini.)",
            "(Mulai ngobrol sekarang. Bisa nanya kondisi driver dengan hangat, atau langsung lontar topik ringan yang menarik dan belum disentuh sebelumnya.)"
        ]
        return cues.randomElement() ?? cues[0]
    }

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
                await self?.sendTurn(transcript)
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

    private func sendTurn(_ userText: String) async {
        guard isRunning, !isAlarmActive else { return }
        appendHistory(ChatTurn(role: .user, text: userText))
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
        Task { await sendTurn(cue) }
    }
    
    private func pauseForAlarm() {
        proactiveTask?.cancel()
        proactiveTask = nil
        speechOutput.stop()
        speechInput.pause()
        status = .alerting
    }
    
    private func armProactiveTimer() {
        proactiveTask?.cancel()
        guard !isAlarmActive, let interval = selectedMode.nextInterval else { return }

        proactiveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard let self, !Task.isCancelled else { return }
            await self.sendTurn(self.proactiveCue)
        }
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
        var attempt = 0
        while true {
            let stream = gemini.streamReply(systemInstruction: Self.systemPersona, history: history)
            var fullText = ""
            var sentenceBuffer = ""
            var firstChunk = true
            do {
                for try await chunk in stream {
                    if firstChunk {
                        activeModel = GeminiService.model
                        if !isAlarmActive { status = .speaking }
                        firstChunk = false
                    }
                    fullText += chunk
                    sentenceBuffer += chunk
                    flushSentences(&sentenceBuffer)
                }
                let remaining = sentenceBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !remaining.isEmpty {
                    enqueueSpeech(remaining)
                }
                speechOutput.endStream()
                return fullText
            } catch GeminiError.rateLimited(let retryAfter) where fullText.isEmpty && attempt == 0 {
                attempt += 1
                try await Task.sleep(for: .seconds(min(retryAfter ?? 2, 10)))
            }
        }
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
