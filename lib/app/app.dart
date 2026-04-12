import 'package:flutter/material.dart';
import 'package:mosaic/core/config/app_environment.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/theme/app_theme.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/data/repositories/supabase_auth_repository.dart';
import 'package:mosaic/data/repositories/supabase_event_repository.dart';
import 'package:mosaic/data/repositories/supabase_guest_repository.dart';
import 'package:mosaic/data/repositories/supabase_leaderboard_repository.dart';
import 'package:mosaic/data/repositories/supabase_session_repository.dart';
import 'package:mosaic/data/repositories/supabase_table_repository.dart';
import 'package:mosaic/features/auth/controllers/auth_controller.dart';
import 'package:mosaic/features/auth/screens/host_sign_in_screen.dart';
import 'package:mosaic/features/events/screens/event_list_screen.dart';
import 'package:mosaic/services/nfc/manual_entry_nfc_service.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MosaicApp extends StatelessWidget {
  const MosaicApp({
    super.key,
    this.environment,
    this.startupError,
    this.authRepository,
    this.eventRepository,
    this.guestRepository,
    this.tableRepository,
    this.sessionRepository,
    this.leaderboardRepository,
    this.nfcService,
  });

  final AppEnvironment? environment;
  final String? startupError;
  final AuthRepository? authRepository;
  final EventRepository? eventRepository;
  final GuestRepository? guestRepository;
  final TableRepository? tableRepository;
  final SessionRepository? sessionRepository;
  final LeaderboardRepository? leaderboardRepository;
  final NfcService? nfcService;

  @override
  Widget build(BuildContext context) {
    if (startupError != null) {
      return MaterialApp(
        title: 'Mosaic',
        theme: AppTheme.build(),
        home: _StartupErrorScreen(message: startupError!),
      );
    }

    if (authRepository != null &&
        eventRepository != null &&
        guestRepository != null &&
        tableRepository != null &&
        sessionRepository != null &&
        leaderboardRepository != null &&
        nfcService != null) {
      return _AppWithRepositories(
        authRepository: authRepository!,
        eventRepository: eventRepository!,
        guestRepository: guestRepository!,
        tableRepository: tableRepository!,
        sessionRepository: sessionRepository!,
        leaderboardRepository: leaderboardRepository!,
        nfcService: nfcService!,
      );
    }

    return FutureBuilder<
        ({
          AuthRepository authRepository,
          EventRepository eventRepository,
          GuestRepository guestRepository,
          TableRepository tableRepository,
          SessionRepository sessionRepository,
          LeaderboardRepository leaderboardRepository,
          NfcService nfcService,
        })>(
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
          authRepository: snapshot.data!.authRepository,
          eventRepository: snapshot.data!.eventRepository,
          guestRepository: snapshot.data!.guestRepository,
          tableRepository: snapshot.data!.tableRepository,
          sessionRepository: snapshot.data!.sessionRepository,
          leaderboardRepository: snapshot.data!.leaderboardRepository,
          nfcService: snapshot.data!.nfcService,
        );
      },
    );
  }

  Future<
      ({
        AuthRepository authRepository,
        EventRepository eventRepository,
        GuestRepository guestRepository,
        TableRepository tableRepository,
        SessionRepository sessionRepository,
        LeaderboardRepository leaderboardRepository,
        NfcService nfcService,
      })> _loadRepositories() async {
    final cache = await LocalCache.create();
    final client = Supabase.instance.client;
    return (
      authRepository: SupabaseAuthRepository.fromClient(client),
      eventRepository: SupabaseEventRepository(
        client: client,
        cache: cache,
      ),
      guestRepository: SupabaseGuestRepository(
        client: client,
        cache: cache,
      ),
      tableRepository: SupabaseTableRepository(
        client: client,
        cache: cache,
      ),
      sessionRepository: SupabaseSessionRepository(
        client: client,
        cache: cache,
      ),
      leaderboardRepository: SupabaseLeaderboardRepository(
        client: client,
        cache: cache,
      ),
      nfcService: const ManualEntryNfcService(),
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
    required this.authRepository,
    required this.eventRepository,
    required this.guestRepository,
    required this.tableRepository,
    required this.sessionRepository,
    required this.leaderboardRepository,
    required this.nfcService,
  });

  final AuthRepository authRepository;
  final EventRepository eventRepository;
  final GuestRepository guestRepository;
  final TableRepository tableRepository;
  final SessionRepository sessionRepository;
  final LeaderboardRepository leaderboardRepository;
  final NfcService nfcService;

  @override
  Widget build(BuildContext context) {
    final router = AppRouter(
      eventRepository: eventRepository,
      guestRepository: guestRepository,
      tableRepository: tableRepository,
      sessionRepository: sessionRepository,
      leaderboardRepository: leaderboardRepository,
      nfcService: nfcService,
    );

    return MaterialApp(
      title: 'Mosaic',
      theme: AppTheme.build(),
      home: _AuthGate(
        authRepository: authRepository,
        eventRepository: eventRepository,
        guestRepository: guestRepository,
      ),
      onGenerateRoute: router.onGenerateRoute,
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({
    required this.authRepository,
    required this.eventRepository,
    required this.guestRepository,
  });

  final AuthRepository authRepository;
  final EventRepository eventRepository;
  final GuestRepository guestRepository;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final AuthController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AuthController(authRepository: widget.authRepository)
      ..addListener(_handleUpdate)
      ..bootstrap();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleUpdate)
      ..dispose();
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isBootstrapping) {
      return _BootstrapLoadingScreen(environment: null);
    }

    if (!_controller.isSignedIn) {
      return HostSignInScreen(authController: _controller);
    }

    return EventListScreen(
      eventRepository: widget.eventRepository,
      onSignOut: _controller.signOut,
    );
  }
}
