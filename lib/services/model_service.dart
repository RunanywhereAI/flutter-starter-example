import 'package:flutter/foundation.dart';
import 'package:runanywhere/runanywhere.dart';

/// Service for managing AI models
class ModelService extends ChangeNotifier {
  // Model IDs - curated one-per-modality set mirroring the monorepo reference
  // example (examples/flutter/RunAnywhereAI ModelCatalogBootstrap). Each id /
  // url / framework / category matches what the reference registers. Vision
  // carries a second, larger row (families ordered small -> large, as in the
  // reference) so the Vision view can be pointed at a higher-quality VLM.
  static const String llmModelId = 'smollm2-360m-instruct-q8_0';
  static const String vlmModelId = 'smolvlm-500m-instruct-q8_0';
  static const String vlmLfm25ModelId = 'lfm2.5-vl-3b-q4_k_m';
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

  bool get isLLMLoaded => RunAnywhere.llm.isLoaded;
  bool get isVLMLoaded => RunAnywhere.vlm.isLoaded;
  bool get isSTTLoaded => RunAnywhere.stt.isLoaded;
  bool get isTTSLoaded => RunAnywhere.tts.isLoaded;
  bool get isVADLoaded => RunAnywhere.vad.isModelLoaded;

  bool get isVoiceAgentReady => RunAnywhere.voice.isReady;

