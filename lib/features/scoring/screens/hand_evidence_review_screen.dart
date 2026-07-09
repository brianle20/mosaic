import 'package:flutter/material.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/models/hand_tile_entry_draft.dart';
import 'package:mosaic/features/scoring/models/hand_tile_fan_calculator.dart';
import 'package:mosaic/features/scoring/models/mahjong_tile.dart';
import 'package:mosaic/features/scoring/widgets/hand_photo_preview.dart';
import 'package:mosaic/features/scoring/widgets/tile_keyboard.dart';
import 'package:mosaic/widgets/app_chrome.dart';
import 'package:mosaic/widgets/app_surfaces.dart';
import 'package:mosaic/widgets/empty_state_card.dart';

class HandEvidenceReviewScreen extends StatefulWidget {
  const HandEvidenceReviewScreen({
    super.key,
    required this.eventId,
    required this.mosaicProfileRepository,
    this.handLedgerLoader,
  });

  final String eventId;
  final MosaicProfileRepository mosaicProfileRepository;
  final Future<List<EventHandLedgerEntry>> Function(String eventId)?
      handLedgerLoader;

  @override
  State<HandEvidenceReviewScreen> createState() =>
      _HandEvidenceReviewScreenState();
}

class _HandEvidenceReviewScreenState extends State<HandEvidenceReviewScreen> {
  var _records = <HandEvidenceReviewRecord>[];
  var _ledgerEntriesByHandId = <String, EventHandLedgerEntry>{};
  HandEvidenceReviewRecord? _selectedRecord;
  HandTileEntryDraft _tileDraft = HandTileEntryDraft();
  HandTileEntryDraft _baselineTileDraft = HandTileEntryDraft();
  var _isLoading = true;
  Object? _loadError;
  var _isSaving = false;
  var _hasSavedCurrentDraft = false;
  var _statusFilter = _HandEvidenceStatusFilter.missingTiles;
  String? _saveError;
  Uri? _photoUri;
  Object? _photoError;
  var _isPhotoLoading = false;
  var _photoRequestToken = 0;
  final _editorRevision = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _loadReviewRecords();
  }

  @override
  void dispose() {
    _editorRevision.dispose();
    super.dispose();
  }

  Future<void> _loadReviewRecords() async {
    setState(() {
      _isLoading = true;
      _hasSavedCurrentDraft = false;
      _loadError = null;
      _saveError = null;
      _photoUri = null;
      _photoError = null;
      _isPhotoLoading = false;
    });
    _photoRequestToken++;

    try {
      final ledgerEntriesFuture = _loadLedgerEntries();
      final records = await widget.mosaicProfileRepository
          .listHandEvidenceReview(widget.eventId);
      final ledgerEntries = await ledgerEntriesFuture;
      if (!mounted) {
        return;
      }

      setState(() {
        _records = records;
        _ledgerEntriesByHandId = _ledgerEntriesByHandIdFrom(ledgerEntries);
        _selectedRecord = null;
        _tileDraft = HandTileEntryDraft();
        _baselineTileDraft = HandTileEntryDraft();
        _isLoading = false;
        _hasSavedCurrentDraft = false;
        _photoUri = null;
        _photoError = null;
        _isPhotoLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _records = [];
        _ledgerEntriesByHandId = {};
        _selectedRecord = null;
        _tileDraft = HandTileEntryDraft();
        _baselineTileDraft = HandTileEntryDraft();
        _isLoading = false;
        _hasSavedCurrentDraft = false;
        _loadError = error;
        _photoUri = null;
        _photoError = null;
        _isPhotoLoading = false;
      });
    }
  }

  Future<List<EventHandLedgerEntry>> _loadLedgerEntries() async {
    final loader = widget.handLedgerLoader;
    if (loader == null) {
      return const [];
    }

    try {
      return await loader(widget.eventId);
    } catch (_) {
      return const [];
    }
  }

  void _selectRecord(HandEvidenceReviewRecord record) {
    if (_isSaving) {
      return;
    }

    final selectedDraft =
        _draftFromTileEntry(record.tileEntry) ?? HandTileEntryDraft();
    setState(() {
      _selectedRecord = record;
      _tileDraft = selectedDraft;
      _baselineTileDraft = selectedDraft;
      _hasSavedCurrentDraft = false;
      _saveError = null;
      _photoUri = null;
      _photoError = null;
      _isPhotoLoading = true;
    });
    _notifyEditorChanged();
    _loadPhotoForRecord(record);
  }

  void _notifyEditorChanged() {
    _editorRevision.value += 1;
  }

  bool get _hasUnsavedTileChanges =>
      !_tileDraft.hasSameEditableContentAs(_baselineTileDraft);

  Future<void> _openMobileEditor(
    HandEvidenceReviewRecord record,
    int queuePosition,
  ) async {
    _selectRecord(record);
    if (!mounted || _selectedRecord?.handResultId != record.handResultId) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return ValueListenableBuilder<int>(
            valueListenable: _editorRevision,
            builder: (context, _, __) {
              final selectedRecord = _selectedRecord ?? record;
              final selectedPosition = _selectedRecordPosition ?? queuePosition;
              final selectedLedgerEntry =
                  _ledgerEntriesByHandId[selectedRecord.handResultId];
              return SoftHostScaffold(
                title: _reviewTitle(
                  selectedRecord,
                  ledgerEntry: selectedLedgerEntry,
                  queuePosition: selectedPosition,
                ),
                showBackButton: true,
                compactTitle: true,
                contentPadding: const EdgeInsets.fromLTRB(10, 46, 10, 8),
                body: _buildEditor(returnAfterSave: true),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _loadPhotoForRecord(HandEvidenceReviewRecord record) async {
    final requestToken = ++_photoRequestToken;
    try {
      final uri = await widget.mosaicProfileRepository
          .createHandPhotoSignedUrl(record.photo);
      if (!mounted || requestToken != _photoRequestToken) {
        return;
      }

      setState(() {
        _photoUri = uri;
        _photoError = null;
        _isPhotoLoading = false;
      });
      _notifyEditorChanged();
    } catch (error) {
      if (!mounted || requestToken != _photoRequestToken) {
        return;
      }

      setState(() {
        _photoUri = null;
        _photoError = error;
        _isPhotoLoading = false;
      });
      _notifyEditorChanged();
    }
  }

  Future<void> _saveTiles({bool returnAfterSave = false}) async {
    final record = _selectedRecord;
    if (record == null || _isSaving) {
      return;
    }

    if (!_hasUnsavedTileChanges) {
      return;
    }

    final review = _currentReviewFor(record);
    if (!review.canSave) {
      setState(() {
        _saveError = review.isComplete
            ? 'This tile selection is not a valid winning hand.'
            : 'Select 14 core tiles before saving.';
      });
      _notifyEditorChanged();
      return;
    }

    setState(() {
      _isSaving = true;
      _hasSavedCurrentDraft = false;
      _saveError = null;
    });
    _notifyEditorChanged();

    try {
      final savedEntry =
          await widget.mosaicProfileRepository.upsertHandTileEntry(
        handResultId: record.handResultId,
        tilesJson: _tileDraft.toJson(groups: review.grouping.toJson()),
        calculatedFanCount: review.calculatedFanCount,
        reviewStatus: review.reviewStatus,
        calculationVersion: handTileCalculationVersion,
      );
      final updatedRecord = _withTileEntry(record, savedEntry);
      final updatedRecords = [
        for (final queuedRecord in _records)
          if (queuedRecord.handResultId == record.handResultId)
            updatedRecord
          else
            queuedRecord,
      ];

      if (!mounted) {
        return;
      }

      setState(() {
        _records = updatedRecords;
        _selectedRecord = updatedRecord;
        _baselineTileDraft = _tileDraft;
        _isSaving = false;
        _hasSavedCurrentDraft = true;
      });
      _notifyEditorChanged();
      if (returnAfterSave && mounted) {
        Navigator.of(context).maybePop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _hasSavedCurrentDraft = false;
        _saveError = 'Unable to save tiles. ${error.toString()}';
      });
      _notifyEditorChanged();
    }
  }

  HandTileFanReviewResult _currentReviewFor(HandEvidenceReviewRecord record) {
    return calculateHandTileFanReview(
      draft: _tileDraft,
      declaredFanCount: record.declaredFanCount,
      seatWindTileId: record.seatWindTileId ?? 'east',
      roundWindTileId: record.roundWindTileId ?? 'east',
      isSelfDraw: record.winType == 'self_draw',
      winBonuses: record.winBonuses,
    );
  }

  void _addTile(String tileId) {
    if (_isSaving) {
      return;
    }

    setState(() {
      _tileDraft = _tileDraft.addTile(tileId);
      _hasSavedCurrentDraft = false;
      _saveError = null;
    });
    _notifyEditorChanged();
  }

  void _removeTile(String tileId) {
    if (_isSaving) {
      return;
    }

    setState(() {
      _tileDraft = _tileDraft.removeTile(tileId);
      _hasSavedCurrentDraft = false;
      _saveError = null;
    });
    _notifyEditorChanged();
  }

  void _clearTiles() {
    if (_isSaving) {
      return;
    }

    setState(() {
      _tileDraft = _tileDraft.copyWith(
        coreTileIds: const [],
        flowerTileIds: const [],
        winningTileId: null,
        winningTileKnown: false,
      );
      _hasSavedCurrentDraft = false;
      _saveError = null;
    });
    _notifyEditorChanged();
  }

  void _setWinningTile(String tileId) {
    if (_isSaving) {
      return;
    }

    setState(() {
      _tileDraft = _tileDraft.setWinningTile(tileId);
      _hasSavedCurrentDraft = false;
      _saveError = null;
    });
    _notifyEditorChanged();
  }

  void _setPhotoRotationQuarterTurns(int quarterTurns) {
    if (_isSaving) {
      return;
    }

    setState(() {
      _tileDraft = _tileDraft.copyWith(
        photoRotationQuarterTurns: quarterTurns,
      );
      _hasSavedCurrentDraft = false;
      _saveError = null;
    });
    _notifyEditorChanged();
  }

  Future<void> _openPhotoViewer() async {
    final uri = _photoUri;
    final record = _selectedRecord;
    if (uri == null || record == null) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return _HandPhotoViewer(
            title: _reviewTitle(
              record,
              ledgerEntry: _selectedLedgerEntry,
              queuePosition: _selectedRecordPosition,
            ),
            photoUri: uri,
            initialRotationQuarterTurns: _tileDraft.photoRotationQuarterTurns,
            onRotationChanged: _setPhotoRotationQuarterTurns,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SoftHostScaffold(
      title: 'Hand Review',
      showBackButton: true,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyStateCard(
            icon: Icons.error_outline,
            title: 'Unable to load hand evidence.',
            message: 'Check your connection and try again.',
            action: FilledButton(
              onPressed: _loadReviewRecords,
              child: const Text('Retry'),
            ),
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: EmptyStateCard(
            icon: Icons.photo_library_outlined,
            title: 'No hand evidence to review.',
            message: 'Captured hand photos will appear here.',
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 340,
                child: _HandEvidenceQueuePanel(
                  records: _filteredRecords,
                  allRecords: _records,
                  statusFilter: _statusFilter,
                  onStatusFilterChanged: _setStatusFilter,
                  ledgerEntriesByHandId: _ledgerEntriesByHandId,
                  selectedRecord: _selectedRecord,
                  onSelectRecord: (record, _) => _selectRecord(record),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildEditor(),
              ),
            ],
          );
        }

        return _HandEvidenceQueuePanel(
          records: _filteredRecords,
          allRecords: _records,
          statusFilter: _statusFilter,
          onStatusFilterChanged: _setStatusFilter,
          ledgerEntriesByHandId: _ledgerEntriesByHandId,
          selectedRecord: null,
          onSelectRecord: _openMobileEditor,
        );
      },
    );
  }

  List<HandEvidenceReviewRecord> get _filteredRecords {
    return [
      for (final record in _records)
        if (_statusFilter.matches(record)) record,
    ];
  }

  void _setStatusFilter(_HandEvidenceStatusFilter filter) {
    setState(() {
      _statusFilter = filter;
    });
  }

  int? get _selectedRecordPosition {
    final selectedRecord = _selectedRecord;
    if (selectedRecord == null) {
      return null;
    }
    final index = _records.indexWhere(
      (record) => record.handResultId == selectedRecord.handResultId,
    );
    if (index == -1) {
      return null;
    }
    return index + 1;
  }

  Widget _buildEditor({bool returnAfterSave = false}) {
    final record = _selectedRecord;
    if (record == null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          const emptyState = Padding(
            padding: EdgeInsets.all(24),
            child: EmptyStateCard(
              icon: Icons.touch_app_outlined,
              title: 'Select a photo to review.',
              message: 'Choose a row to enter tiles.',
            ),
          );

          if (constraints.maxHeight < 240) {
            return const SingleChildScrollView(child: emptyState);
          }

          return const Center(child: emptyState);
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 520;
        final gap = isCompact ? 6.0 : 8.0;
        final photoHeight = returnAfterSave
            ? 128.0
            : (constraints.maxHeight * (isCompact ? 0.26 : 0.34))
                .clamp(isCompact ? 132.0 : 190.0, isCompact ? 168.0 : 300.0)
                .toDouble();
        final photoImage =
            _photoUri == null ? null : NetworkImage(_photoUri.toString());
        final keyboard = TileKeyboard(
          draft: _tileDraft,
          onAddTile: _addTile,
          onRemoveTile: _removeTile,
          onClear: _clearTiles,
          onSetWinningTile: _setWinningTile,
        );
        final currentReview = _currentReviewFor(record);
        final topContent = [
          HandPhotoPreview(
            photoId: record.photo.id,
            photoImage: photoImage,
            isLoading: _isPhotoLoading,
            error: _photoError,
            height: photoHeight,
            rotationQuarterTurns: _tileDraft.photoRotationQuarterTurns,
            onOpenPhoto: _openPhotoViewer,
          ),
          SizedBox(height: gap),
          _FanBreakdownPanel(
            record: record,
            review: currentReview,
            isCompact: isCompact,
          ),
          SizedBox(height: gap),
        ];
        final hasUnsavedChanges = _hasUnsavedTileChanges;
        final canSave = currentReview.canSave && hasUnsavedChanges;
        final disabledLabel = _hasSavedCurrentDraft
            ? 'Saved'
            : !currentReview.isComplete
                ? 'Incomplete Hand'
                : !currentReview.canSave
                    ? 'Invalid Hand'
                    : 'No Changes';
        final bottomSaveBar = _BottomSaveBar(
          isSaving: _isSaving,
          isSaved: _hasSavedCurrentDraft,
          canSave: canSave,
          disabledLabel: disabledLabel,
          saveError: _saveError,
          onSave: () => _saveTiles(returnAfterSave: returnAfterSave),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...topContent,
              Expanded(child: keyboard),
              bottomSaveBar,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...topContent,
            Expanded(child: keyboard),
            bottomSaveBar,
          ],
        );
      },
    );
  }

  EventHandLedgerEntry? get _selectedLedgerEntry {
    final selectedRecord = _selectedRecord;
    if (selectedRecord == null) {
      return null;
    }
    return _ledgerEntriesByHandId[selectedRecord.handResultId];
  }
}

