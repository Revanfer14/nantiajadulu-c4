# CLAUDE.md

Master context file for **Jaga** (Xcode project/bundle name: `drivecompanion`) — an iOS driving-companion app that keeps drivers alert on the road. This file is the entry point for understanding the whole codebase; hand it to Claude Code (or any implementer) alongside the feature-specific specs listed under [Related Documentation](#related-documentation).

Bundle ID: `com.nantiajadulu.drivecompanion` · iOS deployment target: 26.0+ · Xcode 26.6 · Swift 5, SwiftUI.

## What This App Is

Jaga is built as a **university/course group project**. It has two independent core features living side by side in the same app, connected only by a bottom tab switcher in `drivecompanionApp.swift`:

1. **AI Companion** ("teman menyetir") — a fully voice-driven conversational presence that chats with the driver, checks in proactively, and keeps them company. Screen: `AIGeminiView.swift`.
2. **Detection** — camera-based drowsiness/microsleep detection using ARKit face tracking, triggering an audible alarm when precursor signals cross thresholds. Screen: `DetectionView.swift`.

## Product Philosophy

This governs every design decision in the app and should not be re-litigated without explicit reason:

- **Non-judgmental companion, not a monitoring/gating system.** Jaga is a driving buddy, not a supervisor. There is no "fit-to-drive" gate that blocks or scores the driver — that idea was explicitly considered and ruled out.
- **Predicts rather than reacts.** A 1–2 second microsleep at driving speed can't be "won" reactively once it starts. Detection is built around precursor signals (PERCLOS trend, blink duration, head drift) rather than waiting for the microsleep event itself — see `DrowsinessDetector.swift`.
- **Six DURING-phase innovation principles** (design targets, not all fully implemented yet — see [Known Gaps](#known-gaps--open-items)):
  1. Closed-loop arousal with self-measured recovery
  2. Sleep-inertia-aware activation
  3. Anti-habituation by design
  4. Intervention intensity scaled to kinetic danger, not just drowsiness score
  5. Breaking the drowsiness oscillation wave-train early
  6. Graceful handoff from "keep awake" to "stop safely" when interventions fail
- **Safety-critical alerts are never routed through an LLM.** Drowsiness/microsleep alarms are fully deterministic (`AlarmService.swift`, triggered directly by `DrowsinessDetector` state). This keeps the safety path independent of connectivity, model quality, or LLM failure modes — non-negotiable.
- **Localization:** all user-facing strings are **Bahasa Indonesia** (`id-ID` locale, both STT and TTS). Code identifiers, docs, and comments-that-would-otherwise-exist stay in English.

## Feature 1 — AI Companion

Full spec lives in `GeminiModel.md` — read that for system persona, session modes, permission flow, and setup steps. Summary of the architecture actually in the codebase:

```
Driver speech (mic, id-ID) ──▶ SpeechInput (SFSpeechRecognizer, silence-timeout utterance detection)
      │
      ▼
   Online?  ──yes──▶ GeminiService (REST, streamGenerateContent, gemini-3.1-flash-lite)
      │no                  │ any error (one retry on pre-chunk 429)
      ▼                    ▼
FoundationModels (on-device, LanguageModelSession) ──▶ static fallback line
      │
      ▼
SpeechOutput (AVSpeechSynthesizer, id-ID voice, sentence-by-sentence streaming)
```

Key files: `AIViewmodel.swift` (orchestration, session modes, proactive timer, `NWPathMonitor` for online/offline), `GeminiService.swift` (REST client, single hardcoded model), `SpeechInput.swift` / `SpeechOutput.swift`, `AIGeminiView.swift` (mode picker + Start/Stop, no chat UI).

### Single model

`GeminiService.model` (hardcoded constant in `GeminiService.swift`) is `gemini-3.1-flash-lite` — the only place the model name appears in the codebase. It was chosen for its 500 RPD / 15 RPM free-tier headroom. Any Gemini failure (429, 5xx, network, parse error) falls back to on-device FoundationModels. There is no quota tracking, no cooldown, and no response cache — free-tier quota state can't be queried via API; the 429 response is the only ground truth, and the response to it is to go on-device. One polite retry (sleeping `Retry-After`, defaulting to 2s, capped at 10s) fires on a pre-chunk 429 before falling back, to avoid a jarring quality cliff from a single per-minute rate-limit blip.

## Feature 2 — Detection

Uses ARKit's TrueDepth face tracking to watch for drowsiness precursors and fires a deterministic audible alarm. No LLM involvement anywhere in this path.

```
ARFaceTrackingConfiguration (TrueDepth camera)
      │  blendShapes: eyeBlinkLeft/Right, jawOpen, face transform → pitch
      ▼
FaceTrackingService ──▶ CameraViewModel ──▶ DrowsinessDetector.update()
                                                   │
                                                   ▼
                                          DrowsinessState (alert / drowsy / microsleep / noFace)
                                                   │
                                                   ▼
                                             AlarmService (looping .wav, .duckOthers overrides silent mode)
```

`DrowsinessDetector.swift` tracks four independent signals and combines them into a state machine each frame:

| Signal | Mechanism | Threshold | Effect |
|---|---|---|---|
| PERCLOS | Rolling 30s window of eye-openness samples; % of samples below 0.75 counts as "closed" | > 0.15 fraction closed, and driver not currently in a 3s+ "alert" streak | → `drowsy` |
| CLOSDUR (microsleep) | Continuous duration eye-openness stays below 0.4 | ≥ 2.0s | → `microsleep` (highest priority state) |
| Head drop | Continuous duration face pitch exceeds 0.2 rad | ≥ 1.0s, combined with PERCLOS > half the fading threshold | → `drowsy` |
| Yawn | Continuous duration jaw-open blend shape ≥ 0.8 | ≥ 3.0s | → `drowsy` regardless of PERCLOS |

Recovery: once the driver's eyes stay open ≥3.0s (`alert` streak) while previously `drowsy`, the PERCLOS history is reseeded so the alarm doesn't linger on stale samples. Losing face tracking entirely resets the detector and stops any alarm (`noFace` state).

Key files: `FaceTrackingService.swift` (ARSession + blend-shape extraction), `DrowsinessDetector.swift` (state machine), `AlarmService.swift` (`AVAudioPlayer` looping `drowsy_alert`/`microsleep_alert`), `CameraViewModel.swift` (orchestration, publishes `@Published` state to the view), `CameraPreview.swift` (`ARSCNView` wrapper rendering the face-mesh wireframe), `DetectionView.swift` (camera preview + debug numeric overlay + state banner).

## Folder Structure

```
drivecompanion/
├── drivecompanionApp.swift        # App entry — bottom tab switcher (AI Gemini / Detection), no TabView, custom buttons
├── ContentView.swift               # Unused Xcode template stub — see Known Gaps
├── Info.plist                      # GEMINI_API_KEY placeholder, mic/speech usage strings
├── GeminiModel.md                  # Full spec for the AI Companion layer
├── Components/
│   └── CameraPreview.swift         # ARSCNView wrapper, face mesh wireframe overlay
├── Models/
│   └── DrowsinessState.swift       # alert / drowsy / microsleep / noFace
├── Services/
│   ├── DrowsinessDetection/
│   │   ├── FaceTrackingService.swift
│   │   ├── DrowsinessDetector.swift
│   │   └── AlarmService.swift
│   ├── LLM/
│   │   └── GeminiService.swift     # REST client (streamGenerateContent), single hardcoded model
│   └── Speech/
│       ├── SpeechInput.swift       # SFSpeechRecognizer, continuous listening, silence timeout
│       └── SpeechOutput.swift      # AVSpeechSynthesizer wrapper, id-ID voice
├── ViewModels/
│   ├── CameraViewModel.swift
│   └── AIViewmodel.swift
└── Views/
    ├── DetectionView.swift
    └── AIGeminiView.swift

drivecompanion.xcodeproj/           # Uses PBXFileSystemSynchronizedRootGroup — files dropped into
                                     # drivecompanion/ are picked up automatically, no manual
                                     # "add to target" step needed
Secrets.xcconfig                    # GEMINI_API_KEY — gitignored, never commit
.gitignore
```

## Tech Stack

- **Swift 5 / SwiftUI**, iOS 26.0+ deployment target. Companion-layer files are gated `@available(iOS 26.0, *)` because of the `FoundationModels` dependency.
- **ARKit + SceneKit** — `ARFaceTrackingConfiguration`, requires TrueDepth camera hardware.
- **Speech** — `SFSpeechRecognizer`, locale `id-ID`.
- **AVFoundation** — `AVSpeechSynthesizer` (TTS), `AVAudioPlayer` (alarms), `AVAudioSession` (`.playAndRecord` for companion, `.playback` + `.duckOthers` for alarms).
- **FoundationModels** — on-device LLM, fallback when Gemini is offline or fails (`LanguageModelSession`).
- **Network** — `NWPathMonitor` for online/offline routing.
- Gemini access is **direct `URLSession` REST calls**, not the Firebase SDK — deferred until iOS 27 is stable (~September 2026), see `GeminiModel.md`.

## Code Style Requirements

**This applies repo-wide, to every file in the project, not just the AI/LLM layer:**

- Clean, structured Swift following standard Swift API design conventions.
- **No comments of any kind** — no inline `//` explanations, no doc comments (`///`), no `// MARK: -` section dividers, nothing.
- The **only** exception is the header block Xcode auto-generates when creating a new file (the `//  FileName.swift` / `//  drivecompanion` / `//  Created by ... on ...` block). Leave that exactly as generated — don't add to it, don't strip it.

## Configuration & Secrets

- `GEMINI_API_KEY` lives in `Secrets.xcconfig` at the project root (gitignored) and is surfaced into `Info.plist` via `$(GEMINI_API_KEY)`, read at runtime through `Bundle.main.object(forInfoDictionaryKey:)`.
- **Known incident:** `Secrets.xcconfig` was committed before `.gitignore` covered it. Because `.gitignore` isn't retroactive, the fix was `git rm --cached Secrets.xcconfig` + commit, and the exposed key was treated as compromised and regenerated in Google AI Studio rather than scrubbing history. Any key that touches a commit — pushed or not — gets treated as burned. Always verify `Secrets.xcconfig` is gitignored *before* it's created/staged.
- Free-tier only, everywhere: Google AI Studio API key with billing disabled, no paid dashboards. Quota is monitored manually at `aistudio.google.com/usage`.

## Known Gaps / Open Items

Things noticed while reading the current code that are worth flagging, not necessarily blockers:

- **`ContentView.swift`** is the unmodified Xcode "Hello, world!" template and isn't referenced by `drivecompanionApp.swift` — looks safe to delete.
- **Companion and Detection are fully siloed.** `AIViewModel` has no awareness of `DrowsinessState`, so the companion can't yet lean into its stated role of scaling intervention to drowsiness/kinetic danger (innovation principle #4) — right now that logic only lives in `AlarmService`'s binary alarm, with no shared state between the two features.
- **Head-motion signal source:** the current head-pitch signal comes from the ARKit face anchor transform (TrueDepth camera, `FaceTrackingService.swift`), not `CMHeadphoneMotionManager`/AirPods. If AirPods-based head motion is still the intended primary signal, that integration hasn't landed in this codebase yet — Apple Watch as a secondary confirmation layer is likewise not present.
- **`DetectionView.swift`** is a debug view (raw numeric overlay of openness/jaw/pitch/PERCLOS/closed-duration) rather than a production UI.
- No persistence of detection events or session history yet for either feature.
- Alarm `.wav` assets (`drowsy_alert`, `microsleep_alert`) must exist in the app bundle for `AlarmService` to do anything — worth double-checking they're actually added as bundle resources, not just referenced by name.
- Nav title in `AIGeminiView` currently reads `"C4"` — likely a placeholder/course-code artifact, flag before any demo/submission.

## Related Documentation

- **`GeminiModel.md`** — full spec for the AI Companion layer: system persona, session modes, voice I/O permission flow, setup steps, secret hygiene, and roadmap. Read this before touching anything under `Services/LLM/`, `Services/Speech/`, `AIViewmodel.swift`, or `AIGeminiView.swift`.
