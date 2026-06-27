import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mosaic/core/config/app_environment.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/theme/app_theme.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/staff_models.dart';
import 'package:mosaic/data/offline/network_reachability.dart';
import 'package:mosaic/data/offline/offline_session_repository.dart';
import 'package:mosaic/data/offline/sqlite_offline_store.dart';
import 'package:mosaic/data/offline/sync_coordinator.dart';
import 'package:mosaic/data/repositories/offline_auth_repository.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/data/repositories/supabase_activity_repository.dart';
import 'package:mosaic/data/repositories/supabase_auth_repository.dart';
import 'package:mosaic/data/repositories/supabase_event_repository.dart';
import 'package:mosaic/data/repositories/supabase_guest_repository.dart';
import 'package:mosaic/data/repositories/supabase_hand_evidence_repository.dart';
import 'package:mosaic/data/repositories/supabase_leaderboard_repository.dart';
import 'package:mosaic/data/repositories/supabase_mosaic_profile_repository.dart';
import 'package:mosaic/data/repositories/supabase_prize_repository.dart';
import 'package:mosaic/data/repositories/supabase_seating_repository.dart';
import 'package:mosaic/data/repositories/supabase_session_repository.dart';
import 'package:mosaic/data/repositories/supabase_staff_repository.dart';
import 'package:mosaic/data/repositories/supabase_table_repository.dart';
import 'package:mosaic/data/supabase/supabase_bootstrap.dart';
import 'package:mosaic/features/auth/controllers/auth_controller.dart';
import 'package:mosaic/features/auth/screens/host_sign_in_screen.dart';
import 'package:mosaic/features/events/screens/event_list_screen.dart';
import 'package:mosaic/services/nfc/nfc_service_factory.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';
import 'package:mosaic/widgets/keyboard_dismiss_region.dart';

class MosaicApp extends StatefulWidget {
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
    this.activityRepository,
    this.prizeRepository,
    this.seatingRepository,
    this.mosaicProfileRepository,
    this.staffRepository,
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
  final ActivityRepository? activityRepository;
  final PrizeRepository? prizeRepository;
  final SeatingRepository? seatingRepository;
  final MosaicProfileRepository? mosaicProfileRepository;
  final StaffRepository? staffRepository;
  final NfcService? nfcService;

  @override
  State<MosaicApp> createState() => _MosaicAppState();
}

class _MosaicAppState extends State<MosaicApp> {
  Future<_LoadedRepositories>? _repositoriesFuture;
  _LoadedRepositories? _loadedRepositories;

  @override
  void initState() {
    super.initState();
    if (_needsDefaultRepositories(widget)) {
      _repositoriesFuture = _loadRepositories();
    }
  }

  @override
  void didUpdateWidget(covariant MosaicApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    final needsDefaultRepositories = _needsDefaultRepositories(widget);
    if (needsDefaultRepositories && _repositoriesFuture == null) {
      _repositoriesFuture = _loadRepositories();
    }
    if (!needsDefaultRepositories && _repositoriesFuture != null) {
      _repositoriesFuture = null;
      _disposeLoadedRepositories();
    }
  }

  @override
  void dispose() {
    _disposeLoadedRepositories();
    super.dispose();
  }

  bool _needsDefaultRepositories(MosaicApp app) {
    return app.startupError == null && !_hasInjectedRepositories(app);
  }

  bool _hasInjectedRepositories(MosaicApp app) {
    return app.authRepository != null &&
        app.eventRepository != null &&
        app.guestRepository != null &&
        app.tableRepository != null &&
        app.sessionRepository != null &&
        app.leaderboardRepository != null &&
        app.activityRepository != null &&
        app.prizeRepository != null &&
        app.seatingRepository != null &&
        app.mosaicProfileRepository != null &&
        app.nfcService != null;
  }

  void _disposeLoadedRepositories() {
    final loadedRepositories = _loadedRepositories;
    if (loadedRepositories == null) {
      return;
    }
    _loadedRepositories = null;
    unawaited(loadedRepositories.dispose());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.startupError != null) {
      return MaterialApp(
        title: 'Mosaic',
        theme: AppTheme.build(),
        builder: _buildKeyboardDismissRegion,
        home: _StartupErrorScreen(message: widget.startupError!),
      );
    }

