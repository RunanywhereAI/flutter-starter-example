import 'package:flutter/foundation.dart';
import 'package:runanywhere/runanywhere.dart';

/// Service for managing AI models
class ModelService extends ChangeNotifier {
  // Model IDs - curated one-per-modality set mirroring the monorepo reference
  // example (examples/flutter/RunAnywhereAI ModelCatalogBootstrap). Each id /
  // url / framework / category matches what the reference registers.
  static const String llmModelId = 'smollm2-360m-instruct-q8_0';
  static const String vlmModelId = 'smolvlm-500m-instruct-q8_0';
  static const String sttModelId = 'sherpa-onnx-whisper-tiny.en';
  static const String ttsModelId = 'vits-piper-en_US-lessac-medium';
  static const String vadModelId = 'silero-vad';
  static const String embeddingModelId = 'all-minilm-l6-v2';

  // Download state
  bool _isLLMDownloading = false;
  bool _isVLMDownloading = false;
  bool _isSTTDownloading = false;
  bool _isTTSDownloading = false;
  bool _isVADDownloading = false;
  bool _isEmbeddingDownloading = false;

  double _llmDownloadProgress = 0.0;
  double _vlmDownloadProgress = 0.0;
  double _sttDownloadProgress = 0.0;
  double _ttsDownloadProgress = 0.0;
  double _vadDownloadProgress = 0.0;
  double _embeddingDownloadProgress = 0.0;

  // Load state
  bool _isLLMLoading = false;
  bool _isVLMLoading = false;
  bool _isSTTLoading = false;
  bool _isTTSLoading = false;
  bool _isVADLoading = false;

  // Resident-model state. `RunAnywhere.models.state()` is the SDK's async
  // source of truth; widget `build()` needs a synchronous answer, so the
  // categories it reports are mirrored here and refreshed after every
  // load/unload.
  final Set<ModelCategory> _loadedCategories = <ModelCategory>{};

  // Getters
  bool get isLLMDownloading => _isLLMDownloading;
  bool get isVLMDownloading => _isVLMDownloading;
  bool get isSTTDownloading => _isSTTDownloading;
  bool get isTTSDownloading => _isTTSDownloading;
  bool get isVADDownloading => _isVADDownloading;
  bool get isEmbeddingDownloading => _isEmbeddingDownloading;

  double get llmDownloadProgress => _llmDownloadProgress;
  double get vlmDownloadProgress => _vlmDownloadProgress;
  double get sttDownloadProgress => _sttDownloadProgress;
  double get ttsDownloadProgress => _ttsDownloadProgress;
  double get vadDownloadProgress => _vadDownloadProgress;
  double get embeddingDownloadProgress => _embeddingDownloadProgress;

  bool get isLLMLoading => _isLLMLoading;
  bool get isVLMLoading => _isVLMLoading;
  bool get isSTTLoading => _isSTTLoading;
  bool get isTTSLoading => _isTTSLoading;
  bool get isVADLoading => _isVADLoading;

  bool get isLLMLoaded =>
      _loadedCategories.contains(ModelCategory.MODEL_CATEGORY_LANGUAGE);
  bool get isVLMLoaded =>
      _loadedCategories.contains(ModelCategory.MODEL_CATEGORY_MULTIMODAL);
  bool get isSTTLoaded => _loadedCategories
      .contains(ModelCategory.MODEL_CATEGORY_SPEECH_RECOGNITION);
  bool get isTTSLoaded =>
      _loadedCategories.contains(ModelCategory.MODEL_CATEGORY_SPEECH_SYNTHESIS);
  bool get isVADLoaded => _loadedCategories
      .contains(ModelCategory.MODEL_CATEGORY_VOICE_ACTIVITY_DETECTION);

  /// A voice session needs STT + LLM + TTS resident before it can be composed.
  bool get isVoiceAgentReady => isSTTLoaded && isLLMLoaded && isTTSLoaded;

