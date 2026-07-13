import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import '../widgets/feature_card.dart';
import 'chat_view.dart';
import 'knowledge_view.dart';
import 'speech_to_text_view.dart';
import 'text_to_speech_view.dart';
import 'tool_calling_view.dart';
import 'vad_view.dart';
import 'vision_view.dart';
import 'voice_pipeline_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              Color(0xFF0F1629),
              AppColors.primaryMid,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader(context),
                      const SizedBox(height: 40),
                      _buildSubtitle(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildListDelegate([
                    FeatureCard(
                      title: 'Chat',
                      subtitle: 'LLM Text Generation',
                      icon: Icons.chat_bubble_outline_rounded,
                      gradientColors: const [
                        AppColors.accentCyan,
                        Color(0xFF0EA5E9),
                      ],
                      onTap: () => _navigateTo(context, const ChatView()),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
                    FeatureCard(
                      title: 'Vision',
                      subtitle: 'Image Understanding',
                      icon: Icons.center_focus_strong_rounded,
                      gradientColors: const [
                        AppColors.accentGreen,
                        Color(0xFF059669),
                      ],
                      onTap: () => _navigateTo(context, const VisionView()),
                    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),
                    FeatureCard(
                      title: 'Speech',
                      subtitle: 'Speech to Text',
                      icon: Icons.mic_rounded,
                      gradientColors: const [
                        AppColors.accentViolet,
                        Color(0xFF7C3AED),
                      ],
                      onTap: () =>
                          _navigateTo(context, const SpeechToTextView()),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                    FeatureCard(
                      title: 'Voice',
                      subtitle: 'Text to Speech',
                      icon: Icons.volume_up_rounded,
                      gradientColors: const [
                        AppColors.accentPink,
                        Color(0xFFDB2777),
                      ],
                      onTap: () =>
                          _navigateTo(context, const TextToSpeechView()),
                    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.2),
                    FeatureCard(
                      title: 'Activity',
                      subtitle: 'Voice Detection',
                      icon: Icons.graphic_eq_rounded,
                      gradientColors: const [
                        AppColors.accentOrange,
                        Color(0xFFEA580C),
                      ],
                      onTap: () => _navigateTo(context, const VADView()),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                    FeatureCard(
                      title: 'Pipeline',
                      subtitle: 'Voice Agent',
                      icon: Icons.auto_awesome_rounded,
                      gradientColors: const [
                        AppColors.accentGreen,
                        Color(0xFF059669),
                      ],
                      onTap: () =>
                          _navigateTo(context, const VoicePipelineView()),
                    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.2),
                    FeatureCard(
                      title: 'Knowledge',
                      subtitle: 'RAG over Documents',
                      icon: Icons.menu_book_rounded,
                      gradientColors: const [
                        AppColors.accentViolet,
                        Color(0xFF6D28D9),
                      ],
                      onTap: () => _navigateTo(context, const KnowledgeView()),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                    FeatureCard(
                      title: 'Tools',
                      subtitle: 'Function Calling',
                      icon: Icons.build_rounded,
                      gradientColors: const [
                        AppColors.accentOrange,
                        Color(0xFFEA580C),
                      ],
                      onTap: () =>
                          _navigateTo(context, const ToolCallingView()),
                    ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildInfoSection(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentCyan, AppColors.accentViolet],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentCyan.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 32,
              ),
            ).animate(onPlay: (controller) => controller.repeat()).shimmer(
                  duration: 2000.ms,
                  color: Colors.white.withOpacity(0.3),
                ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RunAnywhere',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          letterSpacing: -1,
                        ),
                  ),
                  Text(
                    'Flutter SDK Starter',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.accentCyan,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1);
  }

  Widget _buildSubtitle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceCard.withOpacity(0.8),
            AppColors.surfaceCard.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentCyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.privacy_tip_rounded,
            color: AppColors.accentCyan.withOpacity(0.8),
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy-First On-Device AI',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'All AI processing happens locally on your device. No data ever leaves your phone.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 600.ms);
  }

  Widget _buildInfoSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textMuted.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            context,
            icon: Icons.memory_rounded,
            title: 'LLM',
            value: 'SmolLM2 360M',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            icon: Icons.center_focus_strong_rounded,
            title: 'VLM',
            value: 'SmolVLM 500M',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            icon: Icons.hearing_rounded,
            title: 'STT',
            value: 'Whisper Tiny',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            icon: Icons.record_voice_over_rounded,
            title: 'TTS',
            value: 'Piper Lessac',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            icon: Icons.graphic_eq_rounded,
            title: 'VAD',
            value: 'Silero',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            icon: Icons.menu_book_rounded,
            title: 'Embeddings',
            value: 'MiniLM L6 v2',
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms, duration: 600.ms);
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 20),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.accentCyan,
              ),
        ),
      ],
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
