import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/finals_state_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/screens/bonus_round_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

void main() {
  testWidgets('six-player setup shows reserved slots and two advancers',
      (tester) async {
    await _pumpSetup(
      tester,
      preview: _preview(
        count: 6,
        format: FinalsFormat.redemptionAdvancement,
        directSlots: 2,
        requiresRedemptionTable: true,
        redemptionPlayers: [_player(3), _player(4), _player(5), _player(6)],
        orderCopy: const [
          'Table of Redemption starts first.',
          'First and second place advance to Table of Champions.',
        ],
      ),
    );

    expect(find.text('Seed 1 — Reserved for Champions'), findsOneWidget);
    expect(find.text('Seed 2 — Reserved for Champions'), findsOneWidget);
    expect(find.text('Slot 3 — Redemption first place'), findsOneWidget);
    expect(find.text('Slot 4 — Redemption second place'), findsOneWidget);
    expect(
      find.text('First and second place advance to Table of Champions.'),
      findsOneWidget,
    );
    expect(find.text('Seed 3 · Player 3'), findsOneWidget);
  });

  testWidgets('seven-player setup shows three reserved slots and winner',
      (tester) async {
    await _pumpSetup(
      tester,
      preview: _preview(
        count: 7,
        format: FinalsFormat.redemptionAdvancement,
        directSlots: 3,
        requiresRedemptionTable: true,
        redemptionPlayers: [_player(4), _player(5), _player(6), _player(7)],
        orderCopy: const [
          'Table of Redemption starts first.',
          'The winner advances to Table of Champions.',
        ],
      ),
    );

    expect(find.text('Seed 1 — Reserved for Champions'), findsOneWidget);
    expect(find.text('Seed 2 — Reserved for Champions'), findsOneWidget);
    expect(find.text('Seed 3 — Reserved for Champions'), findsOneWidget);
    expect(find.text('Slot 4 — Redemption winner'), findsOneWidget);
    expect(
      find.text('The winner advances to Table of Champions.'),
      findsOneWidget,
    );
  });

  testWidgets('five-player setup shows automatic Redemption winner no table',
      (tester) async {
    await _pumpSetup(
      tester,
      preview: _preview(
        count: 5,
        format: FinalsFormat.automaticRedemption,
        redemptionPlayers: [_player(5)],
        orderCopy: const [
          'Seeds 1-4 start Table of Champions.',
          'Fifth place is the Redemption winner; no Redemption table is played.',
        ],
      ),
    );

    expect(find.text('5th place — Player 5'), findsOneWidget);
    expect(find.text('Redemption winner (no table)'), findsOneWidget);
    expect(find.text('Table of Redemption'), findsNothing);
    expect(find.byKey(const ValueKey('scanRedemptionTable')), findsNothing);
  });

  testWidgets('eight-plus setup says both tables start together',
      (tester) async {
    await _pumpSetup(
      tester,
      preview: _preview(
        count: 12,
        format: FinalsFormat.parallelFinals,
        requiresRedemptionTable: true,
        redemptionPlayers: [_player(9), _player(10), _player(11), _player(12)],
        orderCopy: const [
          'Table of Champions and Table of Redemption start together.',
        ],
      ),
    );

    expect(
      find.text('Table of Champions and Table of Redemption start together.'),
      findsOneWidget,
    );
    expect(find.text('Seeds 1-4 — Table of Champions'), findsOneWidget);
    expect(find.text('Seed 9 · Player 9'), findsOneWidget);
  });

  testWidgets('direct-cutoff tie copy names affected players', (tester) async {
    await _pumpSetup(
      tester,
      preview: _preview(
        count: 6,
        format: FinalsFormat.redemptionAdvancement,
        directSlots: 2,
        requiresRedemptionTable: true,
        cutoffTiePlayers: [_player(2), _player(3)],
        orderCopy: const ['Table of Redemption starts first.'],
      ),
    );

    expect(find.text('Direct qualification tiebreak'), findsOneWidget);
    expect(find.text('Player 2 and Player 3'), findsOneWidget);
    expect(
      find.text(
        'This tiebreak runs before the displayed Finals assignments become final.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('setup picker shows only authoritative ready-table candidates',
      (tester) async {
    await _pumpSetup(
      tester,
      preview: _preview(
        count: 4,
        format: FinalsFormat.championsOnly,
        availableTableIds: const ['ready'],
      ),
      tables: [
        _table('ready'),
        _table('busy'),
        _table('retired'),
        _table('retyped'),
        _table('tagless', hasTag: false),
      ],
    );

    await tester.tap(find.text('Choose Table'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Table ready'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Table busy'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Table retired'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Table retyped'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Table tagless'), findsNothing);
  });

  testWidgets('scanned setup table must be an authoritative candidate',
      (tester) async {
    await _pumpSetup(
      tester,
      preview: _preview(
        count: 4,
        format: FinalsFormat.championsOnly,
        availableTableIds: const ['ready'],
      ),
      tables: [_table('ready'), _table('busy')],
      nfcUids: ['tag_busy'],
    );

    await tester.tap(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.pumpAndSettle();

    expect(
      find.text('That table is not ready for Finals. Choose another table.'),
      findsOneWidget,
    );
    expect(find.text('Table busy'), findsNothing);
  });

  testWidgets('setup picker explains when no authoritative table is ready',
      (tester) async {
    await _pumpSetup(
      tester,
      preview: _preview(
        count: 4,
        format: FinalsFormat.championsOnly,
        availableTableIds: const [],
      ),
    );

    await tester.tap(find.text('Choose Table'));
    await tester.pumpAndSettle();

    expect(find.text('No ready tables'), findsOneWidget);
    expect(
      find.text(
        'Finish active play or bind an active table tag before beginning Finals.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Begin Finals'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('successful Begin Finals pops FinalsState and started copy',
      (tester) async {
    final state = _state();
    final finalsRepository = _FinalsRepository(
      _preview(count: 4, format: FinalsFormat.championsOnly),
      state: state,
    );

    await tester.pumpWidget(
      _Launcher(
        finalsRepository: finalsRepository,
        tableRepository: _TableRepository([_table('champions')]),
      ),
    );
    await tester.tap(find.text('Open Finals Setup'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Begin Finals'));
    await tester.pumpAndSettle();

    expect(finalsRepository.beginInputs, hasLength(1));
    expect(find.text('Finals tables started.'), findsOneWidget);
    expect(find.text('Finals seating created.'), findsNothing);
    expect(find.text('Returned Finals state 1'), findsOneWidget);
    expect(find.byType(BonusRoundScreen), findsNothing);
  });

  testWidgets('double tap sends one Begin Finals command', (tester) async {
    final finalsRepository = _FinalsRepository(
      _preview(count: 4, format: FinalsFormat.championsOnly),
    );
    await _pumpSetup(tester, repository: finalsRepository);
    await tester.tap(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Begin Finals');
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(finalsRepository.beginInputs, hasLength(1));
  });

  testWidgets('stale Begin error offers a visible preview refresh',
      (tester) async {
    final finalsRepository = _FinalsRepository(
      _preview(count: 4, format: FinalsFormat.championsOnly),
      beginError: StateError(
        'Finals changed since this screen was loaded. Refresh and try again.',
      ),
    );
    await _pumpSetup(tester, repository: finalsRepository);
    await tester.tap(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Begin Finals'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Finals changed since this screen was loaded. Refresh and try again.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('refreshFinalsPreview')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('refreshFinalsPreview')));
    await tester.pumpAndSettle();
    expect(finalsRepository.previewCalls, 2);
  });

  for (final message in const [
    'All Finals players must be checked in before starting.',
    'A Finals player is already playing at another table.',
  ]) {
    testWidgets('shows exact host-safe Begin error: $message', (tester) async {
      final repository = _FinalsRepository(
        _preview(count: 4, format: FinalsFormat.championsOnly),
        beginError: StateError(message),
      );
      await _pumpSetup(tester, repository: repository);
      await tester.tap(find.byKey(const ValueKey('scanChampionsTable')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Begin Finals'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(repository.beginInputs, hasLength(1));
    });
  }
}

Future<void> _pumpSetup(
  WidgetTester tester, {
  FinalsSetupPreview? preview,
  _FinalsRepository? repository,
  List<EventTableRecord>? tables,
  List<String>? nfcUids,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BonusRoundScreen(
        eventId: 'evt_01',
        finalsRepository: repository ?? _FinalsRepository(preview!),
        tableRepository: _TableRepository(
          tables ?? [_table('champions'), _table('redemption')],
        ),
        nfcService: _NfcService(
          nfcUids ?? ['tag_champions', 'tag_redemption'],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Launcher extends StatefulWidget {
  const _Launcher({
    required this.finalsRepository,
    required this.tableRepository,
  });

  final _FinalsRepository finalsRepository;
  final _TableRepository tableRepository;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  FinalsState? result;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (navigatorContext) => Scaffold(
          body: Column(
            children: [
              if (result case final state?)
                Text('Returned Finals state ${state.stateVersion}'),
              ElevatedButton(
                onPressed: () async {
                  final value =
                      await Navigator.of(navigatorContext).push<FinalsState>(
                    MaterialPageRoute(
                      builder: (_) => BonusRoundScreen(
                        eventId: 'evt_01',
                        finalsRepository: widget.finalsRepository,
                        tableRepository: widget.tableRepository,
                        nfcService: _NfcService(['tag_champions']),
                      ),
                    ),
                  );
                  if (mounted) setState(() => result = value);
                },
                child: const Text('Open Finals Setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

FinalsSetupPreview _preview({
  required int count,
  required FinalsFormat format,
  int directSlots = 4,
  bool requiresRedemptionTable = false,
  List<FinalsSetupPlayer> redemptionPlayers = const [],
  List<FinalsSetupPlayer> cutoffTiePlayers = const [],
  List<String> availableTableIds = const ['champions', 'redemption'],
  List<String> orderCopy = const ['Table of Champions starts immediately.'],
}) =>
    FinalsSetupPreview(
      previewToken: 'preview-token',
      eligiblePlayerCount: count,
      format: format,
      directSlots: directSlots,
      redemptionPlayers: redemptionPlayers,
      cutoffTiePlayers: cutoffTiePlayers,
      requiresChampionsTable: true,
      requiresRedemptionTable: requiresRedemptionTable,
      availableTableIds: availableTableIds,
      orderCopy: orderCopy,
    );

FinalsSetupPlayer _player(int seed) => FinalsSetupPlayer(
      eventGuestId: 'guest_$seed',
      displayName: 'Player $seed',
      seedRank: seed,
      totalPoints: 100 - seed,
    );

FinalsState _state() => FinalsState(
      flowVersion: FinalsFlowVersion.orchestrated,
      stateVersion: 1,
      format: FinalsFormat.championsOnly,
      overallStatus: FinalsOverallStatus.active,
      eligiblePlayerCount: 4,
      championsSlots: const [],
      contests: const [],
      allowedActions: const [],
      blockingReason: null,
      recoveryToken: null,
      champion: null,
      redemptionWinner: null,
      sessions: const [],
    );

EventTableRecord _table(String id, {bool hasTag = true}) => EventTableRecord(
      id: id,
      eventId: 'evt_01',
      label: 'Table $id',
      displayOrder: 1,
      nfcTagId: hasTag ? 'tag_$id' : null,
      defaultRulesetId: 'HK_STANDARD',
      defaultRotationPolicyType:
          RotationPolicyType.dealerCycleReturnToInitialEast,
      defaultRotationPolicyConfig: const {},
    );

class _NfcService implements NfcService {
  _NfcService(this.uids);
  final List<String> uids;

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) async {
    final uid = uids.removeAt(0);
    return TagScanResult(rawUid: uid, normalizedUid: uid, isManualEntry: true);
  }
}

class _FinalsRepository implements FinalsRepository {
  _FinalsRepository(this.preview, {FinalsState? state, this.beginError})
      : state = state ?? _state();

  final FinalsSetupPreview preview;
  final FinalsState state;
  final Object? beginError;
  final List<BeginFinalsInput> beginInputs = [];
  int previewCalls = 0;

  @override
  Future<FinalsSetupPreview> previewFinals(String eventId) async {
    previewCalls += 1;
    return preview;
  }

  @override
  Future<FinalsState> beginFinals(BeginFinalsInput input) async {
    beginInputs.add(input);
    if (beginError != null) throw beginError!;
    return state;
  }

  @override
  Future<FinalsState> loadFinalsState(String eventId) =>
      throw UnimplementedError();

  @override
  Future<FinalsState> resumeFinalsStart(ResumeFinalsStartInput input) =>
      throw UnimplementedError();

  @override
  Future<FinalsState> startContest(StartFinalsContestInput input) =>
      throw UnimplementedError();
}

class _TableRepository implements TableRepository {
  _TableRepository(this.tables);
  final List<EventTableRecord> tables;

  @override
  Future<List<EventTableRecord>> listTables(String eventId) async => tables;

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async =>
      tables;

  @override
  Future<EventTableRecord> resolveTableByTag({
    required String eventId,
    required String scannedUid,
  }) async =>
      tables.firstWhere((table) => table.nfcTagId == scannedUid);

  @override
  Future<EventTableRecord> bindTableTag({
    required String tableId,
    required String scannedUid,
    String? displayLabel,
  }) =>
      throw UnimplementedError();

  @override
  Future<EventTableRecord> createTable(CreateEventTableInput input) =>
      throw UnimplementedError();

  @override
  Future<EventTableRecord> updateTable(UpdateEventTableInput input) =>
      throw UnimplementedError();
}
