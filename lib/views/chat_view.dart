import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:runanywhere/runanywhere.dart';

import '../services/model_service.dart';
import '../theme/app_theme.dart';
import '../widgets/model_loader_widget.dart';
import '../widgets/chat_message_bubble.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  bool _cancelRequested = false;
  String _currentResponse = '';

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    if (_isGenerating) {
      RunAnywhere.llm.cancelGeneration();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: const Text('Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _clearChat,
              tooltip: 'Clear chat',
            ),
        ],
      ),
      body: Consumer<ModelService>(
        builder: (context, modelService, child) {
          if (!modelService.isLLMLoaded) {
            return ModelLoaderWidget(
              title: 'LLM Model Required',
              subtitle:
                  'Download and load the language model to start chatting',
              icon: Icons.chat_bubble_outline_rounded,
              accentColor: AppColors.accentCyan,
              isDownloading: modelService.isLLMDownloading,
              isLoading: modelService.isLLMLoading,
              progress: modelService.llmDownloadProgress,
              onLoad: () => modelService.downloadAndLoadLLM(),
            );
          }

          return Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessagesList(),
              ),
              _buildInputArea(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: AppColors.accentCyan,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: 2000.ms),
            const SizedBox(height: 24),
            Text(
              'Start a Conversation',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Ask anything! The AI runs entirely on your device.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('Tell me a joke'),
                _buildSuggestionChip('What is AI?'),
                _buildSuggestionChip('Write a haiku'),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      backgroundColor: AppColors.surfaceCard,
      side: BorderSide(color: AppColors.accentCyan.withOpacity(0.3)),
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textPrimary,
          ),
      onPressed: () {
        _controller.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isGenerating ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isGenerating) {
          return ChatMessageBubble(
            message: ChatMessage(
              text: _currentResponse.isEmpty ? '...' : _currentResponse,
              isUser: false,
              timestamp: DateTime.now(),
            ),
            isStreaming: true,
          ).animate().fadeIn(duration: 300.ms);
        }

        return ChatMessageBubble(
          message: _messages[index],
        ).animate().fadeIn(duration: 300.ms).slideX(
              begin: _messages[index].isUser ? 0.1 : -0.1,
            );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.8),
        border: Border(
          top: BorderSide(
            color: AppColors.textMuted.withOpacity(0.1),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: AppColors.primaryMid,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                enabled: !_isGenerating,
              ),
            ),
            const SizedBox(width: 12),
            _isGenerating
                ? Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.stop_rounded),
                      color: AppColors.error,
                      onPressed: _stopGeneration,
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accentCyan, AppColors.accentViolet],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentCyan.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded),
                      color: Colors.white,
                      onPressed: _sendMessage,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isGenerating) return;

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _controller.clear();
      _isGenerating = true;
      _currentResponse = '';
    });

    _scrollToBottom();

    try {
      final events = RunAnywhere.llm.generateStream(
        text,
        LLMGenerationOptions(
          maxTokens: 256,
          temperature: 0.8,
        ),
      );

      // Consumes the token stream and aggregates it into one final result
      // (text + metrics), while `onToken` drives the live partial-response UI.
      final result = await RunAnywhere.aggregateStream(
        prompt: text,
        events: events,
        onToken: (aggregated) async {
          if (!mounted) return;
          setState(() {
            _currentResponse = aggregated;
          });
          _scrollToBottom();
        },
      );

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: result.text,
            isUser: false,
            timestamp: DateTime.now(),
            tokensPerSecond: result.tokensPerSecond,
            totalTokens: result.totalTokens,
            wasCancelled: _cancelRequested,
          ));
          _isGenerating = false;
          _currentResponse = '';
          _cancelRequested = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Error: $e',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
          _isGenerating = false;
          _currentResponse = '';
          _cancelRequested = false;
        });
      }
    }
  }

  void _stopGeneration() {
    // The pending _sendMessage() call owns appending the final bubble once
    // the (now-cancelled) stream actually terminates — this just requests
    // cancellation and flags it, avoiding a duplicate bubble race.
    _cancelRequested = true;
    RunAnywhere.llm.cancelGeneration();
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final double? tokensPerSecond;
  final int? totalTokens;
  final bool isError;
  final bool wasCancelled;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.tokensPerSecond,
    this.totalTokens,
    this.isError = false,
    this.wasCancelled = false,
  });
}
