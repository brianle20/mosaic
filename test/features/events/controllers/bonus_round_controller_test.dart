import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/finals_state_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/bonus_round_controller.dart';

void main() {
  for (final testCase in <({
    String name,
    FinalsSetupPreview preview,
    bool championsRequired,
    bool redemptionRequired,
  })>[
    (
      name: 'champions-only',
      preview: _preview(count: 4, format: FinalsFormat.championsOnly),
      championsRequired: true,
      redemptionRequired: false,
    ),
    (
      name: 'automatic redemption',
      preview: _preview(
        count: 5,
        format: FinalsFormat.automaticRedemption,
        redemptionPlayers: [_player(5)],
      ),
      championsRequired: true,
      redemptionRequired: false,
    ),
    (
      name: 'redemption advancement',
      preview: _preview(
        count: 6,
        format: FinalsFormat.redemptionAdvancement,
        directSlots: 2,
        requiresRedemptionTable: true,
        redemptionPlayers: [_player(3), _player(4), _player(5), _player(6)],
      ),
      championsRequired: true,
      redemptionRequired: true,
    ),
    (
      name: 'parallel finals',
      preview: _preview(
        count: 8,
        format: FinalsFormat.parallelFinals,
        requiresRedemptionTable: true,
        redemptionPlayers: [_player(5), _player(6), _player(7), _player(8)],
      ),
      championsRequired: true,
      redemptionRequired: true,
    ),
  ]) {
    test('loads authoritative ${testCase.name} preview and required selectors',
        () async {
      final finalsRepository = _FinalsRepository(testCase.preview);
      final controller = BonusRoundController(
        finalsRepository: finalsRepository,
        tableRepository: _TableRepository([_table('champions')]),
      );

      await controller.load('evt_01');

      expect(finalsRepository.previewCalls, ['evt_01']);
      expect(controller.preview, same(testCase.preview));
      expect(controller.championsRequired, testCase.championsRequired);
      expect(controller.redemptionRequired, testCase.redemptionRequired);
    });
  }

  test('uses authoritative cutoff tie players and order copy', () async {
    final preview = _preview(
      count: 6,
      format: FinalsFormat.redemptionAdvancement,
      directSlots: 2,
      requiresRedemptionTable: true,
      cutoffTiePlayers: [_player(2), _player(3)],
      orderCopy: const [
        'A standings tiebreak runs before the Finals tables are finalized.',
      ],
    );
    final controller = BonusRoundController(
      finalsRepository: _FinalsRepository(preview),
      tableRepository: _TableRepository([_table('champions')]),
    );

    await controller.load('evt_01');

    expect(controller.preview?.cutoffTiePlayers, preview.cutoffTiePlayers);
    expect(controller.setup.orderCopy, preview.orderCopy);
    expect(controller.setup.cutoffTiePlayerNames, ['Player 2', 'Player 3']);
  });

  test('intersects loaded tables with authoritative preview candidates',
      () async {
    final controller = BonusRoundController(
      finalsRepository: _FinalsRepository(
        _preview(
          count: 4,
          format: FinalsFormat.championsOnly,
          availableTableIds: const ['ready'],
        ),
      ),
      tableRepository: _TableRepository([
        _table('ready'),
        _table('busy'),
        _table('retired'),
        _table('retyped'),
        _table('tagless', hasTag: false),
      ]),
    );

    await controller.load('evt_01');

    expect(controller.readyTables.map((table) => table.id), ['ready']);
  });

  test('rejects a scanned table outside authoritative preview candidates',
      () async {
    final controller = BonusRoundController(
      finalsRepository: _FinalsRepository(
        _preview(
          count: 4,
          format: FinalsFormat.championsOnly,
          availableTableIds: const ['ready'],
        ),
      ),
      tableRepository: _TableRepository([_table('ready'), _table('busy')]),
    );
    await controller.load('evt_01');

    await controller.resolveScannedTable(
      eventId: 'evt_01',
      role: BonusRoundTableRole.champions,
      normalizedUid: 'tag_busy',
    );

    expect(controller.championsTable, isNull);
    expect(
      controller.actionError,
      'That table is not ready for Finals. Choose another table.',
    );
  });

  test('no authoritative table candidate keeps setup blocked', () async {
    final controller = BonusRoundController(
      finalsRepository: _FinalsRepository(
        _preview(
          count: 4,
          format: FinalsFormat.championsOnly,
          availableTableIds: const [],
        ),
      ),
      tableRepository: _TableRepository([_table('loaded')]),
    );

    await controller.load('evt_01');

    expect(controller.readyTables, isEmpty);
    expect(controller.canBeginFinals, isFalse);
  });

  test('requires only selectors described by the preview', () async {
    final controller = BonusRoundController(
      finalsRepository: _FinalsRepository(
        _preview(
          count: 5,
          format: FinalsFormat.automaticRedemption,
          redemptionPlayers: [_player(5)],
        ),
      ),
      tableRepository: _TableRepository([_table('champions')]),
    );
    await controller.load('evt_01');

    expect(controller.canBeginFinals, isFalse);
    controller.selectTable(
      role: BonusRoundTableRole.champions,
      table: _table('champions'),
    );

    expect(controller.canBeginFinals, isTrue);
    expect(controller.redemptionRequired, isFalse);
  });

  test('requires different Champions and Redemption tables', () async {
    final controller = BonusRoundController(
      finalsRepository: _FinalsRepository(
        _preview(
          count: 8,
          format: FinalsFormat.parallelFinals,
          requiresRedemptionTable: true,
          availableTableIds: const ['one', 'two'],
        ),
      ),
      tableRepository: _TableRepository([_table('one'), _table('two')]),
    );
    await controller.load('evt_01');

    controller.selectTable(
      role: BonusRoundTableRole.champions,
      table: _table('one'),
    );
    controller.selectTable(
      role: BonusRoundTableRole.redemption,
      table: _table('one'),
    );

    expect(controller.championsTable, isNull);
    expect(controller.redemptionTable?.id, 'one');
    expect(controller.canBeginFinals, isFalse);
  });

  test('begin finals invokes exactly one authoritative mutation', () async {
    final finalsRepository = _FinalsRepository(
      _preview(
        count: 8,
        format: FinalsFormat.parallelFinals,
        requiresRedemptionTable: true,
        availableTableIds: const ['champions', 'redeem'],
      ),
      result: _state(),
    );
    final controller = BonusRoundController(
      finalsRepository: finalsRepository,
      tableRepository:
          _TableRepository([_table('champions'), _table('redeem')]),
    );
    await controller.load('evt_01');
    controller
      ..selectTable(
        role: BonusRoundTableRole.champions,
        table: _table('champions'),
      )
      ..selectTable(
        role: BonusRoundTableRole.redemption,
        table: _table('redeem'),
      );

    final result = await controller.beginFinals('evt_01');

    expect(result, same(finalsRepository.result));
    expect(finalsRepository.beginInputs, hasLength(1));
    final input = finalsRepository.beginInputs.single;
    expect(input.eventId, 'evt_01');
    expect(input.championsTableId, 'champions');
    expect(input.redemptionTableId, 'redeem');
    expect(input.expectedStateVersion, isNull);
    expect(input.expectedPreviewToken, 'preview-token');
  });

  test('does not add a client global-session guard', () async {
    final finalsRepository = _FinalsRepository(
      _preview(count: 4, format: FinalsFormat.championsOnly),
      result: _state(),
    );
    final controller = BonusRoundController(
      finalsRepository: finalsRepository,
      tableRepository: _TableRepository([_table('champions')]),
    );
    await controller.load('evt_01');
    controller.selectTable(
      role: BonusRoundTableRole.champions,
      table: _table('champions'),
    );

    expect(await controller.beginFinals('evt_01'), isNotNull);
    expect(finalsRepository.beginInputs, hasLength(1));
  });

  test('stale command errors remain actionable and preserve preview', () async {
    final preview = _preview(count: 4, format: FinalsFormat.championsOnly);
    final finalsRepository = _FinalsRepository(
      preview,
      beginError: StateError(
        'Finals changed since this screen loaded. Refresh and try again.',
      ),
    );
    final controller = BonusRoundController(
      finalsRepository: finalsRepository,
      tableRepository: _TableRepository([_table('champions')]),
    );
    await controller.load('evt_01');
    controller.selectTable(
      role: BonusRoundTableRole.champions,
      table: _table('champions'),
    );

    expect(await controller.beginFinals('evt_01'), isNull);
    expect(controller.preview, same(preview));
    expect(
      controller.actionError,
      'Finals changed since this screen loaded. Refresh and try again.',
    );
  });

  for (final message in const [
    'All Finals players must be checked in before starting.',
    'A Finals player is already playing at another table.',
  ]) {
    test('preserves host-safe Begin error: $message', () async {
      final preview = _preview(count: 4, format: FinalsFormat.championsOnly);
      final controller = BonusRoundController(
        finalsRepository: _FinalsRepository(
          preview,
          beginError: StateError(message),
        ),
        tableRepository: _TableRepository([_table('champions')]),
      );
      await controller.load('evt_01');
      controller.selectTable(
        role: BonusRoundTableRole.champions,
        table: _table('champions'),
      );

      expect(await controller.beginFinals('evt_01'), isNull);
      expect(controller.actionError, message);
    });
  }

  test('duplicate taps share one in-flight command', () async {
    final completer = Completer<FinalsState>();
    final finalsRepository = _FinalsRepository(
      _preview(count: 4, format: FinalsFormat.championsOnly),
      beginFuture: completer.future,
    );
    final controller = BonusRoundController(
      finalsRepository: finalsRepository,
      tableRepository: _TableRepository([_table('champions')]),
    );
    await controller.load('evt_01');
    controller.selectTable(
      role: BonusRoundTableRole.champions,
      table: _table('champions'),
    );

    final first = controller.beginFinals('evt_01');
    final second = controller.beginFinals('evt_01');
    expect(finalsRepository.beginInputs, hasLength(1));
    expect(controller.isSubmitting, isTrue);

    completer.complete(_state());
    expect(await first, isNotNull);
    expect(await second, isNull);
    expect(controller.isSubmitting, isFalse);
  });

  test('silent refresh keeps usable preview and tables on failure', () async {
    final preview = _preview(count: 4, format: FinalsFormat.championsOnly);
    final finalsRepository = _FinalsRepository(preview);
    final tableRepository = _TableRepository([_table('champions')]);
    final controller = BonusRoundController(
      finalsRepository: finalsRepository,
      tableRepository: tableRepository,
    );
    await controller.load('evt_01');
    controller.selectTable(
      role: BonusRoundTableRole.champions,
      table: tableRepository.tables.single,
    );

    finalsRepository.previewError = StateError('offline');
    tableRepository.listError = StateError('offline');
    await controller.load('evt_01', silent: true);

    expect(controller.preview, same(preview));
    expect(controller.tables, hasLength(1));
    expect(controller.championsTable?.id, 'champions');
    expect(controller.error, isNull);
  });

  test('refresh clears a table selection no longer required by the preview',
      () async {
    final finalsRepository = _FinalsRepository(
      _preview(
        count: 6,
        format: FinalsFormat.redemptionAdvancement,
        requiresRedemptionTable: true,
      ),
    );
    final controller = BonusRoundController(
      finalsRepository: finalsRepository,
      tableRepository: _TableRepository([
        _table('champions'),
        _table('redemption'),
      ]),
    );
    await controller.load('evt_01');
    controller
      ..selectTable(
        role: BonusRoundTableRole.champions,
        table: _table('champions'),
      )
      ..selectTable(
        role: BonusRoundTableRole.redemption,
        table: _table('redemption'),
      );

    finalsRepository.preview = _preview(
      count: 5,
      format: FinalsFormat.automaticRedemption,
      redemptionPlayers: [_player(5)],
    );
    await controller.load('evt_01', silent: true);

    expect(controller.redemptionRequired, isFalse);
    expect(controller.redemptionTable, isNull);
    expect(await controller.beginFinals('evt_01'), isNotNull);
    expect(finalsRepository.beginInputs.single.redemptionTableId, isNull);
  });
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
}) {
  return FinalsSetupPreview(
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
}

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

class _FinalsRepository implements FinalsRepository {
  _FinalsRepository(
    this.preview, {
    this.result,
    this.beginFuture,
    this.beginError,
  });

  FinalsSetupPreview preview;
  final FinalsState? result;
  final Future<FinalsState>? beginFuture;
  final Object? beginError;
  Object? previewError;
  final List<String> previewCalls = [];
  final List<BeginFinalsInput> beginInputs = [];

  @override
  Future<FinalsSetupPreview> previewFinals(String eventId) async {
    previewCalls.add(eventId);
    if (previewError != null) throw previewError!;
    return preview;
  }

  @override
  Future<FinalsState> beginFinals(BeginFinalsInput input) {
    beginInputs.add(input);
    if (beginError != null) throw beginError!;
    return beginFuture ?? Future.value(result ?? _state());
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
  Object? listError;

  @override
  Future<List<EventTableRecord>> listTables(String eventId) async {
    if (listError != null) throw listError!;
    return tables;
  }

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
