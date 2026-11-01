import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand_logo.dart';

/// Left-side marketing panel shown on wide screens.
class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.panelGradient),
      child: Stack(
        children: [
          // Decorative glow circles.
          Positioned(
            top: -120,
            right: -100,
            child: _GlowCircle(
              size: 340,
              color: AppColors.accent.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -120,
            child: _GlowCircle(
              size: 400,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          const Positioned(
            top: 40,
            left: 56,
            child: BrandLogo(onGradient: true),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 56,
                vertical: 110,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: const _PanelContent(),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 56,
            child: Text(
              'Secure. Fair. Built for campus exams.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelContent extends StatelessWidget {
  const _PanelContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Built for colleges',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 20),
        const Text(
          'Run coding exams\nthe modern way.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        )
            .animate(delay: 100.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.15, end: 0, curve: Curves.easeOut),
        const SizedBox(height: 16),
        Text(
          'Create, deliver and evaluate programming and objective '
          'assessments with live monitoring and instant results.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 16,
            height: 1.5,
          ),
        ).animate(delay: 200.ms).fadeIn(duration: 500.ms),
        const SizedBox(height: 32),
        const _CodePreviewCard()
            .animate(delay: 350.ms)
            .fadeIn(duration: 600.ms)
            .slideY(begin: 0.12, end: 0, curve: Curves.easeOut),
        const SizedBox(height: 32),
        const _FeatureRow(
          icon: Icons.terminal_rounded,
          title: 'Secure code execution',
          subtitle: 'Isolated judging with hidden test cases.',
        ).animate(delay: 500.ms).fadeIn(duration: 400.ms),
        const SizedBox(height: 16),
        const _FeatureRow(
          icon: Icons.monitor_heart_outlined,
          title: 'Live monitoring',
          subtitle: 'Real-time alerts and event logs for faculty.',
        ).animate(delay: 600.ms).fadeIn(duration: 400.ms),
        const SizedBox(height: 16),
        const _FeatureRow(
          icon: Icons.insights_rounded,
          title: 'Instant analytics',
          subtitle: 'Question-wise and topic-wise performance.',
        ).animate(delay: 700.ms).fadeIn(duration: 400.ms),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Glass-style card that previews a coding submission result.
class _CodePreviewCard extends StatelessWidget {
  const _CodePreviewCard();

  static const String _sampleCode = 'int maxElement(vector<int>& a) {\n'
      '  sort(a.begin(), a.end());\n'
      '  return a.back();\n'
      '}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Dot(color: Color(0xFFFF5F57)),
              const SizedBox(width: 6),
              const _Dot(color: Color(0xFFFEBC2E)),
              const SizedBox(width: 6),
              const _Dot(color: Color(0xFF28C840)),
              const Spacer(),
              Text(
                'solution.cpp',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            _sampleCode,
            style: TextStyle(
              fontFamily: 'monospace',
              color: Colors.white,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              _ResultChip(label: '7 passed', color: AppColors.success),
              SizedBox(width: 8),
              _ResultChip(label: '3 failed', color: Color(0xFFF87171)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}