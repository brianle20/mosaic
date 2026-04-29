import 'package:flutter/material.dart';

class SoftHostScaffold extends StatelessWidget {
  const SoftHostScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showBackButton = false,
    this.onBack,
    this.actions = const [],
    this.extendBehindAppBar = true,
    this.contentPadding = const EdgeInsets.fromLTRB(
      16,
      kToolbarHeight + 12,
      16,
      24,
    ),
  });

  final String title;
  final Widget body;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool extendBehindAppBar;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: const ValueKey('softHostScaffold'),
      extendBodyBehindAppBar: extendBehindAppBar,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: showBackButton
            ? Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GlassCircleButton(
                  visualKey: const ValueKey('softHostBackButton'),
                  icon: Icons.chevron_left,
                  tooltip: 'Back',
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                ),
              )
            : null,
        title: GlassTitlePill(title: title),
        centerTitle: true,
        actions: [
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: action,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.75),
              colorScheme.secondaryContainer.withValues(alpha: 0.35),
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: const [0, 0.26, 0.42],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: contentPadding,
            child: body,
          ),
        ),
      ),
    );
  }
}

class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.visualKey,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Key? visualKey;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Center(
      child: SizedBox.square(
        key: visualKey,
        dimension: 40,
        child: Material(
          color: Colors.white.withValues(alpha: 0.46),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurface,
              size: 22,
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(
      message: tooltip!,
      child: button,
    );
  }
}

class GlassTitlePill extends StatelessWidget {
  const GlassTitlePill({
    super.key,
    required this.title,
    this.maxWidth = 220,
  });

  final String title;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('glassTitlePill-$title'),
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
