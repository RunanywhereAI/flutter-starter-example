import 'package:flutter/foundation.dart';
import 'package:runanywhere/runanywhere.dart';

/// Service for managing AI models
class ModelService extends ChangeNotifier {
  // Model IDs - using officially supported models from RunanywhereAI/sherpa-onnx
  static const String llmModelId = 'smollm2-360m-instruct-q8_0';
  static const String sttModelId = 'sherpa-onnx-whisper-tiny.en';
  static const String ttsModelId = 'vits-piper-en_US-lessac-medium';

  // Download state
  bool _isLLMDownloading = false;
  bool _isSTTDownloading = false;
  bool _isTTSDownloading = false;

  double _llmDownloadProgress = 0.0;
  double _sttDownloadProgress = 0.0;
  double _ttsDownloadProgress = 0.0;

  // Load state
  bool _isLLMLoading = false;
  bool _isSTTLoading = false;
  bool _isTTSLoading = false;

  // Getters
  bool get isLLMDownloading => _isLLMDownloading;
  bool get isSTTDownloading => _isSTTDownloading;
  bool get isTTSDownloading => _isTTSDownloading;

  double get llmDownloadProgress => _llmDownloadProgress;
  double get sttDownloadProgress => _sttDownloadProgress;
  double get ttsDownloadProgress => _ttsDownloadProgress;

  bool get isLLMLoading => _isLLMLoading;
  bool get isSTTLoading => _isSTTLoading;
  bool get isTTSLoading => _isTTSLoading;

  bool get isLLMLoaded => RunAnywhere.llm.isLoaded;
  bool get isSTTLoaded => RunAnywhere.stt.isLoaded;
  bool get isTTSLoaded => RunAnywhere.tts.isLoaded;

  bool get isVoiceAgentReady => RunAnywhere.voice.isReady;

  /// Register default models with the SDK
  /// Using officially supported models from RunanywhereAI/sherpa-onnx for compatibility
  static Future<void> registerDefaultModels() async {
    // LLM Model - SmolLM2 360M (small, fast, good for demos)
    try {
      await RunAnywhere.models.register(
        id: llmModelId,
        name: 'SmolLM2 360M Instruct Q8_0',
        url:
            'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q8_0.gguf',
        framework: InferenceFramework.INFERENCE_FRAMEWORK_LLAMA_CPP,
        memoryRequirement: 400000000, // ~400MB
      );
    } catch (e) {
      debugPrint('Failed to register LLM model: $e');
    }

    // STT Model - Whisper Tiny English (fast transcription)
    // Using tar.gz format from RunanywhereAI for fast native extraction
    try {
      await RunAnywhere.models.registerArchiveModel(
        id: sttModelId,
        name: 'Sherpa Whisper Tiny (ONNX)',
        archiveUrl:
            'https://github.com/RunanywhereAI/sherpa-onnx/releases/download/runanywhere-models-v1/sherpa-onnx-whisper-tiny.en.tar.gz',
        archiveType: ArchiveType.ARCHIVE_TYPE_TAR_GZ,
        structure: ArchiveStructure.ARCHIVE_STRUCTURE_NESTED_DIRECTORY,
        framework: InferenceFramework.INFERENCE_FRAMEWORK_SHERPA,
        modality: ModelCategory.MODEL_CATEGORY_SPEECH_RECOGNITION,
        memoryRequirement: 75000000,
      );
    } catch (e) {
      debugPrint('Failed to register STT model: $e');
    }

    // TTS Model - Piper TTS (US English - Medium quality)
    // Using officially supported Piper model for reliable TTS
    try {
      await RunAnywhere.models.registerArchiveModel(
        id: ttsModelId,
        name: 'Piper TTS (US English - Medium)',
        archiveUrl:
            'https://github.com/RunanywhereAI/sherpa-onnx/releases/download/runanywhere-models-v1/vits-piper-en_US-lessac-medium.tar.gz',
        archiveType: ArchiveType.ARCHIVE_TYPE_TAR_GZ,
        structure: ArchiveStructure.ARCHIVE_STRUCTURE_NESTED_DIRECTORY,
        framework: InferenceFramework.INFERENCE_FRAMEWORK_SHERPA,
        modality: ModelCategory.MODEL_CATEGORY_SPEECH_SYNTHESIS,
        memoryRequirement: 65000000,
      );
    } catch (e) {
      debugPrint('Failed to register TTS model: $e');
    }
  }

