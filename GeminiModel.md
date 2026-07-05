# GeminiModel.md

Documentation for DriveCompanion's **AI companion layer** — the voice-driven "teman menyetir" (driving buddy) that listens, chats naturally, checks in proactively, and replies aloud. This is separate from the perception engine (CoreML/ARKit); see `CLAUDE.md` for overall project context.

## Purpose

The companion is a presence, not a dashboard: casual spoken conversation, occasional check-ins, warm tone. **There is no chat UI.** Input comes from the driver's voice (microphone → speech-to-text), output is spoken aloud (text-to-speech). The only manual UI control is Start/Stop.

## Architecture

```
Driver speech (mic) ──▶ SpeechInput (id-ID, silence-timer 0.8s)
      │
      ▼
   Online?    ──yes──▶ GeminiService.streamReply (gemini-3.1-flash-lite)
      │no                    │ any error (one retry on pre-chunk 429)
      ▼                      ▼
Foundation Models (on-device) ──▶ static fallback line ("Maaf, aku lagi susah connect nih.")
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

**Single model: `gemini-3.1-flash-lite`.** Hardcoded as `GeminiService.model` — the only place the model name appears in the codebase. Chosen for its 500 RPD / 15 RPM free-tier headroom; casual-conversation quality is sufficient. Any Gemini failure falls back to on-device FoundationModels with no intermediate routing step.

### Considered and deferred
- **Gemini Live API** (real-time speech-to-speech, native interruption/turn-taking handling) could eventually replace the STT→LLM→TTS pipeline below with one streaming session. Flagged as a **post-MVP exploration** — Bahasa Indonesia quality on Live API hasn't been verified, and it adds WebSocket/streaming complexity not needed for the group-project demo. The current spec (separate STT/LLM/TTS steps) is the near-term path.
- **Apple Foundation Models as primary brain** — ruled out because iOS 26/27 have no official Bahasa Indonesia support yet. Kept as the **offline fallback** instead; revisit as fine-tuning support matures.
- **Firebase AI Logic** (unified `LanguageModel` protocol) — requires iOS 27, which was still in developer beta as of writing (stable expected ~mid-September 2026). Too risky to depend on for a group project deadline. Revisit once iOS 27 ships stable.

## GeminiService — Single Model, Direct Call

`Services/LLM/GeminiService.swift` is a `nonisolated struct` that calls the Gemini REST API directly — no router, no quota tracking, no response cache.

### Model

`GeminiService.model` is `"gemini-3.1-flash-lite"` — the only place the model name appears in the codebase.

### Error handling and retry

`streamReply(systemInstruction:history:)` returns `AsyncThrowingStream<String, Error>`. The stream throws `GeminiError.rateLimited(retryAfter:)` on 429 and `GeminiError.requestFailed(Int)` on any other non-200 status.

`AIViewModel.streamAndSpeak()` adds one polite retry: if the stream throws `GeminiError.rateLimited` before any chunk has been yielded, it sleeps for `retryAfter` (default 2s if the header is absent, capped at 10s) and retries once. Any second failure, any other error, or any failure after chunks have started falls through to `onDeviceReply()`.

Free-tier quota state cannot be queried via API — the 429 response is the only ground truth, and the response to it is simply "go on-device." No in-app usage counters, cooldowns, or caches.

### Streaming

`streamReply` yields plain `String` chunks (SSE `data:` lines parsed, text fields extracted). `AIViewModel.streamAndSpeak()` accumulates chunks into a sentence buffer and flushes complete sentences to `SpeechOutput` as they arrive for near-real-time TTS.

## Language: Bahasa Indonesia In, Bahasa Indonesia Out

Both directions of the pipeline must be locked to Indonesian:

- **Understanding (STT):** the speech recognizer must be configured with an Indonesian locale (`id-ID`) so the driver's spoken Indonesian is transcribed correctly, not auto-detected or defaulted to English.
- **Replying (LLM):** enforced via the system persona below, which explicitly instructs replies in Bahasa Indonesia.
- **Speaking (TTS):** the synthesizer voice must also be set to `id-ID` so the companion's spoken output matches.

## System Persona

```
Kamu adalah sohib dekat yang lagi nemenin driver nyetir — santai, akrab, genuinely penasaran sama cerita dia. Ngobrolnya kayak teman lama, bukan asisten.

