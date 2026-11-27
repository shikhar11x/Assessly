import 'package:flutter/material.dart';
import '../theme.dart';

enum BadgeTone { neutral, success, warning, danger }

/// Small status pill (Published, Draft, Locked ...).
class AppBadge extends StatelessWidget {
  final String text;
  final BadgeTone tone;
  const AppBadge(this.text, {super.key, this.tone = BadgeTone.neutral});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Color fg;
    switch (tone) {
      case BadgeTone.success:
        fg = c.success;
      case BadgeTone.warning:
        fg = c.warning;
      case BadgeTone.danger:
        fg = c.danger;
      case BadgeTone.neutral:
        fg = c.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: tone == BadgeTone.neutral ? c.secondarySurface : fg.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Bordered surface with the standard 20px padding.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.cardPadding)});

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}

/// Page title row used at the top of a screen.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PageHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(subtitle!, style: TextStyle(color: c.textSecondary)),
            ),
        ]),
      ),
      ?trailing,
    ]);
  }
}
