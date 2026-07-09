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
internal import _LocationEssentials

enum CompanionStatus: String {
    case idle = "Menunggu..."
    case listening = "Mendengarkan..."
    case thinking = "Lagi mikir..."
    case speaking = "Ngobrol..."
    case alerting = "Terdeteksi ngantuk"
    case muted = "Mikrofon dimatikan"
}

//@available(iOS 26.0, *)
@MainActor
final class AIViewModel: ObservableObject {
    @Published var isRunning = false
    @Published var status: CompanionStatus = .idle
    @Published var permissionDenied = false
    @Published var activeModel: String = ""
    @Published var isMuted = false
    
    private static let systemPersona = """
        Kamu adalah sohib dekat yang lagi nemenin driver nyetir — santai, akrab, genuinely penasaran sama cerita dia. Ngobrolnya kayak temen lama, bukan asisten.
        
        Panggil diri sendiri "gua" dan lawan bicara "lu" — bukan "aku/kamu", bukan "saya/anda". Konsisten dari awal sampai akhir.
        
        JANGAN pernah tutup kalimat dengan "ya" (contoh yang dilarang: "hati-hati ya", "semangat ya", "seru ya"). Ganti dengan penutup lain atau langsung potong kalimatnya, misal "hati-hati di jalan" bukan "hati-hati ya di jalan".
        
        Gaya bahasa: pakai kontraksi sehari-hari — "gak" bukan "tidak", "kalo" bukan "kalau", "emang" bukan "memang", "gitu" bukan "seperti itu", "udah" bukan "sudah". Selipin "eh", "btw", "nih", "kan", "wkwk" secukupnya, jangan tiap kalimat.
        
        Hindari frasa yang kedengaran AI banget: "semangat terus", "wah keren banget", "menurutku", "gimana kabarnya", atau nanya sesuatu yang generic tanpa nyambung ke omongan driver sebelumnya. Jangan selalu antusias — kadang cukup nimbrung santai, boleh sedikit skeptis atau bercanda kalo emang pas momennya.
        
        Jangan pakai emoji, simbol, tanda bintang, atau format apapun karena semua output kamu diucapkan langsung.
        
        Cara ngobrol: nanggepin dulu apa yang driver bilang sebelum ganti topik, ajukan pertanyaan lanjutan yang relevan, variasikan cara lu buka kalimat — jangan mulai dengan pola yang sama terus (misal selalu "Wah" atau selalu nanya).
        
        Konten: topik bebas — cuaca, olahraga, film/series, musik, teknologi, makanan, traveling, hewan, fakta unik, motivasi ringan, hobi, dan sejenisnya. Jangan ulangi topik yang udah dibahas di percakapan ini.
        
        Panjang: 1–3 kalimat, ringkas dan enak diucapkan. Gak perlu bertele-tele.
        
        Contoh gaya ngobrol yang bener:
        
        Driver: "Capek banget gua hari ini, macet dari tadi."
        Kamu: "Anjir sama, dari tadi gua liat maps merah semua. Lu udah dari jam berapa di jalan?"
        
        Driver: "Baru nonton film horor semalem, serem juga."
        Kamu: "Judulnya apa tuh? Gua udah lama gak nonton horor soalnya kebanyakan ketebak endingnya."
        
        Driver: "Enakan kucing atau anjing sih menurut lu?"
        Kamu: "Kucing sih gua, gak ribet ngurusnya. Tapi anjing emang lebih setia katanya, lu tim mana?"
        """
    
    private static let recoveryNote = "(Driver baru saja pulih dari kondisi mengantuk/microsleep dan sekarang sudah fokus kembali.)"

    private static let greetingLine = "Halo bro, Budi disini, gue bakal nemenin lu selama perjalanan. Kalau ada yang mau lu tanyain atau obrolin, langsung aja ya bro."
    
    private static let restStopKeywords = ["istirahat", "spbu", "masjid", "rest area", "pom bensin"]
    
    private func isRestStopRequest(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return Self.restStopKeywords.contains { lowercased.contains($0) }
    }
    
    private static let affirmativeKeywords = ["ya", "oke", "boleh", "gas", "yuk", "sip", "ayo"]
    