class _FanBreakdownPanel extends StatelessWidget {
  const _FanBreakdownPanel({
    required this.record,
    required this.review,
    required this.isCompact,
  });

  final HandEvidenceReviewRecord record;
  final HandTileFanReviewResult review;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasKnownWinType =
        record.winType == 'discard' || record.winType == 'self_draw';
    final rows = review.breakdown
        .where(
          (item) =>
              item.source != HandTileFanBreakdownSource.declared &&
              (item.source != HandTileFanBreakdownSource.winType ||
                  hasKnownWinType),
        )
        .toList(growable: false);
    final statusLabel = _statusLabel;
    final winBonuses = record.winBonuses;
    final winBonusesLabel = winBonuses == null
        ? 'Win bonuses not recorded'
        : winBonuses.isEmpty
            ? 'Win bonuses: None'
            : null;
    final contextLabelStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: isCompact ? 6 : 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _declarationLabel(record),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (isCompact)
                  Text(
                    '${review.calculatedFanCount?.toString() ?? '--'} fan',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        review.calculatedFanCount?.toString() ?? '--',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'fan',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (statusLabel != null || winBonusesLabel != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 2,
                children: [
                  if (statusLabel != null)
                    Text(statusLabel, style: contextLabelStyle),
                  if (winBonusesLabel != null)
                    Text(winBonusesLabel, style: contextLabelStyle),
                ],
              ),
            ],
            if (rows.isNotEmpty) ...[
              SizedBox(height: isCompact ? 4 : 8),
              if (isCompact)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final item in rows)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Row(
                            children: [
                              Text(
                                item.label,
                                style: theme.textTheme.bodySmall,
                              ),
                              if (item.fanValue != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '+${item.fanValue}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                )
              else
                for (final item in rows)
                  _FanBreakdownRow(
                    label: item.label,
                    fanValue: item.fanValue,
                  ),
            ],
          ],
        ),
      ),
    );
  }

  String? get _statusLabel {
    if (!review.isComplete) {
      return 'Incomplete hand';
    }
    if (!review.canSave) {
      return 'Invalid tile grouping';
    }
    return null;
  }
}

