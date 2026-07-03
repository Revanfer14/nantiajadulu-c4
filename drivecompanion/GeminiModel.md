# GeminiModel.md

Documentation for Jaga's **AI companion layer** — the voice-driven "teman menyetir" (driving buddy) that listens, chats naturally, checks in proactively, and replies aloud. This is separate from the perception engine (CoreML/ARKit); see `CLAUDE.md` for overall project context.

This file is the spec for the companion layer — hand this directly to Claude Code (or any implementer) to generate the actual Swift files.

## Purpose

The companion is a presence, not a dashboard: casual spoken conversation, occasional check-ins, warm tone. **There is no chat UI.** Input comes from the driver's voice (microphone → speech-to-text), output is spoken aloud (text-to-speech). The only manual UI control is Start/Stop.

## Architecture — Three-Path Routing

```
Driver speech (mic) ──▶ Speech-to-text (id-ID)
      │
      ▼
Safety alert?  ──yes──▶ Scripted response (deterministic, Bahasa Indonesia)
      │no
      ▼
   Online?    ──yes──▶ Gemini Flash (cloud, primary)
      │no                    │ (on failure)
      ▼                      ▼
Foundation Models (on-device, offline) ──▶ static fallback line (if this also fails)
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

**Decision: `gemini-3.5-flash` (or latest GA Flash release at build time) is the primary companion model.**

### Considered and deferred
- **Gemini Live API** (real-time speech-to-speech, native interruption/turn-taking handling) could eventually replace the STT→LLM→TTS pipeline below with one streaming session. Flagged as a **post-MVP exploration** — Bahasa Indonesia quality on Live API hasn't been verified, and it adds WebSocket/streaming complexity not needed for the group-project demo. The current spec (separate STT/LLM/TTS steps) is the near-term path.
- **Apple Foundation Models as primary brain** — ruled out because iOS 26/27 have no official Bahasa Indonesia support yet. Kept as the **offline fallback** instead; revisit as fine-tuning support matures.
- **Firebase AI Logic** (unified `LanguageModel` protocol) — requires iOS 27, which was still in developer beta as of writing (stable expected ~mid-September 2026). Too risky to depend on for a group project deadline. Revisit once iOS 27 ships stable.

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

**Continuous listening design:**
- Recognizer locale: `Locale(identifier: "id-ID")`.
- While a session is active, the mic stays open and recognition runs continuously rather than one-shot per tap.
- Use a short silence timeout (reset on every partial result, fire after ~1.5s of no new partial) to detect "the driver finished a sentence" and submit that utterance to the AI — `SFSpeechRecognizer` doesn't reliably mark `isFinal` on open-ended continuous audio.
- **Mute recognition while the companion is speaking**, so the mic doesn't pick up and transcribe Jaga's own TTS output as if it were the driver talking. Resume listening once `AVSpeechSynthesizerDelegate` reports playback finished.
- Configure `AVAudioSession` with a `.playAndRecord` category so recording and TTS playback can coexist within the same session (with the mute-during-TTS logic above still handling self-capture).

## Session Modes

The companion's proactive-timer behavior is controlled by a mode, chosen before Start is pressed (mode selection is locked once a session is running so each session is consistent). Persona and topic pool stay identical across modes — only the initiation cadence changes. Driver-initiated speech (via mic) is always recognized and answered in every mode, regardless of the timer.

| Mode | Behavior | Trigger |
|---|---|---|
| `continuousProactive` | Companion keeps opening new topics back-to-back, staying coherent via conversation history. | Timer, ~15–30s (randomized), re-armed after every reply |
| `driverInitiated` | Companion never speaks first — pure reactive chat. | None — only responds when the driver's speech is transcribed |
| `occasionalProactive` | Companion checks in now and then, sparser than continuous. | Timer, ~60–120s (randomized), re-armed after every reply |

**How coherence across topics works:** every exchange (driver utterance or companion-initiated line) is appended to a rolling conversation history and sent back to Gemini as multi-turn context on the next call. That's why topics can drift — "cuaca" → "musik" → "rencana weekend" — while still reading as one continuous conversation instead of disconnected one-shot prompts.

**How a companion-initiated turn works:** there's no real driver utterance to send, so the proactive trigger sends a short internal cue instead — `"(Waktunya kamu yang mulai ngobrol duluan. Pilih topik baru, jangan ulangi topik sebelumnya.)"` — and only the model's spoken reply is what the driver hears. The cue is stored in history purely to keep the API's turn order valid and to help the model track what it already opened with; it is never spoken or shown.

**These intervals are tuned for iteration/demo, not final production behavior.** Production triggers should eventually be state-aware — trip duration, silence length, drowsiness precursor signals — per the six DURING-phase innovation principles in `CLAUDE.md` (anti-habituation by design, sleep-inertia-aware activation, etc.) rather than fixed timers.

## Session Lifecycle (Start / Stop)

One button, two states — this is the only manual control in the UI.

- **Start:** requests mic/speech permissions if not already granted, begins a fresh session (empty conversation history), arms the proactive timer per the selected mode, and starts continuous listening.
- **While running:** the companion retains full conversation context for the entire session — every driver utterance and every companion reply, proactive or reactive, accumulates into the same history and informs every subsequent reply. Nothing is cleared mid-session.
- **Stop:** stops listening, cancels the proactive timer, and resets the session — conversation history and any in-progress recognition/synthesis are cleared. A subsequent Start begins completely fresh, with no memory of the previous session.

Conversation history should still be capped to a reasonable rolling window (e.g. last ~20 turns) to keep API payload and free-tier token usage in check on long sessions — the driver experiences this as "the companion remembers the whole trip," even though very old turns eventually roll off.

## Code Style Requirements

- Clean, structured Swift, following standard Swift API design conventions.
- **No comments of any kind** — no inline comments, no doc comments, no `// MARK: -` section dividers. The only exception is the header block Xcode auto-generates when you create a new file (the `//  FileName.swift` / `//  Jaga` / `//  Created by ... on ...` block) — leave that as-is, don't add anything beyond it.
- Applies to every file in this layer: `GeminiService.swift`, `SpeechOutput.swift`, `AIViewModel.swift`, `AIGeminiView.swift`.

## Files

| File | Responsibility |
|---|---|
| `GeminiService.swift` | Direct REST client to the Gemini Developer API (`generateContent` endpoint). Reads the API key from `Info.plist`. Supports multi-turn history for conversational context. |
| `SpeechOutput.swift` | `AVSpeechSynthesizer` wrapper, `id-ID` voice, speaks the final reply aloud; reports playback completion so listening can resume. |
| `AIViewModel.swift` | Core companion logic: mic capture + STT (`id-ID`), hybrid routing (Gemini online → Foundation Models offline → static fallback), rolling conversation history, session mode/timer logic, Start/Stop session lifecycle. |
| `AIGeminiView.swift` | Minimal SwiftUI screen: mode selector + Start/Stop button. No chat UI, no transcript, no text input — the microphone is the only input. |
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

## Roadmap / Open Items

- Sync the companion's 3D model animation state (idle/talking/listening) with speech input/output timing.
- Re-evaluate Firebase AI Logic once iOS 27 is stable.
- Explore Gemini Live API for true speech-to-speech, replacing the separate STT/LLM/TTS steps with one streaming session, once Bahasa Indonesia quality is verified.
- Replace the fixed-interval proactive timers (Mode 1 & 3) with state-aware production triggers — trip duration, silence length, drowsiness precursor signals.
