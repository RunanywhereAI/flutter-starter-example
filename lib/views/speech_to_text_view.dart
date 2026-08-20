import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:runanywhere/runanywhere.dart';
import 'package:record/record.dart';

import '../services/model_service.dart';
import '../theme/app_theme.dart';
import '../widgets/model_loader_widget.dart';
import '../widgets/audio_visualizer.dart';

class SpeechToTextView extends StatefulWidget {
  const SpeechToTextView({super.key});

  @override
  State<SpeechToTextView> createState() => _SpeechToTextViewState();
}

class _SpeechToTextViewState extends State<SpeechToTextView> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  String _transcription = '';
  List<String> _transcriptionHistory = [];
  StreamSubscription<Uint8List>? _recordingSubscription;
  List<int> _audioBuffer = [];
  double _audioLevel = 0.0;
  Timer? _levelTimer;

  @override
  void dispose() {
    _recordingSubscription?.cancel();
    _levelTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: const Text('Speech to Text'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_transcriptionHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _clearHistory,
              tooltip: 'Clear history',
            ),
        ],
      ),
      body: Consumer<ModelService>(
        builder: (context, modelService, child) {
          if (!modelService.isSTTLoaded) {
            return ModelLoaderWidget(
              modelCredit: ModelService.sttCredit,
              title: 'STT Model Required',
              subtitle: 'Download and load the speech recognition model',
              icon: Icons.mic_rounded,
              accentColor: AppColors.accentViolet,
              isDownloading: modelService.isSTTDownloading,
              isLoading: modelService.isSTTLoading,
              progress: modelService.sttDownloadProgress,
              onLoad: () => modelService.downloadAndLoadSTT(),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildRecordingArea(),
                      const SizedBox(height: 32),
                      if (_transcription.isNotEmpty || _isTranscribing)
                        _buildCurrentTranscription(),
                      if (_transcriptionHistory.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildTranscriptionHistory(),
                      ],
                    ],
                  ),
                ),
              ),
              _buildRecordButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecordingArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
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
          color: _isRecording
              ? AppColors.accentViolet.withOpacity(0.5)
              : AppColors.textMuted.withOpacity(0.1),
          width: _isRecording ? 2 : 1,
        ),
        boxShadow: _isRecording
            ? [
                BoxShadow(
                  color: AppColors.accentViolet.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          if (_isRecording) ...[
            AudioVisualizer(level: _audioLevel),
            const SizedBox(height: 24),
            Text(
              'Listening...',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.accentViolet,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Speak clearly into your microphone',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ] else if (_isTranscribing) ...[
            const SizedBox(
              height: 80,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.accentViolet,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Transcribing...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accentViolet.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_rounded,
                size: 48,
                color: AppColors.accentViolet,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tap to Record',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'On-device speech recognition',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildCurrentTranscription() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentViolet.withOpacity(0.3),
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
                  color: AppColors.accentViolet.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LATEST',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.accentViolet,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _isTranscribing
              ? Row(
                  children: [
                    Text(
                      'Processing',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentViolet,
                      ),
                    ),
                  ],
                )
              : SelectableText(
                  _transcription,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildTranscriptionHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'History',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ),
        ...List.generate(_transcriptionHistory.length, (index) {
          final reversedIndex = _transcriptionHistory.length - 1 - index;
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
            child: SelectableText(
              _transcriptionHistory[reversedIndex],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ).animate().fadeIn(delay: (index * 50).ms);
        }),
      ],
    );
  }

  Widget _buildRecordButton() {
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
          onTap: _isTranscribing ? null : _toggleRecording,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              gradient: _isRecording
                  ? const LinearGradient(
                      colors: [AppColors.error, Color(0xFFDC2626)],
                    )
                  : const LinearGradient(
                      colors: [AppColors.accentViolet, Color(0xFF7C3AED)],
                    ),
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color:
                      (_isRecording ? AppColors.error : AppColors.accentViolet)
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
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isRecording ? 'Stop Recording' : 'Start Recording',
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
            .animate(target: _isRecording ? 1 : 0)
            .scale(begin: const Offset(1, 1), end: const Offset(0.98, 0.98)),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _audioBuffer = [];
      _transcription = '';
    });

    // Start streaming recording
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    // Listen to audio data
    _recordingSubscription = stream.listen((data) {
      _audioBuffer.addAll(data);
    });

    // Start level monitoring
    _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final amplitude = await _recorder.getAmplitude();
      if (mounted) {
        setState(() {
          // Convert dB to 0-1 range
          final dB = amplitude.current;
          _audioLevel = ((dB + 60) / 60).clamp(0.0, 1.0);
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordingSubscription?.cancel();
    _levelTimer?.cancel();
    await _recorder.stop();

    setState(() {
      _isRecording = false;
      _audioLevel = 0.0;
      _isTranscribing = true;
    });

    // Transcribe the audio
    try {
      final audioData = Uint8List.fromList(_audioBuffer);
      if (audioData.length > 1600) {
        // At least 0.1s of audio at 16kHz. The recorder streams raw
        // PCM16 mono samples (no WAV container), so describe them with the
        // matching AudioInput factory rather than the WAV-container default.
        final output = await RunAnywhere.stt.transcribe(
          AudioInput.pcm16(audioData, sampleRate: 16000),
        );
        final text = output.text;

        if (mounted) {
          setState(() {
            _transcription = text.isEmpty ? '(No speech detected)' : text;
            if (text.isNotEmpty) {
              _transcriptionHistory.add(text);
            }
            _isTranscribing = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _transcription = '(Recording too short)';
            _isTranscribing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _transcription = 'Error: $e';
          _isTranscribing = false;
        });
      }
    }
  }

  void _clearHistory() {
    setState(() {
      _transcriptionHistory.clear();
      _transcription = '';
    });
  }
}
