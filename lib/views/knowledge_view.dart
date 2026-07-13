import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:runanywhere/runanywhere.dart';

import '../services/model_service.dart';
import '../theme/app_theme.dart';
import '../widgets/model_loader_widget.dart';

/// Knowledge (RAG) view — paste a document, ingest it into the on-device RAG
/// pipeline (embeddings + retrieval), then ask grounded questions answered by
/// the LLM. Exercises `RunAnywhere.rag.*` end-to-end:
/// `ragCreatePipelineForModels` → `ragIngest` → `query` → `destroyPipeline`.
class KnowledgeView extends StatefulWidget {
  const KnowledgeView({super.key});

  @override
  State<KnowledgeView> createState() => _KnowledgeViewState();
}

class _QAPair {
  final String question;
  String answer;
  bool isError;
  _QAPair({required this.question}) : answer = '', isError = false;
}

class _KnowledgeViewState extends State<KnowledgeView> {
  final TextEditingController _documentController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();

  bool _isIngesting = false;
  bool _isQuerying = false;
  bool _documentLoaded = false;
  String? _documentName;
  String? _error;
  final List<_QAPair> _messages = [];

  @override
  void dispose() {
    _documentController.dispose();
    _questionController.dispose();
    // Release the native RAG pipeline if the screen is popped mid-session.
    unawaited(RunAnywhere.rag.destroyPipeline());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: const Text('Knowledge'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_documentLoaded)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'New document',
              onPressed: _clearDocument,
            ),
        ],
      ),
      body: Consumer<ModelService>(
        builder: (context, modelService, child) {
          return FutureBuilder<bool>(
            future: modelService.isRAGReady(),
            builder: (context, snapshot) {
              final ready = snapshot.data ?? false;
              if (!ready) {
                return ModelLoaderWidget(
                  title: 'Knowledge Models Required',
                  subtitle:
                      'Download the embedding + language models to build a '
                      'private knowledge base',
                  icon: Icons.menu_book_rounded,
                  accentColor: AppColors.accentViolet,
                  isDownloading: modelService.isEmbeddingDownloading ||
                      modelService.isLLMDownloading,
                  isLoading: false,
                  progress: modelService.embeddingDownloadProgress,
                  onLoad: () => modelService.downloadRAGDependencies(),
                );
              }

              return _documentLoaded
                  ? _buildQAInterface()
                  : _buildDocumentInput();
            },
          );
        },
      ),
    );
  }

  Widget _buildDocumentInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentViolet.withOpacity(0.1),
                  AppColors.surfaceCard,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.accentViolet.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded,
                    color: AppColors.accentViolet, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Paste any text below, ingest it, then ask questions '
                    'answered only from that content.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _documentController,
            minLines: 8,
            maxLines: 16,
            enabled: !_isIngesting,
            decoration: const InputDecoration(
              hintText: 'Paste your document text here…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(
              _error!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isIngesting ? null : _ingestDocument,
              icon: _isIngesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_stories_rounded),
              label: Text(_isIngesting ? 'Ingesting…' : 'Ingest Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentViolet,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildQAInterface() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: AppColors.surfaceCard.withOpacity(0.5),
          child: Row(
            children: [
              const Icon(Icons.description_rounded,
                  size: 18, color: AppColors.accentViolet),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _documentName ?? 'Document loaded',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) =>
                      _buildQACard(_messages[index]),
                ),
        ),
        _buildQuestionInput(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined,
                size: 56, color: AppColors.accentViolet.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text('Ask about your document',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Answers are grounded in the text you ingested.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQACard(_QAPair pair) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textMuted.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.help_outline_rounded,
                  size: 18, color: AppColors.accentViolet),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pair.question,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 18,
                  color: pair.isError
                      ? AppColors.error
                      : AppColors.accentCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pair.answer.isEmpty ? '…' : pair.answer,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: pair.isError
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildQuestionInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.8),
        border: Border(
          top: BorderSide(color: AppColors.textMuted.withOpacity(0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _questionController,
                enabled: !_isQuerying,
                decoration: const InputDecoration(
                  hintText: 'Ask a question…',
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _askQuestion(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isQuerying
                    ? AppColors.surfaceElevated
                    : AppColors.accentViolet,
                shape: BoxShape.circle,
              ),
              child: _isQuerying
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send_rounded),
                      color: Colors.white,
                      onPressed: _askQuestion,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ingestDocument() async {
    final text = _documentController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please paste some document text first.');
      return;
    }

    final modelService = context.read<ModelService>();
    setState(() {
      _isIngesting = true;
      _error = null;
    });

    try {
      final embedding =
          await modelService.modelInfo(ModelService.embeddingModelId);
      final llm = await modelService.modelInfo(ModelService.llmModelId);
      if (embedding == null || llm == null) {
        throw StateError('Embedding or LLM model not found in registry');
      }

      await RunAnywhere.rag.ragCreatePipelineForModels(
        embeddingModel: embedding,
        llmModel: llm,
      );
      await RunAnywhere.rag.ragIngest(RAGDocument(text: text));

      if (!mounted) return;
      setState(() {
        _documentLoaded = true;
        _documentName =
            'Pasted text (${text.length} chars)';
        _isIngesting = false;
      });
    } catch (e) {
      // Tear down any partially-created pipeline.
      await RunAnywhere.rag.destroyPipeline();
      if (!mounted) return;
      setState(() {
        _error = 'Failed to ingest: $e';
        _isIngesting = false;
      });
    }
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isQuerying || !_documentLoaded) return;

    final pair = _QAPair(question: question);
    setState(() {
      _messages.add(pair);
      _questionController.clear();
      _isQuerying = true;
    });

    try {
      final result = await RunAnywhere.rag.query(question);
      if (!mounted) return;
      setState(() {
        pair.answer = result.answer;
        _isQuerying = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        pair.answer = 'Error: $e';
        pair.isError = true;
        _isQuerying = false;
      });
    }
  }

  Future<void> _clearDocument() async {
    await RunAnywhere.rag.destroyPipeline();
    if (!mounted) return;
    setState(() {
      _documentLoaded = false;
      _documentName = null;
      _messages.clear();
      _documentController.clear();
      _error = null;
    });
  }
}