    private func isAffirmative(_ text: String) -> Bool {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespaces)
        return Self.affirmativeKeywords.contains { lowercased == $0 || lowercased.hasPrefix($0 + " ") || lowercased.hasPrefix($0 + ",") }
    }
    
    private static let negativeKeywords = ["tidak", "gak", "ga", "nggak", "enggak", "engga", "gausah", "males", "nanti aja", "skip"]

    private func isNegative(_ text: String) -> Bool {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespaces)
        return Self.negativeKeywords.contains { lowercased == $0 || lowercased.hasPrefix($0 + " ") || lowercased.hasPrefix($0 + ",") }
    }
    
    private let gemini = GeminiService()
    private let speechInput = SpeechInput()
    private let speechOutput = SpeechOutput()
    private let monitor = NWPathMonitor()
    private let drowsinessMonitor: DrowsinessMonitor
    private let restStopViewModel: RestStopViewModel
    
    private var isOnline = true
    
    @Published var history: [ChatTurn] = []

    private var restStopProactiveTask: Task<Void, Never>?
    private var lastProactiveSuggestionKey: String?
    private var lastProactiveSuggestionAt: Date?
    private let restStopCheckInterval: TimeInterval = 300 // how often do we check
    private let proactiveCooldown: TimeInterval = 900 // how long do we wait before suggesting (again)
    
    private var cancellables = Set<AnyCancellable>()
    
    private var lastAnnouncedState: DrowsinessState = .alert
    private var pendingRecoveryState: DrowsinessState?
    private var pendingRestStopPrompt = false
    private var pendingSuggestionOrigin: RestStopSuggestionOrigin?
    private var isGreeting = false
    
    private var isAlarmActive: Bool {
        drowsinessMonitor.state == .drowsy || drowsinessMonitor.state == .microsleep
    }
    
    private let historyLimit = 20
    
    init(drowsinessMonitor: DrowsinessMonitor, restStopViewModel: RestStopViewModel) {
        self.drowsinessMonitor = drowsinessMonitor
        self.restStopViewModel = restStopViewModel
        
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
                if self.isGreeting {
                    self.isGreeting = false
                    self.finishGreeting()
                    return
                }
                if self.isMuted {
                    self.status = self.isAlarmActive ? .alerting : .muted
                    return
                }
                self.speechInput.resume()
                self.status = self.isAlarmActive ? .alerting : .listening
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
        pendingRecoveryState = nil
        pendingRestStopPrompt = false
        isMuted = false
        isRunning = true
        
        speechInput.start { [weak self] transcript in
            Task { @MainActor [weak self] in
                await self?.sendTurn(transcript)
            }
        }

        if isAlarmActive {
            pauseForAlarm()
            pendingRecoveryState = drowsinessMonitor.state
        } else {
            speakGreeting()
        }
        
        restStopProactiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.restStopCheckInterval))
                guard !Task.isCancelled, self.isRunning else { return }
                await self.checkProactiveRestStop()
            }
        }
    }
    
    func stop() {
        speechInput.stop()
        speechOutput.stop()
        history = []
        activeModel = ""
        lastAnnouncedState = .alert
        pendingRecoveryState = nil
        pendingRestStopPrompt = false
        pendingSuggestionOrigin = nil
        isMuted = false
        isRunning = false
        isGreeting = false
        status = .idle
        restStopProactiveTask?.cancel()
        restStopProactiveTask = nil
        lastProactiveSuggestionKey = nil
        lastProactiveSuggestionAt = nil
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func sendTurn(_ userText: String) async {
        guard isRunning, !isAlarmActive, status == .listening else { return }

        appendHistory(ChatTurn(role: .user, text: userText))

        if pendingRestStopPrompt {
            pendingRestStopPrompt = false
            if isAffirmative(userText) {
                await handleRestStopRequest(origin: .drowsyConfirmed)
                return
            }
            if isNegative(userText) {
                await declineRestStopPrompt()
                return
            }
        }
        
        if restStopViewModel.suggestedStop != nil {
            if isAffirmative(userText) {
                await confirmRestStop()
                return
            }
            if isNegative(userText) {
                await declineRestStopCard()
                return
            }
        }
        
        if isRestStopRequest(userText) {
            await handleRestStopRequest(origin: .voiceRequest)
            return
        }
        
        await deliverCue(userText)
    }
    
    private func confirmRestStop() async {
        guard let candidate = restStopViewModel.confirm() else { return }
        pendingSuggestionOrigin = nil
        speechInput.pause()
        status = .speaking
        let text = "Oke, meluncur ke \(candidate.name) ya. Jangan lupa balik ke app ini lagi."
        appendHistory(ChatTurn(role: .model, text: text))
        speakIfNotAlarming(text)
        try? await Task.sleep(for: .seconds(2))
        restStopViewModel.openInMaps(candidate)
    }
    
    private func declineRestStopPrompt() async {
        speechInput.pause()
        status = .speaking
        let text = "Oke, lanjut aja ya."
        appendHistory(ChatTurn(role: .model, text: text))
        speakIfNotAlarming(text)
    }

    private func declineRestStopCard() async {
        let origin = pendingSuggestionOrigin
        restStopViewModel.dismiss()
        pendingSuggestionOrigin = nil
        speechInput.pause()
        status = .speaking
        let text = origin == .microsleep
            ? "Oke, tapi tolong beneran hati-hati ya, tadi itu bahaya banget."
            : "Oke deh."
        appendHistory(ChatTurn(role: .model, text: text))
        speakIfNotAlarming(text)
    }
    
    private func presentWithETA(_ candidate: RestStopCandidate) {
        Task { [weak self] in
            guard let self else { return }
            let updated = await self.restStopViewModel.fetchEstimatedTime(for: candidate)
            guard self.restStopViewModel.suggestedStop?.id == candidate.id else { return }
            self.restStopViewModel.present(updated)
        }
    }
    
    private func deliverCue(_ text: String) async {
        guard isRunning, !isAlarmActive else { return }
        speechInput.pause()
        status = .thinking
        let reply = await respond()
        appendHistory(ChatTurn(role: .model, text: reply))
    }
    
    private func handleRestStopRequest(origin: RestStopSuggestionOrigin = .voiceRequest) async {
        await searchAndPresentRestStop(origin: origin) { candidate in
            let distanceKm = candidate.distance / 1000
            return "Ada \(candidate.name), sekitar \(String(format: "%.1f", distanceKm)) km lagi. Mau ke situ?"
        }
    }

    private func searchAndPresentRestStop(
        origin: RestStopSuggestionOrigin,
        notFoundMessage: String = "Belum ketemu tempat istirahat di sekitar sini nih.",
        foundMessage: (RestStopCandidate) -> String
    ) async {
        speechInput.pause()
        status = .thinking

        let candidates = await restStopViewModel.findCandidates()
        guard let nearest = candidates.first else {
            status = .speaking
            appendHistory(ChatTurn(role: .model, text: notFoundMessage))
            speakIfNotAlarming(notFoundMessage)
            return
        }

        restStopViewModel.present(nearest)
        pendingSuggestionOrigin = origin
        status = .speaking
        let message = foundMessage(nearest)
        appendHistory(ChatTurn(role: .model, text: message))
        speakIfNotAlarming(message)
        presentWithETA(nearest)
    }
    
    private func checkProactiveRestStop() async {
        guard isRunning, !isAlarmActive, status == .listening, !pendingRestStopPrompt, restStopViewModel.suggestedStop == nil else { return }
        
        let candidates = await restStopViewModel.findCandidates()
        guard let nearest = candidates.first, !isAlarmActive, status == .listening else { return }
        
        let key = coordinateKey(for: nearest)
        if key == lastProactiveSuggestionKey,
           let lastAt = lastProactiveSuggestionAt,
           Date().timeIntervalSince(lastAt) < proactiveCooldown {
            return
        }
        
        lastProactiveSuggestionKey = key
        lastProactiveSuggestionAt = Date()
        
        speechInput.pause()
        restStopViewModel.present(nearest)
        pendingSuggestionOrigin = .proactive
        let distanceKm = nearest.distance / 1000
        status = .speaking
        let text = "Eh, ada \(nearest.name) sekitar \(String(format: "%.1f", distanceKm)) km lagi nih, mau mampir sebentar?"
        appendHistory(ChatTurn(role: .model, text: text))
        speakIfNotAlarming(text)
        presentWithETA(nearest)
    }
    
    private func coordinateKey(for candidate: RestStopCandidate) -> String {
        String(format: "%.4f,%.4f", candidate.coordinate.latitude, candidate.coordinate.longitude)
    }
    
    private func handleDrowsinessChange(_ newState: DrowsinessState) {
        defer { lastAnnouncedState = newState }
        guard isRunning else { return }
        
        let alarmActive = newState == .drowsy || newState == .microsleep
        let wasAlarmActive = lastAnnouncedState == .drowsy || lastAnnouncedState == .microsleep

        if isGreeting {
            if alarmActive {
                let isPendingMicrosleep = pendingRecoveryState == .microsleep
                if newState == .microsleep || !isPendingMicrosleep {
                    pendingRecoveryState = newState
                }
            }
            return
        }

        if alarmActive {
            pauseForAlarm()
            let isPendingMicrosleep =  pendingRecoveryState == .microsleep
            if newState == .microsleep || !isPendingMicrosleep {
                pendingRecoveryState = newState
            }
            return
        }
        
        if wasAlarmActive {
            if let state = pendingRecoveryState {
                pendingRecoveryState = nil
                Task { await handleDrowsinessRecovery(for: state) }
            } else {
                resumeAfterAlarm()
            }
            return
        }
        
        guard let state = pendingRecoveryState else { return }
        pendingRecoveryState = nil
        Task { await handleDrowsinessRecovery(for: state) }
    }
    
    private func handleDrowsinessRecovery(for state: DrowsinessState) async {
        if state == .microsleep {
            await presentMicrosleepRestStop()
        } else {
            await askAboutRestStop()
        }
    }

    private func askAboutRestStop() async {
        speechInput.pause()
        status = .speaking
        let text = "Eh, sori gua motong obrolan tadi ya. Lu keliatan mulai ngantuk nih — mau gua cariin tempat istirahat terdekat?"
        appendHistory(ChatTurn(role: .model, text: text))
        speakIfNotAlarming(text)
        pendingRestStopPrompt = true
    }

    private func presentMicrosleepRestStop() async {
        await searchAndPresentRestStop(
            origin: .microsleep,
            notFoundMessage: "Eh, tadi lu sempet microsleep bentar. Gua belum nemu tempat istirahat terdekat, tapi pelan-pelan ya, cari tempat aman buat berhenti.",
            foundMessage: { candidate in
                let distanceKm = candidate.distance / 1000
                return "Eh bentar ya, tadi lu sempet ketiduran sepersekian detik — itu bahaya banget. Ada \(candidate.name) sekitar \(String(format: "%.1f", distanceKm)) km lagi, mampir istirahat dulu yuk."
            })
    }
    
    private func pauseForAlarm() {
        speechOutput.stop()
        speechInput.pause()
        status = .alerting
    }
    
    private func resumeAfterAlarm() {
        appendHistory(ChatTurn(role: .user, text: Self.recoveryNote, isInternal: true))
        if isMuted {
            status = .muted
            return
        }
        speechInput.resume()
        status = .listening
    }

    func toggleMute() {
        guard isRunning else { return }
        isMuted.toggle()
        if isMuted {
            speechOutput.stop()
            speechInput.pause()
            status = isAlarmActive ? .alerting : .muted
        } else {
            guard !isAlarmActive else { return }
            speechInput.resume()
            status = .listening
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
            var firstChunk = true
            do {
                for try await chunk in stream {
                    if firstChunk {
                        activeModel = GeminiService.model
                        if !isAlarmActive { status = .speaking }
                        firstChunk = false
                    }
                    fullText += chunk
                }
                let reply = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !reply.isEmpty {
                    enqueueSpeech(reply)
                }
                speechOutput.endStream()
                return fullText
            } catch GeminiError.rateLimited(let retryAfter) where fullText.isEmpty && attempt == 0 {
                attempt += 1
                try await Task.sleep(for: .seconds(min(retryAfter ?? 2, 10)))
            }
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

    private func speakGreeting() {
        isGreeting = true
        speechInput.pause()
        status = .speaking
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, self.isRunning, self.isGreeting else { return }
            self.appendHistory(ChatTurn(role: .model, text: Self.greetingLine))
            self.speechOutput.speak(Self.greetingLine)
        }
    }

    private func finishGreeting() {
        if isAlarmActive {
            pauseForAlarm()
            let isPendingMicrosleep = pendingRecoveryState == .microsleep
            if drowsinessMonitor.state == .microsleep || !isPendingMicrosleep {
                pendingRecoveryState = drowsinessMonitor.state
            }
            return
        }
        if let state = pendingRecoveryState {
            pendingRecoveryState = nil
            Task { await handleDrowsinessRecovery(for: state) }
            return
        }
        if isMuted {
            status = .muted
            return
        }
        speechInput.resume()
        status = .listening
    }
    
    private func appendHistory(_ turn: ChatTurn) {
        history.append(turn)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
    }
}
