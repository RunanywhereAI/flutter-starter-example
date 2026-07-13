import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:runanywhere/runanywhere.dart';

import '../services/model_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/model_loader_widget.dart';

/// Voice Activity Detection view — streams microphone audio through the loaded
/// Silero VAD model and shows live speech / confidence / energy readouts.
/// Uses the SDK's `AudioCaptureManager` for mic capture and
/// `RunAnywhere.vad.streamVAD` for per-chunk detection.
class VADView extends StatefulWidget {
  const VADView({super.key});

  @override
  State<VADView> createState() => _VADViewState();
}

class _VADViewState extends State<VADView> {
  final AudioCaptureManager _capture = AudioCaptureManager();
  StreamSubscription<VADResult>? _vadSubscription;
  StreamSubscription<double>? _levelSubscription;

  bool _isListening = false;
  bool _isSpeech = false;
  double _confidence = 0;
  double _energy = 0;
  int _frameCount = 0;
  double _audioLevel = 0;
  String? _error;

  @override
  void dispose() {
    unawaited(_vadSubscription?.cancel());
    unawaited(_levelSubscription?.cancel());
    unawaited(_capture.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: const Text('Voice Activity'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<ModelService>(
        builder: (context, modelService, child) {
          if (!modelService.isVADLoaded) {
            return ModelLoaderWidget(
              title: 'VAD Model Required',
              subtitle:
                  'Download and load the voice-activity model to detect speech',
              icon: Icons.graphic_eq_rounded,
              accentColor: AppColors.accentOrange,
              isDownloading: modelService.isVADDownloading,
              isLoading: modelService.isVADLoading,
              progress: modelService.vadDownloadProgress,
              onLoad: () => modelService.downloadAndLoadVAD(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildSpeechIndicator(),
                const SizedBox(height: 24),
                _buildVisualizer(),
                const SizedBox(height: 24),
                _buildMetrics(),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 32),
                _buildControlButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpeechIndicator() {
    final active = _isListening && _isSpeech;
    final color = active ? AppColors.accentGreen : AppColors.textMuted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            active ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded,
            size: 48,
            color: color,
          ),
          const SizedBox(height: 12),
          Text(
            _isListening
                ? (_isSpeech ? 'Speech detected' : 'Silence')
                : 'Not listening',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: color),
          ),
        ],
      ),
    ).animate(target: active ? 1 : 0).scaleXY(
          begin: 1,
          end: 1.02,
          duration: 200.ms,
        );
  }

  Widget _buildVisualizer() {
    return Container(
      width: double.infinity,
      height: 120,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.textMuted.withOpacity(0.1)),
      ),
      child: _isListening
          ? AudioVisualizer(level: _audioLevel)
          : Center(
              child: Text(
                'Start listening to see live audio',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
    );
  }

  Widget _buildMetrics() {
    return Row(
      children: [
        _metricCard('Confidence', _confidence.toStringAsFixed(2),
            Icons.percent_rounded, AppColors.accentCyan),
        const SizedBox(width: 12),
        _metricCard('Energy', _energy.toStringAsFixed(3),
            Icons.bolt_rounded, AppColors.accentViolet),
        const SizedBox(width: 12),
        _metricCard('Frames', '$_frameCount',
            Icons.timeline_rounded, AppColors.accentOrange),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        onPressed: _toggleListening,
        icon: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded),
        label: Text(_isListening ? 'Stop Listening' : 'Start Listening'),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isListening ? AppColors.error : AppColors.accentOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!RunAnywhere.vad.isModelLoaded) {
      setState(() => _error = 'Load a VAD model first');
      return;
    }

    final Stream<Uint8List>? chunks = await _capture.startRecording(
      sampleRate: 16000,
      numChannels: 1,
    );
    if (chunks == null) {
      setState(() => _error = 'Microphone capture failed');
      return;
    }

    await _levelSubscription?.cancel();
    _levelSubscription = _capture.audioLevelStream?.listen((level) {
      if (!mounted) return;
      setState(() => _audioLevel = level);
    });

    // One VADResult per mic chunk — the SDK owns model framing.
    _vadSubscription = RunAnywhere.vad.streamVAD(chunks).listen(
      (result) {
        if (!mounted) return;
        if (result.errorMessage.isNotEmpty) {
          setState(() {
            _error = result.errorMessage;
            _isListening = false;
          });
          unawaited(_capture.cancel());
          return;
        }
        setState(() {
          _isSpeech = result.isSpeech;
          _confidence = result.confidence;
          _energy = result.energy;
          _frameCount += 1;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _error = 'VAD failed: $e';
          _isListening = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
    );

    setState(() {
      _isListening = true;
      _error = null;
      _frameCount = 0;
    });
  }

  Future<void> _stopListening() async {
    await _vadSubscription?.cancel();
    _vadSubscription = null;
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    await _capture.stopRecording();

    if (!mounted) return;
    setState(() {
      _isListening = false;
      _isSpeech = false;
      _audioLevel = 0;
    });
  }
}
