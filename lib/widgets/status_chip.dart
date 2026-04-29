import 'package:flutter/material.dart';

enum StatusChipTone {
  neutral,
  info,
  success,
  warning,
  danger,
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusChipTone.neutral,
  });

  final String label;
  final StatusChipTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = switch (tone) {
      StatusChipTone.neutral => (
          background: colorScheme.surfaceContainerHighest,
          foreground: colorScheme.onSurfaceVariant,
        ),
      StatusChipTone.info => (
          background: colorScheme.primaryContainer,
          foreground: colorScheme.onPrimaryContainer,
        ),
      StatusChipTone.success => (
          background: colorScheme.secondaryContainer,
          foreground: colorScheme.onSecondaryContainer,
        ),
      StatusChipTone.warning => (
          background: colorScheme.tertiaryContainer,
          foreground: colorScheme.onTertiaryContainer,
        ),
      StatusChipTone.danger => (
          background: colorScheme.errorContainer,
          foreground: colorScheme.onErrorContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colors.foreground.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
      ),
    );
  }
}