  /// Register default models with the SDK — one small, curated model per
  /// exposed modality. Ids / urls / framework / category are copied verbatim
  /// from the monorepo reference example so the two stay in lockstep. Safe to
  /// re-run: commons merges runtime fields on re-registration.
  static Future<void> registerDefaultModels() async {
    // LLM Model - SmolLM2 360M Instruct (small, fast, good for demos)
    try {
      await RunAnywhere.models.register(
        id: llmModelId,
        name: 'SmolLM2 360M Instruct Q8_0',
        url:
            'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q8_0.gguf',
        framework: InferenceFramework.INFERENCE_FRAMEWORK_LLAMA_CPP,
        modality: ModelCategory.MODEL_CATEGORY_LANGUAGE,
        memoryRequirement: 400000000, // ~400MB
      );
    } catch (e) {
      debugPrint('Failed to register LLM model: $e');
    }

    // VLM Model - SmolVLM 500M Instruct (vision-language, archive bundle).
    // tar.gz with a directory-based layout (weights + mmproj projector).
    try {
      await RunAnywhere.models.registerArchiveModel(
        id: vlmModelId,
        name: 'SmolVLM 500M Instruct',
        archiveUrl:
            'https://github.com/RunanywhereAI/sherpa-onnx/releases/download/runanywhere-vlm-models-v1/smolvlm-500m-instruct-q8_0.tar.gz',
        archiveType: ArchiveType.ARCHIVE_TYPE_TAR_GZ,
        structure: ArchiveStructure.ARCHIVE_STRUCTURE_DIRECTORY_BASED,
        framework: InferenceFramework.INFERENCE_FRAMEWORK_LLAMA_CPP,
        modality: ModelCategory.MODEL_CATEGORY_MULTIMODAL,
        memoryRequirement: 600000000,
      );
    } catch (e) {
      debugPrint('Failed to register VLM model: $e');
    }

    // VLM Model - LFM2.5-VL 3B (LiquidAI), multi-file: Q4_K_M weights plus the
    // matching Q8_0 mmproj vision projector. Both files must land in the same
    // folder so llama.cpp finds the projector next to the weights; the shared
    // commons classifier (inferModelFileRole) tags primary-model vs mmproj
    // roles. Much heavier than SmolVLM, so it is registered alongside it
    // instead of replacing the Vision view's default.
    try {
      const files = [
        (
          url:
              'https://huggingface.co/LiquidAI/LFM2.5-VL-3B-GGUF/resolve/main/LFM2.5-VL-3B-Q4_K_M.gguf',
          filename: 'LFM2.5-VL-3B-Q4_K_M.gguf',
        ),
        (
          url:
              'https://huggingface.co/LiquidAI/LFM2.5-VL-3B-GGUF/resolve/main/mmproj-LFM2.5-VL-3B-Q8_0.gguf',
          filename: 'mmproj-LFM2.5-VL-3B-Q8_0.gguf',
        ),
      ];
      final descriptors = files
          .map(
            (file) => ModelFileDescriptor(
              filename: file.filename,
              url: file.url,
              isRequired: true,
              role: RunAnywhere.models.inferModelFileRole(
                filename: file.filename,
                modality: ModelCategory.MODEL_CATEGORY_MULTIMODAL,
              ),
            ),
          )
          .toList();
      await RunAnywhere.models.registerMultiFile(
        id: vlmLfm25ModelId,
        name: 'LFM2.5-VL 3B',
        files: descriptors,
        framework: InferenceFramework.INFERENCE_FRAMEWORK_LLAMA_CPP,
        modality: ModelCategory.MODEL_CATEGORY_MULTIMODAL,
        // Sum of the two file sizes on HuggingFace: Q4_K_M weights
        // (1,674,454,240 B) + Q8_0 mmproj (583,109,120 B).
        memoryRequirement: 2257563360,
      );
    } catch (e) {
      debugPrint('Failed to register LFM2.5-VL model: $e');
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

    // VAD Model - Silero VAD (single-file ONNX)
    try {
      await RunAnywhere.models.register(
        id: vadModelId,
        name: 'Silero VAD',
        url:
            'https://github.com/snakers4/silero-vad/raw/master/src/silero_vad/data/silero_vad.onnx',
        framework: InferenceFramework.INFERENCE_FRAMEWORK_ONNX,
        modality: ModelCategory.MODEL_CATEGORY_VOICE_ACTIVITY_DETECTION,
        memoryRequirement: 2327524,
      );
    } catch (e) {
      debugPrint('Failed to register VAD model: $e');
    }

    // Embedding Model - All MiniLM L6 v2 (multi-file: model.onnx + vocab.txt).
    // Powers the RAG pipeline. Both files must land in the same folder so the
    // C++ RAG pipeline finds the vocab next to the model. The shared commons
    // classifier (inferModelFileRole) tags primary-model vs vocab roles.
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
              isRequired: true,
              role: RunAnywhere.models.inferModelFileRole(
                filename: file.filename,
                modality: ModelCategory.MODEL_CATEGORY_EMBEDDING,
              ),
            ),
          )
          .toList();
      await RunAnywhere.models.registerMultiFile(
        id: embeddingModelId,
        name: 'All MiniLM L6 v2 (Embedding)',
        files: descriptors,
        framework: InferenceFramework.INFERENCE_FRAMEWORK_ONNX,
        modality: ModelCategory.MODEL_CATEGORY_EMBEDDING,
        memoryRequirement: 25500000,
      );
    } catch (e) {
      debugPrint('Failed to register embedding model: $e');
    }
  }

  /// Look up the fully-populated proto [ModelInfo] for a registered id.
  Future<ModelInfo?> modelInfo(String modelId) async {
    final models = await RunAnywhere.models.available();
    for (final model in models) {
      if (model.id == modelId) return model;
    }
    return null;
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

  /// Download and load a VLM model.
  ///
  /// Defaults to the Vision view's model ([vlmModelId]); pass
  /// [vlmLfm25ModelId] to drive the larger LFM2.5-VL 3B row through the same
  /// vision slot.
  Future<void> downloadAndLoadVLM({String modelId = vlmModelId}) async {
    if (_isVLMDownloading || _isVLMLoading) return;

    final isDownloaded = await isModelDownloaded(modelId);

    if (!isDownloaded) {
      _isVLMDownloading = true;
      _vlmDownloadProgress = 0.0;
      notifyListeners();

      try {
        await RunAnywhere.downloadModel(
          modelId,
          onProgress: (progress) async {
            _vlmDownloadProgress = progress.stageProgress;
            notifyListeners();
          },
        );
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
      await RunAnywhere.vlm.load(modelId);
    } catch (e) {
      debugPrint('VLM load error: $e');
    }

    _isVLMLoading = false;
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

  /// Download and load VAD model
  Future<void> downloadAndLoadVAD() async {
    if (_isVADDownloading || _isVADLoading) return;

    final isDownloaded = await isModelDownloaded(vadModelId);

    if (!isDownloaded) {
      _isVADDownloading = true;
      _vadDownloadProgress = 0.0;
      notifyListeners();

      try {
        await RunAnywhere.downloadModel(
          vadModelId,
          onProgress: (progress) async {
            _vadDownloadProgress = progress.stageProgress;
            notifyListeners();
          },
        );
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
      await RunAnywhere.vad.loadModel(vadModelId);
    } catch (e) {
      debugPrint('VAD load error: $e');
    }

    _isVADLoading = false;
    notifyListeners();
  }

  /// Ensure the RAG prerequisites (embedding + LLM) are downloaded.
  ///
  /// RAG's C++ pipeline loads both models by id during pipeline creation, so
  /// they only need to be present on disk here — the RAG view then calls
  /// `RunAnywhere.rag.ragCreatePipelineForModels(...)` with the resolved
  /// [ModelInfo]s.
  Future<void> downloadRAGDependencies() async {
    if (_isEmbeddingDownloading) return;

    _isEmbeddingDownloading = true;
    _embeddingDownloadProgress = 0.0;
    notifyListeners();

    try {
      if (!await isModelDownloaded(embeddingModelId)) {
        await RunAnywhere.downloadModel(
          embeddingModelId,
          onProgress: (progress) async {
            _embeddingDownloadProgress = progress.stageProgress;
            notifyListeners();
          },
        );
      }
      if (!await isModelDownloaded(llmModelId)) {
        _isLLMDownloading = true;
        notifyListeners();
        await RunAnywhere.downloadModel(
          llmModelId,
          onProgress: (progress) async {
            _llmDownloadProgress = progress.stageProgress;
            notifyListeners();
          },
        );
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
    await RunAnywhere.llm.unload();
    await RunAnywhere.vlm.unload();
    await RunAnywhere.stt.unload();
    await RunAnywhere.tts.unloadVoice();
    await RunAnywhere.vad.unloadModel();
    notifyListeners();
  }
}