    if (_hasInjectedRepositories(widget)) {
      return _AppWithRepositories(
        authRepository: widget.authRepository!,
        eventRepository: widget.eventRepository!,
        guestRepository: widget.guestRepository!,
        tableRepository: widget.tableRepository!,
        sessionRepository: widget.sessionRepository!,
        leaderboardRepository: widget.leaderboardRepository!,
        activityRepository: widget.activityRepository!,
        prizeRepository: widget.prizeRepository!,
        seatingRepository: widget.seatingRepository!,
        mosaicProfileRepository: widget.mosaicProfileRepository!,
        staffRepository:
            widget.staffRepository ?? const _UnavailableStaffRepository(),
        nfcService: widget.nfcService!,
      );
    }

    return FutureBuilder<_LoadedRepositories>(
      future: _repositoriesFuture ??= _loadRepositories(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            title: 'Mosaic',
            theme: AppTheme.build(),
            builder: _buildKeyboardDismissRegion,
            home: _StartupErrorScreen(message: snapshot.error.toString()),
          );
        }

        if (!snapshot.hasData) {
          return MaterialApp(
            title: 'Mosaic',
            theme: AppTheme.build(),
            builder: _buildKeyboardDismissRegion,
            home: _BootstrapLoadingScreen(environment: widget.environment),
          );
        }

        return _AppWithRepositories(
          authRepository: snapshot.data!.authRepository,
          eventRepository: snapshot.data!.eventRepository,
          guestRepository: snapshot.data!.guestRepository,
          tableRepository: snapshot.data!.tableRepository,
          sessionRepository: snapshot.data!.sessionRepository,
          leaderboardRepository: snapshot.data!.leaderboardRepository,
          activityRepository: snapshot.data!.activityRepository,
          prizeRepository: snapshot.data!.prizeRepository,
          seatingRepository: snapshot.data!.seatingRepository,
          mosaicProfileRepository: snapshot.data!.mosaicProfileRepository,
          staffRepository: snapshot.data!.staffRepository,
          nfcService: snapshot.data!.nfcService,
        );
      },
    );
  }

  Future<_LoadedRepositories> _loadRepositories() async {
    final cache = await LocalCache.create();
    final client = SupabaseBootstrap.client;
    final offlineStore = await SqliteOfflineStore.open();
    final reachability = DefaultNetworkReachability(client: client);
    final supabaseAuthRepository = SupabaseAuthRepository.fromClient(client);
    final supabaseSessionRepository = SupabaseSessionRepository(
      client: client,
      cache: cache,
    );
    final handEvidenceRepository = SupabaseHandEvidenceRepository(
      client: client,
    );
    late final SyncCoordinator syncCoordinator;
    final sessionRepository = OfflineSessionRepository(
      inner: supabaseSessionRepository,
      store: offlineStore,
      reachability: reachability,
      onMutationQueued: () => syncCoordinator.syncNow(),
    );
    syncCoordinator = SyncCoordinator(
      store: offlineStore,
      sessionRepository: supabaseSessionRepository,
      reachability: reachability,
      handEvidenceRepository: handEvidenceRepository,
    );

    final loadedRepositories = _LoadedRepositories(
      authRepository: OfflineAuthRepository(
        inner: supabaseAuthRepository,
        cache: cache,
        reachability: reachability,
      ),
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
      sessionRepository: sessionRepository,
      leaderboardRepository: SupabaseLeaderboardRepository(
        client: client,
        cache: cache,
      ),
      activityRepository: SupabaseActivityRepository(
        client: client,
        cache: cache,
      ),
      prizeRepository: SupabasePrizeRepository(
        client: client,
        cache: cache,
      ),
      seatingRepository: SupabaseSeatingRepository(
        client: client,
        cache: cache,
      ),
      mosaicProfileRepository: SupabaseMosaicProfileRepository(client: client),
      staffRepository: SupabaseStaffRepository(client: client),
      nfcService: createDefaultNfcService(),
      offlineStore: offlineStore,
    );

    if (!mounted) {
      await loadedRepositories.dispose();
      throw StateError('Mosaic app was disposed before startup completed.');
    }

    _loadedRepositories = loadedRepositories;
    unawaited(syncCoordinator.initialize().catchError((Object _) {}));
    return loadedRepositories;
  }
}

class _LoadedRepositories {
  const _LoadedRepositories({
    required this.authRepository,
    required this.eventRepository,
    required this.guestRepository,
    required this.tableRepository,
    required this.sessionRepository,
    required this.leaderboardRepository,
    required this.activityRepository,
    required this.prizeRepository,
    required this.seatingRepository,
    required this.mosaicProfileRepository,
    required this.staffRepository,
    required this.nfcService,
    required this.offlineStore,
  });