  /// Pull the resident-model set from the SDK into the synchronous mirror the
  /// widget tree reads.
  Future<void> refreshLoadedModels() async {
    try {
      final state = await RunAnywhere.models.state();
      _loadedCategories
        ..clear()
        ..addAll(state.loaded.keys);
    } catch (e) {
      debugPrint('Failed to read model state: $e');
    }
    notifyListeners();
  }

  /// Register default models with the SDK — one small, curated model per
  /// exposed modality. Ids / urls / framework / category are copied verbatim
  /// from the monorepo reference example so the two stay in lockstep. Safe to
  /// re-run: commons merges runtime fields on re-registration.
  static Future<void> registerDefaultModels() async {
    // LLM Model - SmolLM2 360M Instruct (small, fast, good for demos)
    try {
      await RunAnywhere.models.register(
        ModelRegistration.url(
          id: llmModelId,
          name: 'SmolLM2 360M Instruct Q8_0',
          url:
              'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q8_0.gguf',
          framework: InferenceFramework.INFERENCE_FRAMEWORK_LLAMA_CPP,
          category: ModelCategory.MODEL_CATEGORY_LANGUAGE,
          memoryRequirementBytes: 400000000, // ~400MB
        ),
      );
    } catch (e) {
      debugPrint('Failed to register LLM model: $e');
    }

    // VLM Model - SmolVLM 500M Instruct (vision-language, archive bundle).
    // tar.gz with a directory-based layout (weights + mmproj projector).
    try {
      await RunAnywhere.models.register(
        ModelRegistration.archive(
          id: vlmModelId,
          name: 'SmolVLM 500M Instruct',
          url:
              'https://github.com/RunanywhereAI/sherpa-onnx/releases/download/runanywhere-vlm-models-v1/smolvlm-500m-instruct-q8_0.tar.gz',
          archiveType: ArchiveType.ARCHIVE_TYPE_TAR_GZ,
          structure: ArchiveStructure.ARCHIVE_STRUCTURE_DIRECTORY_BASED,
          framework: InferenceFramework.INFERENCE_FRAMEWORK_LLAMA_CPP,
          category: ModelCategory.MODEL_CATEGORY_MULTIMODAL,
          memoryRequirementBytes: 600000000,
        ),
      );
    } catch (e) {
      debugPrint('Failed to register VLM model: $e');
    }

    // STT Model - Whisper Tiny English (fast transcription)
    // Using tar.gz format from RunanywhereAI for fast native extraction
    try {
      await RunAnywhere.models.register(
        ModelRegistration.archive(
          id: sttModelId,
          name: 'Sherpa Whisper Tiny (ONNX)',
          url:
              'https://github.com/RunanywhereAI/sherpa-onnx/releases/download/runanywhere-models-v1/sherpa-onnx-whisper-tiny.en.tar.gz',
          archiveType: ArchiveType.ARCHIVE_TYPE_TAR_GZ,
          structure: ArchiveStructure.ARCHIVE_STRUCTURE_NESTED_DIRECTORY,
          framework: InferenceFramework.INFERENCE_FRAMEWORK_SHERPA,
          category: ModelCategory.MODEL_CATEGORY_SPEECH_RECOGNITION,
          memoryRequirementBytes: 75000000,
        ),
      );
    } catch (e) {
      debugPrint('Failed to register STT model: $e');
    }

    // TTS Model - Piper TTS (US English - Medium quality)
    // Using officially supported Piper model for reliable TTS
    try {
      await RunAnywhere.models.register(
        ModelRegistration.archive(
          id: ttsModelId,
          name: 'Piper TTS (US English - Medium)',
          url:
              'https://github.com/RunanywhereAI/sherpa-onnx/releases/download/runanywhere-models-v1/vits-piper-en_US-lessac-medium.tar.gz',
          archiveType: ArchiveType.ARCHIVE_TYPE_TAR_GZ,
          structure: ArchiveStructure.ARCHIVE_STRUCTURE_NESTED_DIRECTORY,
          framework: InferenceFramework.INFERENCE_FRAMEWORK_SHERPA,
          category: ModelCategory.MODEL_CATEGORY_SPEECH_SYNTHESIS,
          memoryRequirementBytes: 65000000,
        ),
      );
    } catch (e) {
      debugPrint('Failed to register TTS model: $e');
    }

    // VAD Model - Silero VAD (single-file ONNX)
    try {
      await RunAnywhere.models.register(
        ModelRegistration.url(
          id: vadModelId,
          name: 'Silero VAD',
          url:
              'https://github.com/snakers4/silero-vad/raw/master/src/silero_vad/data/silero_vad.onnx',
          framework: InferenceFramework.INFERENCE_FRAMEWORK_ONNX,
          category: ModelCategory.MODEL_CATEGORY_VOICE_ACTIVITY_DETECTION,
          memoryRequirementBytes: 2327524,
        ),
      );
    } catch (e) {
      debugPrint('Failed to register VAD model: $e');
    }

    // Embedding Model - All MiniLM L6 v2 (multi-file: model.onnx + vocab.txt).
    // Powers the RAG pipeline. Both files must land in the same folder so the
    // C++ RAG pipeline finds the vocab next to the model. Per-file roles are
    // left unset: `models.register` fills them in through the commons
    // classifier, so the app never restates the SDK's filename conventions.
    try {
      const files = [
        (
          url:
              'https://huggingface.co/Xenova/all-MiniLM-L6-v2/resolve/main/onnx/model.onnx',
          filename: 'model.onnx',
        ),
        (
          url:
              'https://huggingface.co/Xenova/all-MiniLM-L6-v2/resolve/main/vocab.txt',
          filename: 'vocab.txt',
        ),
      ];
      final descriptors = files
          .map(
            (file) => ModelFileDescriptor(
              filename: file.filename,
              url: file.url,
            ),
          )
          .toList();
      await RunAnywhere.models.register(
        ModelRegistration.multiFile(
          id: embeddingModelId,
          name: 'All MiniLM L6 v2 (Embedding)',
          files: descriptors,
          framework: InferenceFramework.INFERENCE_FRAMEWORK_ONNX,
          category: ModelCategory.MODEL_CATEGORY_EMBEDDING,
          memoryRequirementBytes: 25500000,
        ),
      );
    } catch (e) {
      debugPrint('Failed to register embedding model: $e');
    }
  }