class _FanBreakdownRow extends StatelessWidget {
  const _FanBreakdownRow({
    required this.label,
    required this.fanValue,
  });

  final String label;
  final int? fanValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          if (fanValue != null)
            Text(
              '+$fanValue',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _HandEvidenceQueuePanel extends StatelessWidget {
  const _HandEvidenceQueuePanel({
    required this.records,
    required this.allRecords,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.ledgerEntriesByHandId,
    required this.selectedRecord,
    required this.onSelectRecord,
  });

  final List<HandEvidenceReviewRecord> records;
  final List<HandEvidenceReviewRecord> allRecords;
  final _HandEvidenceStatusFilter statusFilter;
  final ValueChanged<_HandEvidenceStatusFilter> onStatusFilterChanged;
  final Map<String, EventHandLedgerEntry> ledgerEntriesByHandId;
  final HandEvidenceReviewRecord? selectedRecord;
  final void Function(HandEvidenceReviewRecord record, int queuePosition)
      onSelectRecord;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(statusFilter),
      length: _HandEvidenceStatusFilter.values.length,
      initialIndex: statusFilter.index,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (index) {
              onStatusFilterChanged(_HandEvidenceStatusFilter.values[index]);
            },
            tabs: [
              for (final filter in _HandEvidenceStatusFilter.values)
                Tab(text: filter.label),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: EmptyStateCard(
                      icon: Icons.filter_list_off,
                      title: 'No ${statusFilter.label.toLowerCase()} hands.',
                      message: 'Try another status tab.',
                    ),
                  )
                : _HandEvidenceQueue(
                    records: records,
                    allRecords: allRecords,
                    ledgerEntriesByHandId: ledgerEntriesByHandId,
                    selectedRecord: selectedRecord,
                    onSelectRecord: onSelectRecord,
                  ),
          ),
        ],
      ),
    );
  }
}

