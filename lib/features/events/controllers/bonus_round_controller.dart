import 'package:flutter/foundation.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
import 'package:mosaic/data/models/finals_state_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/models/finals_setup_view_models.dart';

enum BonusRoundTableRole { champions, redemption }

class BonusRoundController extends ChangeNotifier {
  BonusRoundController({
    required FinalsRepository finalsRepository,
    required TableRepository tableRepository,
  })  : _finalsRepository = finalsRepository,
        _tableRepository = tableRepository;

  final FinalsRepository _finalsRepository;
  final TableRepository _tableRepository;

  bool isLoading = true;
  bool isSubmitting = false;
  bool isResolvingTable = false;
  String? error;
  String? actionError;
  FinalsSetupPreview? preview;
  List<EventTableRecord> tables = const [];
  EventTableRecord? championsTable;
  EventTableRecord? redemptionTable;
  int _requestGeneration = 0;
  bool _isDisposed = false;

  FinalsSetupViewModel get setup => preview == null
      ? FinalsSetupViewModel(
          formatTitle: 'Finals setup',
          orderCopy: const [],
          championsRows: const [],
          redemptionRows: const [],
          automaticRedemptionPlayer: null,
          cutoffTiePlayerNames: const [],
        )
      : FinalsSetupViewModel.fromPreview(preview!);

  bool get championsRequired => preview?.requiresChampionsTable ?? false;
  bool get redemptionRequired => preview?.requiresRedemptionTable ?? false;

  List<EventTableRecord> get readyTables {
    final availableTableIds = preview?.availableTableIds.toSet() ?? const {};
    return tables
        .where((table) => availableTableIds.contains(table.id))
        .toList(growable: false);
  }

  bool get canBeginFinals {
    final loadedPreview = preview;
    if (loadedPreview == null || loadedPreview.format == null) return false;
    final readyTableIds = readyTables.map((table) => table.id).toSet();
    if (championsRequired && !readyTableIds.contains(championsTable?.id)) {
      return false;
    }
    if (redemptionRequired && !readyTableIds.contains(redemptionTable?.id)) {
      return false;
    }
    return championsTable?.id != redemptionTable?.id;
  }

  Future<void> load(String eventId, {bool silent = false}) async {
    final generation = ++_requestGeneration;
    if (!silent) isLoading = true;
    error = null;
    actionError = null;

    final cachedTables = await _tableRepository.readCachedTables(eventId);
    if (!_isCurrent(generation)) return;
    if (!silent || cachedTables.isNotEmpty || tables.isEmpty) {
      tables = cachedTables;
    }
    _notifyIfActive();

    try {
      final loadedPreview = await _finalsRepository.previewFinals(eventId);
      if (!_isCurrent(generation)) return;
      final loadedTables = await _tableRepository.listTables(eventId);
      if (!_isCurrent(generation)) return;
      preview = loadedPreview;
      tables = loadedTables;
      _clearUnavailableSelections();
    } catch (exception) {
      if (_isCurrent(generation) && (!silent || preview == null)) {
        error = userFacingError(
          exception,
          fallback: 'Unable to load Finals setup.',
        );
      }
    }

    if (_isCurrent(generation)) {
      isLoading = false;
      _notifyIfActive();
    }
  }

  void selectTable({
    required BonusRoundTableRole role,
    required EventTableRecord table,
  }) {
    actionError = null;
    if (!readyTables.any((readyTable) => readyTable.id == table.id)) {
      actionError = 'That table is not ready for Finals. Choose another table.';
      _notifyIfActive();
      return;
    }
    switch (role) {
      case BonusRoundTableRole.champions:
        championsTable = table;
        if (redemptionTable?.id == table.id) redemptionTable = null;
      case BonusRoundTableRole.redemption:
        redemptionTable = table;
        if (championsTable?.id == table.id) championsTable = null;
    }
    _notifyIfActive();
  }

  Future<void> resolveScannedTable({
    required String eventId,
    required BonusRoundTableRole role,
    required String normalizedUid,
  }) async {
    if (isResolvingTable) return;
    isResolvingTable = true;
    actionError = null;
    _notifyIfActive();
    try {
      final table = await _tableRepository.resolveTableByTag(
        eventId: eventId,
        scannedUid: normalizedUid,
      );
      selectTable(role: role, table: table);
    } catch (exception) {
      actionError = userFacingError(exception);
    } finally {
      isResolvingTable = false;
      _notifyIfActive();
    }
  }

  Future<FinalsState?> beginFinals(String eventId) async {
    if (!canBeginFinals || isSubmitting) return null;
    isSubmitting = true;
    actionError = null;
    _notifyIfActive();
    try {
      return await _finalsRepository.beginFinals(
        BeginFinalsInput(
          eventId: eventId,
          championsTableId: championsTable!.id,
          redemptionTableId: redemptionTable?.id,
          expectedStateVersion: null,
          expectedPreviewToken: preview!.previewToken,
        ),
      );
    } catch (exception) {
      actionError = userFacingError(exception);
      return null;
    } finally {
      isSubmitting = false;
      _notifyIfActive();
    }
  }

  void _clearUnavailableSelections() {
    final ids = readyTables.map((table) => table.id).toSet();
    if (!ids.contains(championsTable?.id)) championsTable = null;
    if (!ids.contains(redemptionTable?.id)) redemptionTable = null;
    if (!championsRequired) championsTable = null;
    if (!redemptionRequired) redemptionTable = null;
  }

  bool _isCurrent(int generation) =>
      !_isDisposed && generation == _requestGeneration;

  void _notifyIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestGeneration += 1;
    super.dispose();
  }
}
