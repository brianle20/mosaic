import 'package:flutter/material.dart';
import 'package:mosaic/core/config/app_environment.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/theme/app_theme.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/data/repositories/supabase_event_repository.dart';
import 'package:mosaic/data/repositories/supabase_guest_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MosaicApp extends StatelessWidget {
  const MosaicApp({
    super.key,
    this.environment,
    this.startupError,
    this.eventRepository,
    this.guestRepository,
  });

  final AppEnvironment? environment;
  final String? startupError;
  final EventRepository? eventRepository;
  final GuestRepository? guestRepository;

  @override
  Widget build(BuildContext context) {
    if (startupError != null) {
      return MaterialApp(
        title: 'Mosaic',
        theme: AppTheme.build(),
        home: _StartupErrorScreen(message: startupError!),
      );
    }

    if (eventRepository != null && guestRepository != null) {
      return _AppWithRepositories(
        eventRepository: eventRepository!,
        guestRepository: guestRepository!,
      );
    }

    return FutureBuilder<
        ({EventRepository eventRepository, GuestRepository guestRepository})>(
      future: _loadRepositories(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            title: 'Mosaic',
            theme: AppTheme.build(),
            home: _StartupErrorScreen(message: snapshot.error.toString()),
          );
        }

        if (!snapshot.hasData) {
          return MaterialApp(
            title: 'Mosaic',
            theme: AppTheme.build(),
            home: _BootstrapLoadingScreen(environment: environment),
          );
        }

        return _AppWithRepositories(
          eventRepository: snapshot.data!.eventRepository,
          guestRepository: snapshot.data!.guestRepository,
        );
      },
    );
  }

  Future<({EventRepository eventRepository, GuestRepository guestRepository})>
      _loadRepositories() async {
    final cache = await LocalCache.create();
    final client = Supabase.instance.client;
    return (
      eventRepository: SupabaseEventRepository(
        client: client,
        cache: cache,
      ),
      guestRepository: SupabaseGuestRepository(
        client: client,
        cache: cache,
      ),
    );
  }
}

class _BootstrapLoadingScreen extends StatelessWidget {
  const _BootstrapLoadingScreen({required this.environment});

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
                'Connecting to ${environment?.supabaseUrl.host ?? 'Supabase'}...',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
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

class _AppWithRepositories extends StatelessWidget {
  const _AppWithRepositories({
    required this.eventRepository,
    required this.guestRepository,
  });

  final EventRepository eventRepository;
  final GuestRepository guestRepository;

  @override
  Widget build(BuildContext context) {
    final router = AppRouter(
      eventRepository: eventRepository,
      guestRepository: guestRepository,
    );

    return MaterialApp(
      title: 'Mosaic',
      theme: AppTheme.build(),
      initialRoute: AppRouter.eventListRoute,
      onGenerateRoute: router.onGenerateRoute,
    );
  }
}
