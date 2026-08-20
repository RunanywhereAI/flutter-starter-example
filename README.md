# RunAnywhere AI for Flutter

<p align="center">
  <img src="https://raw.githubusercontent.com/RunanywhereAI/runanywhere-sdks/main/docs/logo.svg" alt="RunAnywhere" width="120"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.44%2B-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter 3.44+" />
  <img src="https://img.shields.io/badge/Dart-3.12%2B-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart 3.12+" />
  <img src="https://img.shields.io/badge/iOS-17.5%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="iOS 17.5+" />
  <img src="https://img.shields.io/badge/Android-API%2024%2B-3DDC84?style=flat-square&logo=android&logoColor=white" alt="Android API 24+" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="MIT" />
</p>

A starter app for the [RunAnywhere SDK](https://pub.dev/packages/runanywhere), written in
Dart.

The home screen is a grid of eight cards, one per feature. Each screen downloads and loads
its own model the first time you open it, then runs it on the device. Copy a screen, point
it at your own model, and you have the shape of a real app.

## What each screen does

| Card | SDK surface it calls | Model |
|---|---|---|
| Chat (text generation) | `RunAnywhere.llm.generateStream`, `llm.cancel` | Qwen3.5 0.8B |
| Vision (image understanding) | `RunAnywhere.vlm.generateStream` with `ImageInput.file` | SmolVLM 500M |
| Speech (speech to text) | `RunAnywhere.stt.transcribe` with `AudioInput.pcm16` | Whisper Tiny EN |
| Voice (text to speech) | `RunAnywhere.tts.speak`, `tts.playbackState`, `tts.stop` | Piper en_US lessac medium |
| Activity (voice detection) | `RunAnywhere.vad.openStream` plus the SDK's `AudioCaptureManager` | Silero VAD |
| Pipeline (voice agent) | `RunAnywhere.voice.createSession(stt:, llm:, tts:)` | Whisper Tiny + Qwen3.5 0.8B + Piper |
| Knowledge (RAG) | `RunAnywhere.rag.open`, `session.ingest`, `session.query` | all-MiniLM-L6-v2 + Qwen3.5 0.8B |
| Tools (function calling) | `RunAnywhere.llm.tools.register`, `llm.generate` with `autoExecute: true` | Qwen3.5 0.8B |

Some behavior the table does not capture:

- Chat sends only the latest message. There is no conversation history or system prompt in the request, so the model is stateless across turns even though the UI looks like a thread.
- Speech is batch transcription. The app records with `package:record` into a PCM16 buffer and transcribes once on stop. There is no partial or streaming transcript.
- Pipeline hands the whole loop to the SDK. `VoiceSession` owns mic capture, turn segmentation, and TTS playback; the app only renders `VoiceAgentStateChanged`, `VoiceUserTranscribed`, and `VoiceAgentResponse` events.
- Knowledge ingests pasted text only. There is no file or PDF picker, and answers are shown without source citations.
- Tools registers three functions: `get_weather`, `get_current_time`, and `calculate`. The SDK runs the tool loop and the app supplies the executors.

## Requirements

- Flutter 3.44.0 or newer, Dart 3.12.0 or newer
- iOS 17.5+ (the SDK podspecs set that deployment target and the Podfile pins it)
- Android API 24+; the SDK's Android modules compile against SDK 36 and NDK 28.2.13676358
- Xcode for iOS, Android Studio or the command-line SDK for Android

The Apple MLX backend needs a physical iOS device; `MLX.register()` returns false on the simulator. The Qualcomm Hexagon backend needs an arm64 Snapdragon device; the app checks `QHexRT.isAvailable` before registering it. Both are skipped cleanly elsewhere, so a plain simulator run works and falls back to llama.cpp and ONNX.

## Running it

```bash
git clone https://github.com/RunanywhereAI/flutter-starter-example.git
cd flutter-starter-example
flutter pub get
flutter run
```

Microphone, camera, and photo library permissions are already declared in `ios/Runner/Info.plist` and `android/app/src/main/AndroidManifest.xml`. The Podfile already sets `use_frameworks! :linkage => :static`, which the SDK requires on iOS; without it the vendored xcframework symbols fail to link.

No API key or account is needed. `RunAnywhere.initialize()` is called with no arguments.

Models are not bundled. The first time you open a feature screen you get a download button, and the download runs over the network into local storage. Budget roughly 1.2 GB if you try every screen.

## How the SDK is wired up

`lib/main.dart` does the setup in order: initialize the SDK, register the backends, register the model catalog, then start the app.

```dart
await RunAnywhere.initialize();

LlamaCpp.register();
await Onnx.register();
await MLX.register();
if (QHexRT.isAvailable) {
  await QHexRT.register();
}

await ModelService.registerDefaultModels();
```

`ModelService` (a `ChangeNotifier` behind `provider`) owns the catalog and the download and load state. It registers models with `RunAnywhere.models.register` using three registration shapes:

- `ModelRegistration.url` for single files (Qwen3.5, Silero VAD)
- `ModelRegistration.archive` for tarballs (SmolVLM, Whisper, Piper)
- `ModelRegistration.multiFile` for models that need companion files (LFM2.5-VL weights plus its mmproj projector, MiniLM model plus vocab)

Loaded-model state is mirrored into a synchronous `Set<ModelCategory>` because `RunAnywhere.models.state()` is async and widget `build()` needs an answer immediately. `refreshLoadedModels()` re-syncs it after every load or unload.

## Project layout

```
lib/
  main.dart                     SDK init, backend registration, app root
  services/model_service.dart   Model catalog, download and load state
  theme/app_theme.dart          AppColors palette and AppTheme.darkTheme
  views/
    home_view.dart              Feature grid
    chat_view.dart              LLM streaming chat
    vision_view.dart            Image understanding (VLM)
    speech_to_text_view.dart    Recording and transcription
    text_to_speech_view.dart    Synthesis and playback
    vad_view.dart               Live speech detection
    voice_pipeline_view.dart    Voice agent session
    knowledge_view.dart         RAG over pasted text
    tool_calling_view.dart      Function calling
  widgets/
    feature_card.dart           Home grid tile
    model_loader_widget.dart    Download and load gate screen
    chat_message_bubble.dart    Message bubble with token metrics
    audio_visualizer.dart       Audio level bars
```

The app is dark theme only. `AppTheme.darkTheme` is Material 3 with Inter for body text and Space Grotesk for headings, both via `google_fonts`.

## SDK packages

Pinned at `^0.20.19`, which is the latest version of all five on pub.dev.

| Package | Role |
|---|---|
| `runanywhere` | Core SDK: model management, inference APIs, FFI bridge to the C++ core |
| `runanywhere_llamacpp` | llama.cpp backend for LLM and VLM |
| `runanywhere_onnx` | Sherpa and ONNX backend for STT, TTS, VAD, and embeddings |
| `runanywhere_mlx` | Apple MLX backend, physical iOS devices only |
| `runanywhere_qhexrt` | Qualcomm Hexagon NPU backend, Android arm64 only |

## Models

Registered in `ModelService.registerDefaultModels()`. Sizes are the `memoryRequirementBytes` each model declares.

Every loader screen names the model it is about to fetch and who published it, so nothing
downloads without saying what it is.

| Model | Category | Size |
|---|---|---|
| Qwen3.5 0.8B Q4_K_M | Language | 533 MB |
| SmolVLM 500M Instruct | Multimodal | 600 MB |
| LFM2.5-VL 3B (Q4_K_M + mmproj) | Multimodal | 2.26 GB |
| Sherpa Whisper Tiny EN | Speech recognition | 75 MB |
| Piper TTS en_US lessac medium | Speech synthesis | 65 MB |
| Silero VAD | Voice activity | 2.3 MB |
| all-MiniLM-L6-v2 | Embedding | 25.5 MB |

LFM2.5-VL is registered but no screen selects it. `downloadAndLoadVLM` takes a `modelId` that defaults to SmolVLM; pass `ModelService.vlmLfm25ModelId` to route the Vision screen through the larger model instead.

## Adding your own model

Register it alongside the defaults in `lib/services/model_service.dart`. Registration is idempotent, so re-running it is safe.

```dart
await RunAnywhere.models.register(
  ModelRegistration.url(
    id: 'qwen2.5-1.5b-instruct-q4_k_m',
    name: 'Qwen2.5 1.5B Instruct',
    url: 'https://huggingface.co/.../qwen2.5-1.5b-instruct-q4_k_m.gguf',
    framework: InferenceFramework.INFERENCE_FRAMEWORK_LLAMA_CPP,
    category: ModelCategory.MODEL_CATEGORY_LANGUAGE,
    memoryRequirementBytes: 1100000000,
  ),
);
```

Then point a screen at the new id, either by changing the matching `static const String` at the top of `ModelService` or by passing the id through the download and load method.

## Privacy

Inference runs on device. Prompts, audio, and images are not sent anywhere. Two things do use the network: model downloads, and the `get_weather` tool on the Tools screen, which calls the public Open-Meteo API with the location string the model extracted from your prompt.

## The other apps

| Platform | Repo |
| --- | --- |
| React Native | [react-native-starter-app](https://github.com/RunanywhereAI/react-native-starter-app) |
| iOS and macOS | [runanywhere-ios](https://github.com/RunanywhereAI/runanywhere-ios) |
| Android | [runanywhere-android](https://github.com/RunanywhereAI/runanywhere-android) |
| Web | [runanywhere-web](https://github.com/RunanywhereAI/runanywhere-web) |
| Windows | [runanywhere-electron](https://github.com/RunanywhereAI/runanywhere-electron) |
| SDK monorepo | [runanywhere-sdks](https://github.com/RunanywhereAI/runanywhere-sdks) |
| Documentation | [docs.runanywhere.ai](https://docs.runanywhere.ai) |
| Discord | [discord.gg/N359FBbDVd](https://discord.gg/N359FBbDVd) |

## License

The starter app is MIT licensed (see `LICENSE`). The RunAnywhere SDK ships under its own license, included with each package on pub.dev.

Bug reports: [github.com/RunanywhereAI/runanywhere-sdks/issues](https://github.com/RunanywhereAI/runanywhere-sdks/issues)
