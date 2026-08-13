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
/// Silero VAD model and shows live speech / confidence readouts.
/// Uses the SDK's `AudioCaptureManager` for mic capture and
/// `RunAnywhere.vad.openStream` for per-frame detection.
class VADView extends StatefulWidget {
  const VADView({super.key});

  @override
  State<VADView> createState() => _VADViewState();
}

class _VADViewState extends State<VADView> {
  final AudioCaptureManager _capture = AudioCaptureManager();
  VadStream? _vadStream;
  StreamSubscription<VadEvent>? _vadSubscription;
  StreamSubscription<Uint8List>? _chunkSubscription;
  StreamSubscription<double>? _levelSubscription;

  bool _isListening = false;
  bool _isSpeech = false;
  double _confidence = 0;
  int _speechFrames = 0;
  int _frameCount = 0;
  double _audioLevel = 0;
  String? _error;

  @override
  void dispose() {
    unawaited(_vadSubscription?.cancel());
    unawaited(_chunkSubscription?.cancel());
    unawaited(_levelSubscription?.cancel());
    unawaited(_vadStream?.close());
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
        _metricCard('Speech', '$_speechFrames',
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
    if (!context.read<ModelService>().isVADLoaded) {
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

    // The format is declared once at open time; every frame pushed afterward
    // carries raw PCM in it. The SDK owns model framing behind the stream.
    final stream = RunAnywhere.vad.openStream(
      const AudioFormatSpec(
        encoding: AudioEncoding.pcm16,
        sampleRate: 16000,
      ),
    );
    _vadStream = stream;

    _chunkSubscription = chunks.listen(
      (chunk) => stream.pushFrame(
        AudioFrame(samples: chunk, sampleCount: chunk.lengthInBytes ~/ 2),
      ),
      onDone: stream.finish,
    );

    _vadSubscription = stream.events.listen((event) {
      if (!mounted) return;
      switch (event) {
        case VadActivity(:final isSpeech, :final probability):
          setState(() {
            _isSpeech = isSpeech;
            _confidence = probability;
            _frameCount += 1;
            if (isSpeech) _speechFrames += 1;
          });
        // Both terminal events end the session for good. Route them through
        // _stopListening() so the chunk/event/level subscriptions are
        // cancelled and the VadStream is released. Otherwise pressing Start
        // again would overwrite the handle fields and leak the previous
        // stream (and the microphone) behind them.
        case VadFailed(:final error):
          setState(() => _error = 'VAD failed: ${error.message}');
          unawaited(_stopListening());
        case VadCompleted():
          unawaited(_stopListening());
        default:
          break;
      }
    });

    setState(() {
      _isListening = true;
      _error = null;
      _frameCount = 0;
      _speechFrames = 0;
    });
  }

  Future<void> _stopListening() async {
    await _chunkSubscription?.cancel();
    _chunkSubscription = null;
    await _vadSubscription?.cancel();
    _vadSubscription = null;
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    await _vadStream?.close();
    _vadStream = null;
    await _capture.stopRecording();

    if (!mounted) return;
    setState(() {
      _isListening = false;
      _isSpeech = false;
      _audioLevel = 0;
    });
  }
}