  /// Look up the fully-populated proto [ModelInfo] for a registered id.
  Future<ModelInfo?> modelInfo(String modelId) => RunAnywhere.models.get(modelId);

  /// Check if a model is downloaded
  Future<bool> isModelDownloaded(String modelId) async {
    final model = await RunAnywhere.models.get(modelId);
    return model != null && model.localPath.isNotEmpty;
  }

  /// Drive one `models.download` stream, reporting commons-owned progress.
  ///
  /// Throws the SDK's own [SDKException] on a terminal failure so callers see
  /// the real reason rather than a silently-empty download.
  Future<void> _download(
    String modelId,
    void Function(double progress) onProgress,
  ) async {
    await for (final event in RunAnywhere.models.download(modelId)) {
      switch (event) {
        case DownloadProgressEvent(
            :final overallProgress,
            :final bytesDone,
            :final bytesTotal,
          ):
          onProgress(
            overallProgress ??
                (bytesTotal > 0 ? bytesDone / bytesTotal : 0.0),
          );
        case DownloadCompleted():
          onProgress(1.0);
        case DownloadFailed(:final error):
          throw error;
        case DownloadCancelled():
          return;
        default:
          break;
      }
    }
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
        await _download(llmModelId, (progress) {
          _llmDownloadProgress = progress;
          notifyListeners();
        });
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
      await RunAnywhere.models.load(llmModelId);
    } catch (e) {
      debugPrint('LLM load error: $e');
    }