  /// Check if a model is downloaded
  Future<bool> isModelDownloaded(String modelId) async {
    final models = await RunAnywhere.models.available();
    for (final model in models) {
      if (model.id == modelId) {
        return model.localPath.isNotEmpty;
      }
    }
    return false;
  }

  /// Download and load LLM model
  Future<void> downloadAndLoadLLM() async {
    if (_isLLMDownloading || _isLLMLoading) return;

    final isDownloaded = await isModelDownloaded(llmModelId);

    if (!isDownloaded) {
      _isLLMDownloading = true;
      _llmDownloadProgress = 0.0;
      notifyListeners();

      try {
        await RunAnywhere.downloadModel(
          llmModelId,
          onProgress: (progress) async {
            _llmDownloadProgress = progress.stageProgress;
            notifyListeners();
          },
        );
      } catch (e) {
        debugPrint('LLM download error: $e');
      }

      _isLLMDownloading = false;
      notifyListeners();
    }

    // Load the model
    _isLLMLoading = true;
    notifyListeners();

    try {
      await RunAnywhere.llm.load(llmModelId);
    } catch (e) {
      debugPrint('LLM load error: $e');
    }

    _isLLMLoading = false;
    notifyListeners();
  }

  /// Download and load STT model
  Future<void> downloadAndLoadSTT() async {
    if (_isSTTDownloading || _isSTTLoading) return;

    final isDownloaded = await isModelDownloaded(sttModelId);

    if (!isDownloaded) {
      _isSTTDownloading = true;
      _sttDownloadProgress = 0.0;
      notifyListeners();

      try {
        await RunAnywhere.downloadModel(
          sttModelId,
          onProgress: (progress) async {
            _sttDownloadProgress = progress.stageProgress;
            notifyListeners();
          },
        );
      } catch (e) {
        debugPrint('STT download error: $e');
      }

      _isSTTDownloading = false;
      notifyListeners();
    }

    // Load the model
    _isSTTLoading = true;
    notifyListeners();

    try {
      await RunAnywhere.stt.load(sttModelId);
    } catch (e) {
      debugPrint('STT load error: $e');
    }

    _isSTTLoading = false;
    notifyListeners();
  }

  /// Download and load TTS model
  Future<void> downloadAndLoadTTS() async {
    if (_isTTSDownloading || _isTTSLoading) return;

    final isDownloaded = await isModelDownloaded(ttsModelId);

    if (!isDownloaded) {
      _isTTSDownloading = true;
      _ttsDownloadProgress = 0.0;
      notifyListeners();

      try {
        await RunAnywhere.downloadModel(
          ttsModelId,
          onProgress: (progress) async {
            _ttsDownloadProgress = progress.stageProgress;
            notifyListeners();
          },
        );
      } catch (e) {
        debugPrint('TTS download error: $e');
      }

      _isTTSDownloading = false;
      notifyListeners();
    }

    // Load the model
    _isTTSLoading = true;
    notifyListeners();

    try {
      await RunAnywhere.tts.loadVoice(ttsModelId);
    } catch (e) {
      debugPrint('TTS load error: $e');
    }

    _isTTSLoading = false;
    notifyListeners();
  }

  /// Download and load all models for voice agent
  Future<void> downloadAndLoadAllModels() async {
    await Future.wait([
      downloadAndLoadLLM(),
      downloadAndLoadSTT(),
      downloadAndLoadTTS(),
    ]);
  }

  /// Unload all models
  Future<void> unloadAllModels() async {
    await RunAnywhere.llm.unload();
    await RunAnywhere.stt.unload();
    await RunAnywhere.tts.unloadVoice();
    notifyListeners();
  }
}