enum _HandEvidenceStatusFilter {
  missingTiles('No tiles'),
  flagged('Flagged'),
  done('Done'),
  all('All');

  const _HandEvidenceStatusFilter(this.label);

  final String label;

  bool matches(HandEvidenceReviewRecord record) {
    final status = record.tileEntry?.reviewStatus;
    return switch (this) {
      _HandEvidenceStatusFilter.missingTiles => record.tileEntry == null,
      _HandEvidenceStatusFilter.flagged =>
        status == HandTileReviewStatus.unreviewed ||
            status == HandTileReviewStatus.flagged,
      _HandEvidenceStatusFilter.done =>
        status == HandTileReviewStatus.matched ||
            status == HandTileReviewStatus.underDeclared ||
            status == HandTileReviewStatus.resolved,
      _HandEvidenceStatusFilter.all => true,
    };
  }
}

class _HandEvidenceQueue extends StatelessWidget {
  const _HandEvidenceQueue({
    required this.records,
    required this.allRecords,
    required this.ledgerEntriesByHandId,
    required this.selectedRecord,
    required this.onSelectRecord,
  });

  final List<HandEvidenceReviewRecord> records;
  final List<HandEvidenceReviewRecord> allRecords;
  final Map<String, EventHandLedgerEntry> ledgerEntriesByHandId;
  final HandEvidenceReviewRecord? selectedRecord;
  final void Function(HandEvidenceReviewRecord record, int queuePosition)
      onSelectRecord;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final queuePosition = allRecords.indexWhere(
              (queuedRecord) =>
                  queuedRecord.handResultId == record.handResultId,
            ) +
            1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _HandEvidenceReviewRow(
            record: record,
            ledgerEntry: ledgerEntriesByHandId[record.handResultId],
            queuePosition: queuePosition > 0 ? queuePosition : index + 1,
            isSelected: selectedRecord?.handResultId == record.handResultId,
            onTap: () => onSelectRecord(
              record,
              queuePosition > 0 ? queuePosition : index + 1,
            ),
          ),
        );
      },
    );
  }
}

