import 'package:flutter/material.dart';
import 'package:mosaic/core/config/app_environment.dart';
import 'package:mosaic/core/theme/app_theme.dart';

class MosaicApp extends StatelessWidget {
  const MosaicApp({
    super.key,
    this.environment,
    this.startupError,
  });

  final AppEnvironment? environment;
  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mosaic',
      theme: AppTheme.build(),
      home: startupError == null
          ? _BootstrapReadyScreen(environment: environment)
          : _StartupErrorScreen(message: startupError!),
    );
  }
}

class _BootstrapReadyScreen extends StatelessWidget {
  const _BootstrapReadyScreen({required this.environment});

  final AppEnvironment? environment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Mosaic',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Phase 1 foundation is bootstrapped for ${environment?.supabaseUrl.host ?? 'Supabase'}.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