    _isLLMLoading = false;
    await refreshLoadedModels();
  }

  /// Download and load VLM model
  Future<void> downloadAndLoadVLM() async {
    if (_isVLMDownloading || _isVLMLoading) return;

    final isDownloaded = await isModelDownloaded(vlmModelId);

    if (!isDownloaded) {
      _isVLMDownloading = true;
      _vlmDownloadProgress = 0.0;
      notifyListeners();

      try {
        await _download(vlmModelId, (progress) {
          _vlmDownloadProgress = progress;
          notifyListeners();
        });
      } catch (e) {
        debugPrint('VLM download error: $e');
      }

      _isVLMDownloading = false;
      notifyListeners();
    }

    // Load the model
    _isVLMLoading = true;
    notifyListeners();

    try {
      await RunAnywhere.models.load(vlmModelId);
    } catch (e) {
      debugPrint('VLM load error: $e');
    }

    _isVLMLoading = false;
    await refreshLoadedModels();
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
        await _download(sttModelId, (progress) {
          _sttDownloadProgress = progress;
          notifyListeners();
        });
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
      await RunAnywhere.models.load(sttModelId);
    } catch (e) {
      debugPrint('STT load error: $e');
    }

    _isSTTLoading = false;
    await refreshLoadedModels();
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
        await _download(ttsModelId, (progress) {
          _ttsDownloadProgress = progress;
          notifyListeners();
        });
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
      await RunAnywhere.models.load(ttsModelId);
    } catch (e) {
      debugPrint('TTS load error: $e');
    }

    _isTTSLoading = false;
    await refreshLoadedModels();
  }

  /// Download and load VAD model
  Future<void> downloadAndLoadVAD() async {
    if (_isVADDownloading || _isVADLoading) return;

    final isDownloaded = await isModelDownloaded(vadModelId);

    if (!isDownloaded) {
      _isVADDownloading = true;
      _vadDownloadProgress = 0.0;
      notifyListeners();

      try {
        await _download(vadModelId, (progress) {
          _vadDownloadProgress = progress;
          notifyListeners();
        });
      } catch (e) {
        debugPrint('VAD download error: $e');
      }

      _isVADDownloading = false;
      notifyListeners();
    }

    // Load the model
    _isVADLoading = true;
    notifyListeners();

    try {
      await RunAnywhere.models.load(vadModelId);
    } catch (e) {
      debugPrint('VAD load error: $e');
    }

    _isVADLoading = false;
    await refreshLoadedModels();
  }

  /// Ensure the RAG prerequisites (embedding + LLM) are downloaded.
  ///
  /// `RunAnywhere.rag.open` loads both models by id when the session is
  /// created, so they only need to be present on disk here — the Knowledge
  /// view then opens the session with a [ModelRef] per model.
  Future<void> downloadRAGDependencies() async {
    if (_isEmbeddingDownloading) return;

    _isEmbeddingDownloading = true;
    _embeddingDownloadProgress = 0.0;
    notifyListeners();

    try {
      if (!await isModelDownloaded(embeddingModelId)) {
        await _download(embeddingModelId, (progress) {
          _embeddingDownloadProgress = progress;
          notifyListeners();
        });
      }
      if (!await isModelDownloaded(llmModelId)) {
        _isLLMDownloading = true;
        notifyListeners();
        await _download(llmModelId, (progress) {
          _llmDownloadProgress = progress;
          notifyListeners();
        });
        _isLLMDownloading = false;
      }
    } catch (e) {
      debugPrint('RAG dependency download error: $e');
    }

    _isEmbeddingDownloading = false;
    notifyListeners();
  }

  /// True once both RAG dependencies (embedding + LLM) are on disk.
  Future<bool> isRAGReady() async {
    return await isModelDownloaded(embeddingModelId) &&
        await isModelDownloaded(llmModelId);
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
    await RunAnywhere.models.unloadAll();
    await refreshLoadedModels();
  }
}
