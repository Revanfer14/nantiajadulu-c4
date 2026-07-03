# GeminiModel.md

Documentation for DriveCompanion's **AI companion layer** — the voice-driven "teman menyetir" (driving buddy) that listens, chats naturally, checks in proactively, and replies aloud. This is separate from the perception engine (CoreML/ARKit); see `CLAUDE.md` for overall project context.

## Purpose

The companion is a presence, not a dashboard: casual spoken conversation, occasional check-ins, warm tone. **There is no chat UI.** Input comes from the driver's voice (microphone → speech-to-text), output is spoken aloud (text-to-speech). The only manual UI control is Start/Stop.

## Architecture — Four-Layer Routing

```
Driver speech (mic) ──▶ SpeechInput (id-ID, silence-timer 0.8s)
      │
      ▼
Safety alert?  ──yes──▶ Scripted response (deterministic, Bahasa Indonesia)
      │no
      ▼
   Online?    ──yes──▶ GeminiRouter ──▶ gemini-3.5-flash (primary)
      │no                    │              │ quota/rate-limit?
      │                      │              ▼
      │                      └──────▶ next model in chain (6 fallbacks)
      │                                     │ all exhausted?
      ▼                                     │
Foundation Models (on-device) ◀────────────┘ (online failure fallback)
      │ fails?
      ▼
Static fallback line ("Maaf, aku lagi susah connect nih.")
      │
      ▼
SpeechOutput (AVSpeechSynthesizer, id-ID voice)
```

**Hard boundary: safety-critical drowsiness alerts never go through the LLM path.** They're deterministic, pre-scripted Bahasa Indonesia responses, handled outside the companion view model entirely. Only casual companion chat — small talk, proactive check-ins, responses to things like "aku ngantuk nih" — is routed through this layer. This keeps the safety-critical path independent of connectivity, model quality, or LLM failure modes.

## Model Choice: Gemini Flash, not Pro

- Google AI Pro (the personal chat subscription) is **separate billing** from the Gemini Developer API — a Pro subscription does not unlock extra API quota.
- Free-tier API quota for Pro-class models is tight (~50 requests/day) — too restrictive for a companion that chats repeatedly per trip, even just for testing.
- Pro is tuned for heavy reasoning (math, coding, multi-step analysis) and has higher latency — not built for fast back-and-forth chat.
- Flash is designed for interactive chat/agent use cases: lower latency, and its casual-conversation quality is more than sufficient here. Pro's extra reasoning headroom isn't the bottleneck for this use case.

**Primary model: `gemini-3.5-flash`.** When it is rate-limited or quota-exhausted, `GeminiRouter` automatically steps through a chain of six fallback models (see below) rather than failing immediately.

### Considered and deferred
- **Gemini Live API** (real-time speech-to-speech, native interruption/turn-taking handling) could eventually replace the STT→LLM→TTS pipeline below with one streaming session. Flagged as a **post-MVP exploration** — Bahasa Indonesia quality on Live API hasn't been verified, and it adds WebSocket/streaming complexity not needed for the group-project demo. The current spec (separate STT/LLM/TTS steps) is the near-term path.
- **Apple Foundation Models as primary brain** — ruled out because iOS 26/27 have no official Bahasa Indonesia support yet. Kept as the **offline fallback** instead; revisit as fine-tuning support matures.
- **Firebase AI Logic** (unified `LanguageModel` protocol) — requires iOS 27, which was still in developer beta as of writing (stable expected ~mid-September 2026). Too risky to depend on for a group project deadline. Revisit once iOS 27 ships stable.

## GeminiRouter — Fallback & Rate Limiting

`Services/LLM/GeminiRouter.swift` is a Swift `actor` that sits in front of `GeminiService` and handles quota management, retries, fallback, caching, and streaming.

### Fallback chain (`GeminiRouterConfig.fallbackChain`)

Models are tried left-to-right; the first one with available quota and no rate-limit block wins.

