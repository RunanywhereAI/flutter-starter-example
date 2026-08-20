import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:runanywhere/runanywhere.dart';

import '../services/model_service.dart';
import '../theme/app_theme.dart';
import '../widgets/model_loader_widget.dart';

/// Vision (VLM) view — supply an image from the gallery or the device camera,
/// enter a prompt, and stream a description from the on-device vision-language
/// model via `RunAnywhere.vlm.generateStream`.
class VisionView extends StatefulWidget {
  const VisionView({super.key});

  @override
  State<VisionView> createState() => _VisionViewState();
}

class _VisionViewState extends State<VisionView> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _promptController =
      TextEditingController(text: 'Describe this image in detail.');

  String? _selectedImagePath;
  bool _isProcessing = false;
  String _description = '';
  String? _error;

  @override
  void dispose() {
    _promptController.dispose();
    if (_isProcessing) {
      RunAnywhere.vlm.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: const Text('Vision'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<ModelService>(
        builder: (context, modelService, child) {
          if (!modelService.isVLMLoaded) {
            return ModelLoaderWidget(
              modelCredit: ModelService.vlmCredit,
              title: 'Vision Model Required',
              subtitle:
                  'Download and load the vision model to describe images',
              icon: Icons.center_focus_strong_rounded,
              accentColor: AppColors.accentGreen,
              isDownloading: modelService.isVLMDownloading,
              isLoading: modelService.isVLMLoading,
              progress: modelService.vlmDownloadProgress,
              onLoad: () => modelService.downloadAndLoadVLM(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImagePreview(),
                const SizedBox(height: 20),
                _buildSourceButtons(),
                const SizedBox(height: 20),
                _buildPromptField(),
                const SizedBox(height: 16),
                _buildDescribeButton(),
                const SizedBox(height: 24),
                _buildResult(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePreview() {
    final path = _selectedImagePath;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accentGreen.withOpacity(0.2),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: path != null
            ? Image.file(File(path), fit: BoxFit.cover, width: double.infinity)
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 56,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pick or capture an image',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSourceButtons() {
    final disabled = _isProcessing;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Gallery'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Camera'),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptField() {
    return TextField(
      controller: _promptController,
      minLines: 1,
      maxLines: 3,
      enabled: !_isProcessing,
      decoration: const InputDecoration(
        hintText: 'Describe this image…',
      ),
    );
  }

  Widget _buildDescribeButton() {
    final canDescribe = _selectedImagePath != null && !_isProcessing;
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isProcessing
            ? _cancel
            : (canDescribe ? _describe : null),
        icon: Icon(_isProcessing ? Icons.stop_rounded : Icons.auto_awesome),
        label: Text(_isProcessing ? 'Stop' : 'Describe'),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isProcessing ? AppColors.error : AppColors.accentGreen,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildResult() {
    if (_error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Text(
          _error!,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.error),
        ),
      );
    }

    if (_isProcessing && _description.isEmpty) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('Analyzing image…',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
    }

    if (_description.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textMuted.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Description',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppColors.accentGreen),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: AppColors.textMuted,
                visualDensity: VisualDensity.compact,
                onPressed: _copyDescription,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(source: source);
      if (xFile != null) {
        setState(() {
          _selectedImagePath = xFile.path;
          _description = '';
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _describe() async {
    final path = _selectedImagePath;
    if (path == null || _isProcessing) return;

    final prompt = _promptController.text.trim().isEmpty
        ? 'Describe this image in detail.'
        : _promptController.text.trim();

    setState(() {
      _isProcessing = true;
      _description = '';
      _error = null;
    });

    try {
      final events = RunAnywhere.vlm.generateStream(
        ImageInput.file(path),
        prompt,
        options: LlmOptions(maxOutputTokens: 300),
      );

      final buffer = StringBuffer();
      await for (final event in events) {
        switch (event) {
          case GenerationTextDelta(text: final delta):
            buffer.write(delta);
            if (!mounted) return;
            setState(() => _description = buffer.toString());
          case GenerationFailed(:final error):
            throw error;
          default:
            break;
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _cancel() {
    RunAnywhere.vlm.cancel();
  }

  void _copyDescription() {
    Clipboard.setData(ClipboardData(text: _description));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Description copied to clipboard')),
    );
  }
}