  final AuthRepository authRepository;
  final EventRepository eventRepository;
  final GuestRepository guestRepository;
  final TableRepository tableRepository;
  final SessionRepository sessionRepository;
  final LeaderboardRepository leaderboardRepository;
  final ActivityRepository activityRepository;
  final PrizeRepository prizeRepository;
  final SeatingRepository seatingRepository;
  final MosaicProfileRepository mosaicProfileRepository;
  final StaffRepository staffRepository;
  final NfcService nfcService;
  final SqliteOfflineStore? offlineStore;

  Future<void> dispose() async {
    await offlineStore?.close();
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
                'Preparing host tools...',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Connecting your event workspace and restoring the host session.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Workspace: ${environment?.supabaseUrl.host ?? 'Supabase'}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Unable to Start Mosaic',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Check the app configuration and try again.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
    required this.activityRepository,
    required this.prizeRepository,
    required this.seatingRepository,
    required this.mosaicProfileRepository,
    required this.staffRepository,
    required this.nfcService,
  });

  final AuthRepository authRepository;
  final EventRepository eventRepository;
  final GuestRepository guestRepository;
  final TableRepository tableRepository;
  final SessionRepository sessionRepository;
  final LeaderboardRepository leaderboardRepository;
  final ActivityRepository activityRepository;
  final PrizeRepository prizeRepository;
  final SeatingRepository seatingRepository;
  final MosaicProfileRepository mosaicProfileRepository;
  final StaffRepository staffRepository;
  final NfcService nfcService;

  @override
  Widget build(BuildContext context) {
    final router = AppRouter(
      eventRepository: eventRepository,
      guestRepository: guestRepository,
      tableRepository: tableRepository,
      sessionRepository: sessionRepository,
      leaderboardRepository: leaderboardRepository,
      activityRepository: activityRepository,
      prizeRepository: prizeRepository,
      seatingRepository: seatingRepository,
      mosaicProfileRepository: mosaicProfileRepository,
      staffRepository: staffRepository,
      nfcService: nfcService,
    );

    return MaterialApp(
      title: 'Mosaic',
      theme: AppTheme.build(),
      builder: _buildKeyboardDismissRegion,
      home: _AuthGate(
        authRepository: authRepository,
        eventRepository: eventRepository,
        guestRepository: guestRepository,
        tableRepository: tableRepository,
        sessionRepository: sessionRepository,
        leaderboardRepository: leaderboardRepository,
        activityRepository: activityRepository,
        prizeRepository: prizeRepository,
        seatingRepository: seatingRepository,
        staffRepository: staffRepository,
        nfcService: nfcService,
      ),
      onGenerateRoute: router.onGenerateRoute,
    );
  }
}

Widget _buildKeyboardDismissRegion(BuildContext context, Widget? child) {
  return KeyboardDismissRegion(
    child: child ?? const SizedBox.shrink(),
  );
}

class _UnavailableStaffRepository implements StaffRepository {
  const _UnavailableStaffRepository();

  @override
  Future<List<EventStaffMembershipRecord>> listEventStaff(String eventId) =>
      throw UnimplementedError();

  @override
  Future<EventStaffMembershipRecord> upsertEventStaff(
    UpsertEventStaffMembershipInput input,
  ) =>
      throw UnimplementedError();

  @override
  Future<EventStaffMembershipRecord> disableEventStaffMembership(
    String membershipId,
  ) =>
      throw UnimplementedError();
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({
    required this.authRepository,
    required this.eventRepository,
    required this.guestRepository,
    required this.tableRepository,
    required this.sessionRepository,
    required this.leaderboardRepository,
    required this.activityRepository,
    required this.prizeRepository,
    required this.seatingRepository,
    required this.staffRepository,
    required this.nfcService,
  });

  final AuthRepository authRepository;
  final EventRepository eventRepository;
  final GuestRepository guestRepository;
  final TableRepository tableRepository;
  final SessionRepository sessionRepository;
  final LeaderboardRepository leaderboardRepository;
  final ActivityRepository activityRepository;
  final PrizeRepository prizeRepository;
  final SeatingRepository seatingRepository;
  final StaffRepository staffRepository;
  final NfcService nfcService;

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
      accessState: _controller.currentAccess,
      onSignOut: _controller.signOut,
    );
  }
}