| # | Model | RPM | TPM | RPD |
|---|---|---|---|---|
| 1 | `gemini-3.5-flash` | 5 | 250 000 | 20 |
| 2 | `gemini-3.1-flash-lite` | 15 | 250 000 | 500 |
| 3 | `gemini-3-flash` | 5 | 250 000 | 20 |
| 4 | `gemini-2.5-flash` | 5 | 250 000 | 20 |
| 5 | `gemini-2.5-flash-lite` | 10 | 250 000 | 20 |
| 6 | `gemma-4-26b` | 15 | — | 1 500 |
| 7 | `gemma-4-31b` | 15 | — | 1 500 |

### Per-model usage tracking (`ModelUsageTracker`)

Each model has its own in-memory tracker (keyed by model name in `trackers: [String: ModelUsageTracker]`):

- **RPM window:** sliding 60-second window of request timestamps. If the window is full, router records the wait until the oldest slot expires and moves on to the next model.
- **RPD counter:** daily request count, reset at midnight **Pacific time** (`America/Los_Angeles`).
- **Cooldown:** after `retriesPerModel` (2) consecutive transient failures, the model is put in a 60-second cooldown (`persistentRateLimitCooldown`) before it's eligible again.

### Routing algorithm (both `generateReply` and `streamReply`)

```
outer while true:
  for each model in chain:
    if daily quota exhausted OR in cooldown → skip (continue)
    if RPM cap reached → record minRPMDelay, skip (continue)
    attempt loop (up to retriesPerModel = 2):
      record request → call GeminiService
      success → cache + return
      transient error (429 or 5xx):
        if attempts left → sleep [1s, 2s] or Retry-After header → retry
        else → start 60s cooldown → break to next model
  after full chain sweep:
    if minRPMDelay recorded → sleep that long → retry chain
    else → throw GeminiError.allModelsExhausted
```

`usedFallback` is `true` whenever the model that answers is not `chain.first` (`gemini-3.5-flash`). This is surfaced via `.metadata(model:usedFallback:)` in the stream, logged as a warning, and exposed on `GeminiReply`.

### Response cache

- **Key:** SHA-256 hash of `systemInstruction` length-prefixed + each turn's role and text length-prefixed (collision-resistant, no personally identifiable content exposed in logs).
- **TTL:** 3 600 seconds (1 hour). Expired entries are pruned lazily on every write.
- **Behaviour:** cache hit returns immediately, increments `cacheHitCount`, logs "Cache hit — reusing…". Cache is cleared on session Stop via `clearCache()` (called from `AIViewModel`), or manually via `GeminiRouter.clearCache()`.

### Streaming

`streamReply` returns `AsyncThrowingStream<GeminiStreamEvent, Error>` with two event kinds:
- `.metadata(model: String, usedFallback: Bool)` — emitted once, before the first text chunk, from whichever model commits first.
- `.chunk(String)` — each SSE chunk from `GeminiService.streamReply`.

The router commits to a model on the first chunk received. If a stream errors **after** yielding `.metadata`, it finishes the stream rather than retrying (partial output already sent to TTS).

### In-app usage logging

`GeminiRouter.logUsageSummary()` is called after every successful stream in `AIViewModel.streamAndSpeak()`. It logs RPM/RPD used vs. cap per model to `os_log` (category `GeminiRouter`) and can be read in Console.app filtered by subsystem = bundle identifier.

## Language: Bahasa Indonesia In, Bahasa Indonesia Out

Both directions of the pipeline must be locked to Indonesian:

- **Understanding (STT):** the speech recognizer must be configured with an Indonesian locale (`id-ID`) so the driver's spoken Indonesian is transcribed correctly, not auto-detected or defaulted to English.
- **Replying (LLM):** enforced via the system persona below, which explicitly instructs replies in Bahasa Indonesia.
- **Speaking (TTS):** the synthesizer voice must also be set to `id-ID` so the companion's spoken output matches.

## System Persona

