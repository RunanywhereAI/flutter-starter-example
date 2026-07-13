import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:runanywhere/runanywhere.dart';

import '../services/model_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_visualizer.dart';

class VoicePipelineView extends StatefulWidget {
  const VoicePipelineView({super.key});

  @override
  State<VoicePipelineView> createState() => _VoicePipelineViewState();
}

class _VoicePipelineViewState extends State<VoicePipelineView> {
  // The SDK owns the STT -> LLM -> TTS session end-to-end (mic capture,
  // turn segmentation, and TTS playback all live behind this one event
  // stream) — this view only drives UI state off the proto VoiceEvent
  // oneof. Mirrors the reference app's `VoiceAgentViewModel`
  // (examples/flutter/RunAnywhereAI/lib/features/voice/voice_agent_view_model.dart).
  StreamSubscription<VoiceEvent>? _eventSubscription;

  bool _isSessionActive = false;
  String _status = 'Ready';
  double _audioLevel = 0.0;
  String _lastTranscript = '';
  String _lastResponse = '';
  final List<ConversationTurn> _conversationHistory = [];

  VoicePipelineState _currentState = VoicePipelineState.idle;

  @override
  void dispose() {
    unawaited(_eventSubscription?.cancel());
    if (_isSessionActive) {
      RunAnywhere.voice.cleanup();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: const Text('Voice Pipeline'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_isSessionActive) {
              unawaited(_stopSession());
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          if (_conversationHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _clearHistory,
              tooltip: 'Clear history',
            ),
        ],
      ),
      body: Consumer<ModelService>(
        builder: (context, modelService, child) {
          // Check if all models are loaded
          if (!modelService.isVoiceAgentReady) {
            return _buildModelLoadingView(modelService);
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 24),
                      _buildVisualizationArea(),
                      const SizedBox(height: 24),
                      if (_lastTranscript.isNotEmpty || _lastResponse.isNotEmpty)
                        _buildCurrentTurnCard(),
                      if (_conversationHistory.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildConversationHistory(),
                      ],
                    ],
                  ),
                ),
              ),
              _buildControlButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModelLoadingView(ModelService modelService) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentGreen.withOpacity(0.1),
                  AppColors.surfaceCard,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.accentGreen.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 48,
                  color: AppColors.accentGreen,
                ),
                const SizedBox(height: 16),
                Text(
                  'Voice Pipeline',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Full voice AI experience: Speak → Transcribe → Generate → Speak',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 32),
          Text(
            'Required Models',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildModelCard(
            icon: Icons.memory_rounded,
            title: 'LLM',
            subtitle: 'SmolLM2 360M',
            isLoaded: modelService.isLLMLoaded,
            isLoading: modelService.isLLMLoading || modelService.isLLMDownloading,
            progress: modelService.llmDownloadProgress,
            onLoad: modelService.downloadAndLoadLLM,
            accentColor: AppColors.accentCyan,
          ),
          const SizedBox(height: 12),
          _buildModelCard(
            icon: Icons.mic_rounded,
            title: 'STT',
            subtitle: 'Whisper Tiny',
            isLoaded: modelService.isSTTLoaded,
            isLoading: modelService.isSTTLoading || modelService.isSTTDownloading,
            progress: modelService.sttDownloadProgress,
            onLoad: modelService.downloadAndLoadSTT,
            accentColor: AppColors.accentViolet,
          ),
          const SizedBox(height: 12),
          _buildModelCard(
            icon: Icons.volume_up_rounded,
            title: 'TTS',
            subtitle: 'Kokoro',
            isLoaded: modelService.isTTSLoaded,
            isLoading: modelService.isTTSLoading || modelService.isTTSDownloading,
            progress: modelService.ttsDownloadProgress,
            onLoad: modelService.downloadAndLoadTTS,
            accentColor: AppColors.accentPink,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: modelService.isLLMDownloading ||
                      modelService.isSTTDownloading ||
                      modelService.isTTSDownloading ||
                      modelService.isLLMLoading ||
                      modelService.isSTTLoading ||
                      modelService.isTTSLoading
                  ? null
                  : () => modelService.downloadAndLoadAllModels(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Download & Load All Models'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLoaded,
    required bool isLoading,
    required double progress,
    required VoidCallback onLoad,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLoaded
              ? AppColors.success.withOpacity(0.5)
              : AppColors.textMuted.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                if (isLoading && progress > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.surfaceElevated,
                      color: accentColor,
                    ),
                  ),
              ],
            ),
          ),
          if (isLoaded)
            const Icon(Icons.check_circle_rounded, color: AppColors.success)
          else if (isLoading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accentColor,
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: onLoad,
              color: accentColor,
            ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;

    switch (_currentState) {
      case VoicePipelineState.idle:
        statusColor = AppColors.textMuted;
        statusIcon = Icons.radio_button_unchecked;
        break;
      case VoicePipelineState.listening:
        statusColor = AppColors.accentViolet;
        statusIcon = Icons.mic_rounded;
        break;
      case VoicePipelineState.processing:
        statusColor = AppColors.accentCyan;
        statusIcon = Icons.psychology_rounded;
        break;
      case VoicePipelineState.speaking:
        statusColor = AppColors.accentPink;
        statusIcon = Icons.volume_up_rounded;
        break;
      case VoicePipelineState.error:
        statusColor = AppColors.error;
        statusIcon = Icons.error_outline_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: statusColor,
                      ),
                ),
                Text(
                  _getStatusDescription(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (_currentState == VoicePipelineState.processing ||
              _currentState == VoicePipelineState.speaking)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: statusColor,
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  String _getStatusDescription() {
    switch (_currentState) {
      case VoicePipelineState.idle:
        return 'Press the button to start talking';
      case VoicePipelineState.listening:
        return 'Speak clearly into your microphone';
      case VoicePipelineState.processing:
        return 'Transcribing and generating response...';
      case VoicePipelineState.speaking:
        return 'Playing AI response';
      case VoicePipelineState.error:
        return 'An error occurred';
    }
  }

  Widget _buildVisualizationArea() {
    return Container(
      width: double.infinity,
      height: 160,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceCard,
            AppColors.surfaceCard.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isSessionActive
              ? AppColors.accentGreen.withOpacity(0.5)
              : AppColors.textMuted.withOpacity(0.1),
          width: _isSessionActive ? 2 : 1,
        ),
        boxShadow: _isSessionActive
            ? [
                BoxShadow(
                  color: AppColors.accentGreen.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: _currentState == VoicePipelineState.listening
          ? AudioVisualizer(level: _audioLevel)
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSessionActive
                        ? Icons.auto_awesome_rounded
                        : Icons.play_arrow_rounded,
                    size: 48,
                    color: AppColors.accentGreen.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isSessionActive
                        ? 'Voice session active'
                        : 'Start the voice session',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildCurrentTurnCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentGreen.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'CURRENT TURN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          if (_lastTranscript.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.person_rounded,
                    size: 20, color: AppColors.accentViolet),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastTranscript,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
          if (_lastResponse.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 20, color: AppColors.accentCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastResponse,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildConversationHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Conversation History',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ),
        ...List.generate(_conversationHistory.length, (index) {
          final turn = _conversationHistory[_conversationHistory.length - 1 - index];
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textMuted.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person_rounded,
                        size: 16, color: AppColors.accentViolet),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        turn.transcript,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 16, color: AppColors.accentCyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        turn.response,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: (index * 50).ms);
        }),
      ],
    );
  }

  Widget _buildControlButton() {
    return Container(
      padding: const EdgeInsets.all(24),
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
        child: GestureDetector(
          onTap: _toggleSession,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              gradient: _isSessionActive
                  ? const LinearGradient(
                      colors: [AppColors.error, Color(0xFFDC2626)],
                    )
                  : const LinearGradient(
                      colors: [AppColors.accentGreen, Color(0xFF059669)],
                    ),
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: (_isSessionActive
                          ? AppColors.error
                          : AppColors.accentGreen)
                      .withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSessionActive
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isSessionActive ? 'Stop Session' : 'Start Voice Session',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
        )
            .animate(target: _isSessionActive ? 1 : 0)
            .scale(begin: const Offset(1, 1), end: const Offset(0.98, 0.98)),
      ),
    );
  }

  Future<void> _toggleSession() async {
    if (_isSessionActive) {
      await _stopSession();
    } else {
      await _startSession();
    }
  }

  Future<void> _startSession() async {
    final hasPermission = await AudioRecorder().hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    setState(() {
      _isSessionActive = true;
      _status = 'Starting...';
      _currentState = VoicePipelineState.processing;
      _lastTranscript = '';
      _lastResponse = '';
    });

    try {
      if (!RunAnywhere.voice.isReady) {
        throw StateError(
          'STT, LLM, and TTS models must all be loaded before starting a '
          'voice session',
        );
      }

      // The SDK composes the loaded STT/LLM/TTS models into one voice-agent
      // session; the mic driver behind eventStream() owns audio capture,
      // turn segmentation, and TTS playback end-to-end.
      await RunAnywhere.voice.initializeWithLoadedModels();

      _eventSubscription = RunAnywhere.voice.eventStream().listen(
        _handleVoiceEvent,
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _status = 'Error: $error';
            _currentState = VoicePipelineState.error;
          });
        },
      );

      setState(() {
        _status = 'Listening';
        _currentState = VoicePipelineState.listening;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _currentState = VoicePipelineState.error;
        _isSessionActive = false;
      });
    }
  }

  /// Drive UI state from the canonical proto `VoiceEvent` oneof. Mirrors the
  /// reference app's `VoiceAgentViewModel._handleProtoEvent`, adapted to this
  /// view's paired transcript+response "current turn" presentation instead
  /// of per-message chat bubbles.
  void _handleVoiceEvent(VoiceEvent event) {
    if (!mounted) return;

    switch (event.whichPayload()) {
      case VoiceEvent_Payload.state:
        _handlePipelineState(event.state.current);
        break;

      case VoiceEvent_Payload.vad:
        final vad = event.vad;
        if (vad.type ==
            VADStreamEventKind.VAD_STREAM_EVENT_KIND_SPEECH_ACTIVITY) {
          setState(() {
            if (vad.isSpeech) {
              _status = 'Speech detected...';
              _currentState = VoicePipelineState.listening;
            } else {
              _status = 'Processing';
              _currentState = VoicePipelineState.processing;
            }
          });
        }
        break;

      case VoiceEvent_Payload.audioLevel:
        setState(() {
          _audioLevel = event.audioLevel.rms.clamp(0.0, 1.0);
        });
        break;

      case VoiceEvent_Payload.userSaid:
        final text = event.userSaid.text;
        if (text.isNotEmpty) {
          setState(() {
            _lastTranscript = text;
          });
        }
        break;

      case VoiceEvent_Payload.assistantToken:
        setState(() {
          _lastResponse += event.assistantToken.text;
        });
        break;

      case VoiceEvent_Payload.audio:
        setState(() {
          _status = 'Speaking';
          _currentState = VoicePipelineState.speaking;
        });
        break;

      case VoiceEvent_Payload.agentResponseCompleted:
        // Canonical end-of-reply signal — commit the completed turn.
        _commitTurn();
        break;

      case VoiceEvent_Payload.error:
        setState(() {
          _status = 'Error: ${event.error.message}';
          _currentState = VoicePipelineState.error;
        });
        break;

      default:
        break;
    }
  }

  void _handlePipelineState(PipelineState state) {
    switch (state) {
      case PipelineState.PIPELINE_STATE_IDLE:
      case PipelineState.PIPELINE_STATE_LISTENING:
        setState(() {
          _status = 'Listening';
          _currentState = VoicePipelineState.listening;
        });
        break;
      case PipelineState.PIPELINE_STATE_THINKING:
        setState(() {
          _status = 'Processing';
          _currentState = VoicePipelineState.processing;
          _audioLevel = 0.0;
        });
        break;
      case PipelineState.PIPELINE_STATE_SPEAKING:
        setState(() {
          _status = 'Speaking';
          _currentState = VoicePipelineState.speaking;
        });
        // Flush the accumulated transcript+response as a completed turn.
        // Idempotent with the agentResponseCompleted commit below — whichever
        // fires first commits and clears the buffers.
        _commitTurn();
        break;
      case PipelineState.PIPELINE_STATE_STOPPED:
        unawaited(_stopSession());
        break;
      default:
        break;
    }
  }

  /// Commit the in-progress transcript+response pair as one conversation
  /// turn, then reset the buffers. No-op when both are empty, so it is safe
  /// to call from every turn-boundary signal without producing duplicates.
  void _commitTurn() {
    if (_lastTranscript.isEmpty && _lastResponse.isEmpty) return;
    setState(() {
      if (_lastTranscript.isNotEmpty && _lastResponse.isNotEmpty) {
        _conversationHistory.add(ConversationTurn(
          transcript: _lastTranscript,
          response: _lastResponse,
          timestamp: DateTime.now(),
        ));
      }
      _lastTranscript = '';
      _lastResponse = '';
      _status = 'Listening';
      _currentState = VoicePipelineState.listening;
    });
  }

  Future<void> _stopSession() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    RunAnywhere.voice.cleanup();
    if (!mounted) return;
    setState(() {
      _isSessionActive = false;
      _status = 'Ready';
      _currentState = VoicePipelineState.idle;
      _audioLevel = 0.0;
    });
  }

  void _clearHistory() {
    setState(() {
      _conversationHistory.clear();
      _lastTranscript = '';
      _lastResponse = '';
    });
  }
}

enum VoicePipelineState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

class ConversationTurn {
  final String transcript;
  final String response;
  final DateTime timestamp;

  ConversationTurn({
    required this.transcript,
    required this.response,
    required this.timestamp,
  });
}
