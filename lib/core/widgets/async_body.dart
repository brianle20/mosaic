import 'package:flutter/material.dart';
import 'package:mosaic/widgets/empty_state_card.dart';

class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.isLoading,
    required this.child,
    this.error,
    this.onRetry,
  });

  final bool isLoading;
  final String? error;
  final Widget child;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading…',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyStateCard(
            icon: Icons.error_outline,
            title: 'Something needs attention',
            message: error!,
            action: onRetry == null
                ? null
                : FilledButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
          ),
        ),
      );
    }

    return child;
  }
}
