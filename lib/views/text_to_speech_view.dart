import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:runanywhere/runanywhere.dart';

import '../services/model_service.dart';
import '../theme/app_theme.dart';
import '../widgets/model_loader_widget.dart';

class TextToSpeechView extends StatefulWidget {
  const TextToSpeechView({super.key});

  @override
  State<TextToSpeechView> createState() => _TextToSpeechViewState();
}

class _TextToSpeechViewState extends State<TextToSpeechView> {
  final TextEditingController _controller = TextEditingController();
  StreamSubscription<bool>? _playbackSubscription;
  bool _isSynthesizing = false;
  bool _isPlaying = false;
  double _speechRate = 1.0;
  String? _lastSynthesizedText;

  // Sample texts for quick testing
  final List<String> _sampleTexts = [
    'Hello! Welcome to RunAnywhere. Experience the power of on-device AI.',
    'The quick brown fox jumps over the lazy dog.',
    'Technology is best when it brings people together.',
    'Privacy is not something that I am merely entitled to, it is an absolute prerequisite.',
  ];

  @override
  void initState() {
    super.initState();
    // The SDK owns synthesis + playback for speak(); just mirror its
    // playing-state stream into local UI state.
    _playbackSubscription = RunAnywhere.tts.playbackState.listen((
      isPlaying,
    ) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _playbackSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: const Text('Text to Speech'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<ModelService>(
        builder: (context, modelService, child) {
          if (!modelService.isTTSLoaded) {
            return ModelLoaderWidget(
              title: 'TTS Voice Required',
              subtitle: 'Download and load the voice synthesis model',
              icon: Icons.volume_up_rounded,
              accentColor: AppColors.accentPink,
              isDownloading: modelService.isTTSDownloading,
              isLoading: modelService.isTTSLoading,
              progress: modelService.ttsDownloadProgress,
              onLoad: () => modelService.downloadAndLoadTTS(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputSection(),
                const SizedBox(height: 24),
                _buildControlsSection(),
                const SizedBox(height: 24),
                _buildPlaybackSection(),
                const SizedBox(height: 32),
                _buildSampleTexts(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accentPink.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Enter text to synthesize...',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryMid,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.text_fields_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_controller.text.length} characters',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (_controller.text.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _controller.clear();
                      setState(() {});
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildControlsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textMuted.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Speech Rate',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: AppColors.textMuted),
              Expanded(
                child: Slider(
                  value: _speechRate,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  activeColor: AppColors.accentPink,
                  inactiveColor: AppColors.surfaceElevated,
                  onChanged: (value) {
                    setState(() {
                      _speechRate = value;
                    });
                  },
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentPink.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_speechRate.toStringAsFixed(1)}x',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.accentPink,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 600.ms);
  }

  Widget _buildPlaybackSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceCard,
            AppColors.surfaceCard.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isPlaying
              ? AppColors.accentPink.withOpacity(0.5)
              : AppColors.textMuted.withOpacity(0.1),
          width: _isPlaying ? 2 : 1,
        ),
        boxShadow: _isPlaying
            ? [
                BoxShadow(
                  color: AppColors.accentPink.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          if (_isPlaying)
            _buildPlayingAnimation()
          else if (_isSynthesizing)
            _buildSynthesizingState()
          else
            _buildIdleState(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play/Replay button
              if (_lastSynthesizedText != null && !_isSynthesizing)
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.stop_rounded : Icons.replay_rounded,
                  ),
                  onPressed: _isPlaying ? _stopPlayback : _replayAudio,
                  color: AppColors.textSecondary,
                  iconSize: 28,
                ),
              const SizedBox(width: 16),
              // Main action button
              GestureDetector(
                onTap: _isSynthesizing || _isPlaying ? null : _synthesize,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isSynthesizing
                          ? [AppColors.textMuted, AppColors.textMuted]
                          : [AppColors.accentPink, const Color(0xFFDB2777)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentPink.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSynthesizing
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                  ),
                ),
              ).animate(target: _isSynthesizing ? 1 : 0).scale(
                  begin: const Offset(1, 1), end: const Offset(0.95, 0.95)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _isSynthesizing
                ? 'Synthesizing...'
                : _isPlaying
                    ? 'Playing...'
                    : 'Tap to synthesize',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms);
  }

  Widget _buildPlayingAnimation() {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(7, (index) {
          return Container(
            width: 6,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.accentPink,
              borderRadius: BorderRadius.circular(3),
            ),
          )
              .animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              )
              .scaleY(
                begin: 0.3,
                end: 1.0,
                delay: (index * 100).ms,
                duration: 400.ms,
              );
        }),
      ),
    );
  }

  Widget _buildSynthesizingState() {
    return const SizedBox(
      height: 60,
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.accentPink,
        ),
      ),
    );
  }

  Widget _buildIdleState() {
    return SizedBox(
      height: 60,
      child: Center(
        child: Icon(
          Icons.volume_up_rounded,
          size: 48,
          color: AppColors.accentPink.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildSampleTexts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sample Texts',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_sampleTexts.length, (index) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _controller.text = _sampleTexts[index];
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.textMuted.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _sampleTexts[index],
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.accentPink.withOpacity(0.6),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: (300 + index * 50).ms);
        }),
      ],
    );
  }

  Future<void> _synthesize() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text')),
      );
      return;
    }

    setState(() {
      _isSynthesizing = true;
    });

    try {
      // The SDK synthesizes AND plays the audio through the device
      // speakers — no manual WAV encoding or audio-player wiring needed.
      // `speak` returns immediately with a handle to the in-flight utterance;
      // failures surface on `handle.error` once it settles.
      final handle = RunAnywhere.tts.speak(
        text,
        options: TtsOptions(speed: _speechRate),
      );
      _lastSynthesizedText = text;
      await handle.waitForPlayout();
      final failure = handle.error;
      if (failure != null) throw failure;

      if (mounted) {
        setState(() {
          _isSynthesizing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSynthesizing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _replayAudio() async {
    final text = _lastSynthesizedText;
    if (text == null) return;
    try {
      final handle = RunAnywhere.tts.speak(
        text,
        options: TtsOptions(speed: _speechRate),
      );
      await handle.waitForPlayout();
      final failure = handle.error;
      if (failure != null) throw failure;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _stopPlayback() async {
    await RunAnywhere.tts.stop();
  }
}