```
Kamu adalah teman ngobrol driver saat berkendara — santai, hangat, suportif.
Sesekali ajak ngobrol ringan atau tanya kabar, tapi jangan mengganggu fokus
berkendara. Jawaban singkat dan natural, dalam Bahasa Indonesia.

Topik obrolan bebas dan general — boleh soal cuaca, olahraga, film/series, musik,
teknologi, makanan, traveling, hewan, fakta unik, motivasi ringan, hobi, dan
sejenisnya. Jangan mengulang topik yang sudah pernah dibahas di percakapan ini.
Satu balasan cukup 1-3 kalimat, jangan bertele-tele.
```

The model decides *what* topic to bring up (and avoids repeats, using conversation history as context); the app decides *when* to prompt it. That split is what makes the three session modes below possible without changing the persona itself.

## Voice I/O & Permissions

Fully microphone-driven — no text input, no on-screen transcript required.

**Frameworks:** `Speech` (`SFSpeechRecognizer`, `SFSpeechAudioBufferRecognitionRequest`) for input, `AVFoundation` (`AVAudioEngine` for capture, `AVSpeechSynthesizer` for output).

**Info.plist keys required (set in the target's Info tab, same place `GEMINI_API_KEY` is configured):**

| Key | Purpose | Example value (Bahasa Indonesia) |
|---|---|---|
| `NSMicrophoneUsageDescription` | Required to capture driver's voice | "Jaga butuh akses mikrofon supaya kamu bisa ngobrol langsung dengan companion selama berkendara." |
| `NSSpeechRecognitionUsageDescription` | Required by `SFSpeechRecognizer` | "Jaga menggunakan pengenalan suara untuk memahami obrolan kamu dan membalas secara natural." |

**Runtime authorization:** request both `SFSpeechRecognizer.requestAuthorization` and the microphone record permission before a session can start — trigger this the first time Start is pressed (or on first view appear), not silently in the background.

**Continuous listening design (`SpeechInput.swift`):**
- Recognizer locale: `Locale(identifier: "id-ID")`.
- While a session is active, the mic stays open and recognition runs continuously rather than one-shot per tap.
- Silence timeout: **0.8 seconds** of no new partial result → submit the accumulated transcript as one utterance. This is shorter than typical because the driver's utterances tend to be short; adjust `SpeechInput.silenceTimeout` if clipping occurs.
- **Mute recognition while the companion is speaking** (`SpeechInput.pause()`), so the mic doesn't pick up and transcribe Jaga's own TTS output. Resume listening via `SpeechInput.resume()` once `SpeechOutput.onFinish` fires.
- `AVAudioSession` category: `.playAndRecord` with options `[.duckOthers, .defaultToSpeaker]` — ducks other audio while the companion speaks, routes output through the speaker rather than earpiece.

### Streaming TTS flush

Rather than waiting for the full Gemini reply before speaking, `AIViewModel.streamAndSpeak()` reads chunks from `GeminiRouter.streamReply` and flushes complete sentences to `SpeechOutput` as they arrive:

```
chunk arrives → append to sentenceBuffer
→ scan buffer for [.!?]
→ extract each complete sentence → speechOutput.enqueue(sentence)
→ remainder stays in buffer
stream ends → flush remaining buffer → speechOutput.endStream()
```

`SpeechOutput` queues utterances to `AVSpeechSynthesizer`; it tracks `pendingCount` and calls `onFinish` only after both the stream has ended (`endStream()`) and all queued utterances have finished playing. This gives the user a perception of near-real-time reply while keeping sentence boundaries clean for TTS.

## Session Modes

The companion's proactive-timer behavior is controlled by a mode, chosen before Start is pressed (mode selection is locked once a session is running so each session is consistent). Persona and topic pool stay identical across modes — only the initiation cadence changes. Driver-initiated speech (via mic) is always recognized and answered in every mode, regardless of the timer.

| Mode | Display name | Behavior | Timer |
|---|---|---|---|
| `continuousProactive` | `Terus-Menerus` | Companion keeps opening new topics back-to-back, staying coherent via conversation history. | ~15–30 s (randomized), re-armed after every reply |
| `driverInitiated` | `Hanya Merespons` | Companion never speaks first — pure reactive chat. | None |
| `occasionalProactive` | `Sesekali` | Companion checks in now and then, sparser than continuous. | ~60–120 s (randomized), re-armed after every reply |

**How coherence across topics works:** every exchange (driver utterance or companion-initiated line) is appended to a rolling conversation history and sent back to Gemini as multi-turn context on the next call. That's why topics can drift — "cuaca" → "musik" → "rencana weekend" — while still reading as one continuous conversation instead of disconnected one-shot prompts.

**How a companion-initiated turn works:** there's no real driver utterance to send, so the proactive trigger sends a short internal cue instead — `"(Waktunya kamu yang mulai ngobrol duluan. Pilih topik baru, jangan ulangi topik sebelumnya.)"` — and only the model's spoken reply is what the driver hears. The cue is stored in history purely to keep the API's turn order valid and to help the model track what it already opened with; it is never spoken or shown.

**These intervals are tuned for iteration/demo, not final production behavior.** Production triggers should eventually be state-aware — trip duration, silence length, drowsiness precursor signals — per the six DURING-phase innovation principles in `CLAUDE.md` (anti-habituation by design, sleep-inertia-aware activation, etc.) rather than fixed timers.

## Companion Status

`CompanionStatus` (in `AIViewmodel.swift`) exposes the current state to the UI and drives the status label in `AIGeminiView`:

| Case | Raw value | When |
|---|---|---|
| `idle` | `Menunggu...` | Session stopped |
| `listening` | `Mendengarkan...` | Mic open, waiting for driver speech |
| `thinking` | `Lagi mikir...` | Utterance submitted to LLM, waiting for first chunk |
| `speaking` | `Ngobrol...` | TTS playing companion reply |

## Session Lifecycle (Start / Stop)

One button, two states — this is the only manual control in the UI.

- **Start:** requests mic/speech permissions if not already granted (`SpeechInput.requestAuthorization()`), configures `AVAudioSession` (`.playAndRecord`, `.duckOthers`, `.defaultToSpeaker`), begins a fresh session (empty conversation history), arms the proactive timer per the selected mode, and starts continuous listening.
- **While running:** the companion retains full conversation context for the entire session — every driver utterance and every companion reply, proactive or reactive, accumulates into the same history and informs every subsequent reply. Nothing is cleared mid-session.
- **Stop:** cancels the proactive timer, stops `SpeechInput` and `SpeechOutput`, clears conversation history, resets `activeModel`, deactivates `AVAudioSession`, and returns to `status = .idle`. A subsequent Start begins completely fresh, with no memory of the previous session.

Conversation history is capped to a rolling window of **20 turns** (`historyLimit`) to keep API payload and free-tier token usage in check on long sessions — the driver experiences this as "the companion remembers the whole trip," even though very old turns eventually roll off.

## Files

| File | Responsibility |
|---|---|
| `Services/LLM/GeminiRouter.swift` | Swift `actor`; fallback chain across 7 models; per-model RPM/RPD tracking & cooldown; retry logic; response cache (SHA-256 key, 1-hour TTL); both non-streaming (`generateReply`) and streaming (`streamReply`) entry points. |
| `Services/LLM/GeminiService.swift` | Direct REST client to the Gemini Developer API. `generateContent` (non-streaming) and `streamGenerateContent` (SSE). Reads API key from `Info.plist`. Parses `429` → `GeminiError.rateLimited` with optional `Retry-After`. |
| `Services/Speech/SpeechInput.swift` | `SFSpeechRecognizer` wrapper, `id-ID` locale, continuous recognition with 0.8-second silence timer, `pause()`/`resume()`/`stop()`. |
| `Services/Speech/SpeechOutput.swift` | `AVSpeechSynthesizer` wrapper; picks highest-quality `id-ID` voice; `enqueue()`/`endStream()` for streaming TTS; `speak()` for one-shot; fires `onFinish` after all queued utterances complete. |
| `ViewModels/AIViewmodel.swift` | `@MainActor` `ObservableObject` (`@available(iOS 26.0, *)`); orchestrates mic capture, routing, history, session mode/timer logic, Start/Stop lifecycle, sentence-buffer flush. |
| `Views/AIGeminiView.swift` | Minimal SwiftUI screen: status label, segmented mode picker (disabled while running), Start/Stop button, active model indicator in toolbar (title "C4"). No chat UI, no transcript, no text input. |
| `Secrets.xcconfig` | Local-only config holding `GEMINI_API_KEY`. **Never commit.** |
| `README_gemini_setup.md` | Full step-by-step Xcode setup instructions. |

Implementation is direct `URLSession` REST calls to the Gemini API — not the Firebase SDK — since that path doesn't require iOS 27.

## Setup (summary — see `README_gemini_setup.md` for the full walkthrough)

1. Xcode: File → New → File → Configuration Settings File, name it `Secrets.xcconfig`, place at the project root.
2. Add `GEMINI_API_KEY = your_key_here`. Get a key from [aistudio.google.com](https://aistudio.google.com) — free tier, no credit card, **keep billing off**.
3. Add `Secrets.xcconfig` to `.gitignore` **before** the first commit that touches it.
4. Project navigator → project (blue icon) → Info tab → Configurations → set `Secrets.xcconfig` for both Debug and Release, at the project level.
5. Target → Info tab → add a key: `GEMINI_API_KEY`, type String, value `$(GEMINI_API_KEY)`.
6. Same Info tab → add `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` (see Voice I/O & Permissions above for example values).
7. Build. `Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY")` should now resolve to the real key.

**Known limitation:** this hides the key from Git, but it's still bundled inside the compiled binary (extractable via decompilation). Acceptable for a course project; not production-grade key security.

## Secret Hygiene — Known Incident & Fix

`Secrets.xcconfig` was committed to Git *before* `.gitignore` was applied to it. `.gitignore` is **not retroactive** — it only prevents untracked files from being staged; a file already committed keeps being tracked regardless of later `.gitignore` entries.

Fix applied:
```bash
git rm --cached Secrets.xcconfig
git commit -m "Stop tracking Secrets.xcconfig"
```

Because the key had already entered local commit history — even though the actual push was blocked by GitHub's secret scanning — it was treated as compromised: **the key was regenerated/revoked in Google AI Studio** rather than attempting to scrub Git history after the fact. Treat any key that touches a commit, pushed or not, as burned.

**Rule going forward:** verify `Secrets.xcconfig` is in `.gitignore` *before* it's ever created/staged, not after.

## Monitoring

No paid dashboard needed for this project. **aistudio.google.com/usage** shows RPM (requests/minute), TPM (tokens/minute), and RPD (requests/day) per model against the free-tier quota. Full request/response logs require billing to be enabled — intentionally skipped to stay on the free tier; not needed at course-project observability levels.

**In-app:** after every successful stream, `AIViewModel` calls `GeminiRouter.logUsageSummary()`, which emits an `os_log` message (subsystem = bundle identifier, category = `GeminiRouter`) showing RPM/RPD used vs. cap per model and cache hit count. Read it live in Console.app filtered by subsystem.

## Roadmap / Open Items

- Sync the companion's 3D model animation state (idle/talking/listening) with `CompanionStatus` — the enum already tracks the four states needed.
- Re-evaluate Firebase AI Logic once iOS 27 is stable.
- Explore Gemini Live API for true speech-to-speech, replacing the separate STT/LLM/TTS steps with one streaming session, once Bahasa Indonesia quality is verified.
- Replace the fixed-interval proactive timers (Mode 1 & 3) with state-aware production triggers — trip duration, silence length, drowsiness precursor signals.