Gaya bahasa: sehari-hari, boleh pakai "eh", "btw", "nih", "kan", "wkwk" atau ekspresi ringan lainnya — wajar aja, jangan lebay. Jangan pakai emoji, simbol, tanda bintang, atau format apapun karena semua output kamu diucapkan langsung.

Cara ngobrol: nanggepin dulu apa yang driver bilang sebelum ganti topik, ajukan pertanyaan lanjutan yang relevan, variasikan cara kamu buka kalimat. Hindari sapaan yang sama terus atau pola yang terdengar template.

Konten: topik bebas — cuaca, olahraga, film/series, musik, teknologi, makanan, traveling, hewan, fakta unik, motivasi ringan, hobi, dan sejenisnya. Jangan ulangi topik yang sudah dibahas di percakapan ini.

Panjang: 1–3 kalimat, ringkas dan enak diucapkan. Tidak perlu bertele-tele.
```

Gemini is called with `temperature: 1.0` and `topP: 0.95` (`generationConfig` in the request body) to increase response variety and warmth beyond the conservative defaults.

The model decides *what* topic to bring up (and avoids repeats, using conversation history as context); the app decides *when* to prompt it. That split is what makes the two session modes below possible without changing the persona itself.

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

Rather than waiting for the full Gemini reply before speaking, `AIViewModel.streamAndSpeak()` reads chunks from `GeminiService.streamReply` and flushes complete sentences to `SpeechOutput` as they arrive:

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

**How coherence across topics works:** every exchange (driver utterance or companion-initiated line) is appended to a rolling conversation history and sent back to Gemini as multi-turn context on the next call. That's why topics can drift — "cuaca" → "musik" → "rencana weekend" — while still reading as one continuous conversation instead of disconnected one-shot prompts.

**How a companion-initiated turn works:** there's no real driver utterance to send, so the proactive trigger sends a short internal cue instead (one of several randomly chosen variants encouraging a natural, non-template opening) — and only the model's spoken reply is what the driver hears. The cue is stored in history purely to keep the API's turn order valid and to help the model track what it already opened with; it is never spoken or shown.

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
- **Stop:** cancels the proactive timer, stops `SpeechInput` and `SpeechOutput`, clears conversation history, resets `activeModel`, deactivates `AVAudioSession`, and returns to `status = .idle`. A subsequent Start begins completely fresh with no memory of the previous session.

Conversation history is capped to a rolling window of **20 turns** (`historyLimit`) to keep API payload and free-tier token usage in check on long sessions — the driver experiences this as "the companion remembers the whole trip," even though very old turns eventually roll off.

## Files

| File | Responsibility |
|---|---|
| `Services/LLM/GeminiService.swift` | Direct REST client to the Gemini Developer API. `streamGenerateContent` (SSE), single hardcoded model (`gemini-3.1-flash-lite`). Reads API key from `Info.plist`. Parses `429` → `GeminiError.rateLimited` with optional `Retry-After`. |
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

**In-app:** `activeModel` (published on `AIViewModel`) shows `gemini-3.1-flash-lite` during Gemini replies and `Foundation Models (on-device)` when the fallback fires. This is the only in-app observability — no usage counters or quota logging by design.

## Roadmap / Open Items

- Sync the companion's 3D model animation state (idle/talking/listening) with `CompanionStatus` — the enum already tracks the four states needed.
- Re-evaluate Firebase AI Logic once iOS 27 is stable.
- Explore Gemini Live API for true speech-to-speech, replacing the separate STT/LLM/TTS steps with one streaming session, once Bahasa Indonesia quality is verified.
- Replace the fixed-interval proactive timers (Mode 1 & 3) with state-aware production triggers — trip duration, silence length, drowsiness precursor signals.