class _HandEvidenceReviewRow extends StatelessWidget {
  const _HandEvidenceReviewRow({
    required this.record,
    required this.ledgerEntry,
    required this.queuePosition,
    required this.isSelected,
    required this.onTap,
  });

  final HandEvidenceReviewRecord record;
  final EventHandLedgerEntry? ledgerEntry;
  final int queuePosition;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusBadge = _reviewStatusBadge(record.tileEntry?.reviewStatus);
    return AppListSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _reviewTitle(
                    record,
                    ledgerEntry: ledgerEntry,
                    queuePosition: queuePosition,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isSelected ? colorScheme.primary : null,
                      ),
                ),
              ),
              if (statusBadge != null) ...[
                const SizedBox(width: 8),
                _SmallReviewStatusBadge(label: statusBadge),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _metadataLabel(record, ledgerEntry: ledgerEntry),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _SmallReviewStatusBadge extends StatelessWidget {
  const _SmallReviewStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _BottomSaveBar extends StatelessWidget {
  const _BottomSaveBar({
    required this.isSaving,
    required this.isSaved,
    required this.canSave,
    required this.disabledLabel,
    required this.saveError,
    required this.onSave,
  });

  final bool isSaving;
  final bool isSaved;
  final bool canSave;
  final String disabledLabel;
  final String? saveError;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final error = saveError;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[
              InlineErrorBanner(message: error),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: isSaving || !canSave ? null : onSave,
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isSaved
                          ? Icons.check_circle_outline
                          : Icons.save_outlined,
                    ),
              label: Text(
                isSaved
                    ? 'Saved'
                    : canSave
                        ? 'Save Tiles'
                        : disabledLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandPhotoViewer extends StatefulWidget {
  const _HandPhotoViewer({
    required this.title,
    required this.photoUri,
    required this.initialRotationQuarterTurns,
    required this.onRotationChanged,
  });

  final String title;
  final Uri photoUri;
  final int initialRotationQuarterTurns;
  final ValueChanged<int> onRotationChanged;

  @override
  State<_HandPhotoViewer> createState() => _HandPhotoViewerState();
}

class _HandPhotoViewerState extends State<_HandPhotoViewer> {
  final _transformationController = TransformationController();
  late int _rotationQuarterTurns;

  @override
  void initState() {
    super.initState();
    _rotationQuarterTurns = widget.initialRotationQuarterTurns % 4;
  }

  void _setRotation(int quarterTurns) {
    final normalizedQuarterTurns = quarterTurns % 4;
    setState(() {
      _rotationQuarterTurns = normalizedQuarterTurns;
    });
    widget.onRotationChanged(normalizedQuarterTurns);
  }

  void _resetViewer() {
    _transformationController.value = Matrix4.identity();
    _setRotation(0);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 5,
              child: Center(
                child: RotatedBox(
                  quarterTurns: _rotationQuarterTurns,
                  child: Image.network(
                    widget.photoUri.toString(),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.broken_image_outlined,
                        color: colorScheme.onSurfaceVariant,
                        size: 48,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: 'Rotate left',
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _setRotation(_rotationQuarterTurns - 1),
                        icon: const Icon(Icons.rotate_left),
                        label: const Text('Left'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: 'Rotate right',
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _setRotation(_rotationQuarterTurns + 1),
                        icon: const Icon(Icons.rotate_right),
                        label: const Text('Right'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Reset',
                    onPressed: _resetViewer,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

HandEvidenceReviewRecord _withTileEntry(
  HandEvidenceReviewRecord record,
  HandTileEntryRecord tileEntry,
) {
  return HandEvidenceReviewRecord(
    photo: record.photo,
    handResultId: record.handResultId,
    handNumber: record.handNumber,
    tableLabel: record.tableLabel,
    winnerName: record.winnerName,
    winType: record.winType,
    declaredFanCount: record.declaredFanCount,
    seatWindTileId: record.seatWindTileId,
    roundWindTileId: record.roundWindTileId,
    winBonuses: record.winBonuses,
    tileEntry: tileEntry,
  );
}

HandTileEntryDraft? _draftFromTileEntry(HandTileEntryRecord? tileEntry) {
  final tilesJson = tileEntry?.tilesJson;
  try {
    if (tilesJson is List) {
      final tileIds = _splitTileIds(tilesJson);
      return HandTileEntryDraft(
        coreTileIds: tileIds.coreTileIds,
        flowerTileIds: tileIds.flowerTileIds,
      );
    }

    if (tilesJson is! Map) {
      return null;
    }

    final coreTileIds = _stringListFromJson(tilesJson['tiles']);
    final flowerTileIds = _stringListFromJson(tilesJson['flowers']);
    final winningTileKnown = tilesJson['winningTileKnown'] == true;
    final winningTileValue =
        tilesJson['winningTileId'] ?? tilesJson['winningTile'];
    final winningTileId = winningTileValue is String ? winningTileValue : null;
    final photoRotationValue = tilesJson['photoRotationQuarterTurns'];
    final photoRotationQuarterTurns =
        photoRotationValue is num ? photoRotationValue.toInt() : 0;

    return HandTileEntryDraft(
      coreTileIds: coreTileIds,
      flowerTileIds: flowerTileIds,
      winningTileId: winningTileId,
      winningTileKnown: winningTileKnown,
      photoRotationQuarterTurns: photoRotationQuarterTurns,
    );
  } catch (_) {
    return null;
  }
}

({List<String> coreTileIds, List<String> flowerTileIds}) _splitTileIds(
  List<dynamic> values,
) {
  final coreTileIds = <String>[];
  final flowerTileIds = <String>[];

  for (final value in values) {
    if (value is! String) {
      continue;
    }

    try {
      final tile = MahjongTile.byId(value);
      if (tile.category == MahjongTileCategory.flowerSeason) {
        flowerTileIds.add(value);
      } else {
        coreTileIds.add(value);
      }
    } on FormatException {
      continue;
    }
  }

  return (coreTileIds: coreTileIds, flowerTileIds: flowerTileIds);
}

List<String> _stringListFromJson(Object? value) {
  if (value == null) {
    return const [];
  }

  if (value is! List) {
    throw const FormatException('Expected a list of tile ids.');
  }

  return [
    for (final item in value)
      if (item is String)
        item
      else
        throw const FormatException('Expected tile id string.'),
  ];
}

Map<String, EventHandLedgerEntry> _ledgerEntriesByHandIdFrom(
  List<EventHandLedgerEntry> entries,
) {
  return {
    for (final entry in entries)
      if (entry.rowType == EventHandLedgerRowType.hand) entry.handId: entry,
  };
}

String? _reviewStatusBadge(HandTileReviewStatus? status) {
  return switch (status) {
    HandTileReviewStatus.matched => 'Matched',
    HandTileReviewStatus.underDeclared => 'Under',
    HandTileReviewStatus.resolved => 'Resolved',
    _ => null,
  };
}

String _metadataLabel(
  HandEvidenceReviewRecord record, {
  EventHandLedgerEntry? ledgerEntry,
}) {
  if (ledgerEntry != null) {
    final parts = <String>[];
    final winnerName =
        _trimmedOrNull(record.winnerName) ?? _winnerNameFromLedger(ledgerEntry);
    if (winnerName != null) {
      parts.add(winnerName);
    }
    parts.add(_ledgerResultSummary(ledgerEntry));
    parts.add(_formatCapturedTime(record.photo.capturedAt));
    return parts.join(' • ');
  }

  final parts = <String>[];
  final handNumber = record.handNumber;
  final tableLabel = record.tableLabel;
  final winnerName = record.winnerName;
  final declaredFanCount = record.declaredFanCount;

  if (tableLabel != null && tableLabel.trim().isNotEmpty) {
    parts.add(tableLabel);
  }
  if (winnerName != null && winnerName.trim().isNotEmpty) {
    parts.add(winnerName.trim());
  }
  if (declaredFanCount != null) {
    parts.add('Declared $declaredFanCount fan');
  }

  if (parts.isEmpty) {
    return _formatCapturedTime(record.photo.capturedAt);
  }

  if (handNumber != null) {
    parts.insert(0, 'Hand $handNumber');
  }

  return parts.join(' • ');
}

String _declarationLabel(HandEvidenceReviewRecord record) {
  final declaredFanCount = record.declaredFanCount;
  if (declaredFanCount == null) {
    return 'Declared fan not recorded';
  }

  final winType = switch (record.winType) {
    'self_draw' => 'self-draw',
    'discard' => 'discard',
    _ => null,
  };
  if (winType == null) {
    return 'Declared $declaredFanCount fan';
  }
  return 'Declared $declaredFanCount fan $winType';
}

String _reviewTitle(
  HandEvidenceReviewRecord record, {
  EventHandLedgerEntry? ledgerEntry,
  int? queuePosition,
}) {
  if (ledgerEntry != null) {
    return _ledgerHandLabel(ledgerEntry);
  }

  final handNumber = record.handNumber;
  if (handNumber != null) {
    return 'Hand $handNumber';
  }
  final winnerName = _trimmedOrNull(record.winnerName);
  if (winnerName != null) {
    return "$winnerName's winning hand";
  }
  final tableLabel = _trimmedOrNull(record.tableLabel);
  if (tableLabel != null) {
    return '$tableLabel winning hand';
  }
  if (queuePosition != null) {
    return 'Photo $queuePosition';
  }
  return 'Photo';
}

String _ledgerHandLabel(EventHandLedgerEntry entry) {
  return '${_explicitTableLabel(entry.tableLabel)} · '
      'Session ${entry.sessionNumberForTable} · Hand ${entry.handNumber}';
}

String _explicitTableLabel(String tableLabel) {
  final trimmed = tableLabel.trim();
  if (trimmed.toLowerCase().startsWith('table ')) {
    return trimmed;
  }
  return 'Table $trimmed';
}

String? _winnerNameFromLedger(EventHandLedgerEntry entry) {
  EventHandLedgerCell? winnerCell;
  for (final cell in entry.cells) {
    if (cell.pointsDelta <= 0) {
      continue;
    }
    if (winnerCell == null || cell.pointsDelta > winnerCell.pointsDelta) {
      winnerCell = cell;
    }
  }
  return _trimmedOrNull(winnerCell?.displayName);
}

String _ledgerResultSummary(EventHandLedgerEntry entry) {
  if (entry.status == HandResultStatus.voided) {
    return 'voided';
  }
  if (entry.resultType == HandResultType.washout) {
    return 'draw';
  }
  if (entry.resultType == HandResultType.falseWinPenalty) {
    return '${entry.fanCount ?? 6} fan false win penalty';
  }

  final winType = switch (entry.winType) {
    HandWinType.discard => 'discard',
    HandWinType.selfDraw => 'self-draw',
    null => 'win',
  };
  final fanCount = entry.fanCount;
  return fanCount == null ? winType : '$fanCount fan $winType';
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _formatCapturedTime(DateTime capturedAt) {
  final localTime = capturedAt.toLocal();
  final hour = localTime.hour % 12 == 0 ? 12 : localTime.hour % 12;
  final minute = localTime.minute.toString().padLeft(2, '0');
  final meridiem = localTime.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $meridiem';
}
