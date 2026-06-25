import 'package:flutter/material.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/models/hand_tile_entry_draft.dart';
import 'package:mosaic/features/scoring/models/hand_tile_fan_calculator.dart';
import 'package:mosaic/features/scoring/widgets/tile_keyboard.dart';
import 'package:mosaic/widgets/empty_state_card.dart';

class HandEvidenceReviewScreen extends StatefulWidget {
  const HandEvidenceReviewScreen({
    super.key,
    required this.eventId,
    required this.mosaicProfileRepository,
  });

  final String eventId;
  final MosaicProfileRepository mosaicProfileRepository;

  @override
  State<HandEvidenceReviewScreen> createState() =>
      _HandEvidenceReviewScreenState();
}

class _HandEvidenceReviewScreenState extends State<HandEvidenceReviewScreen> {
  var _records = <HandEvidenceReviewRecord>[];
  HandEvidenceReviewRecord? _selectedRecord;
  HandTileEntryDraft _tileDraft = HandTileEntryDraft();
  var _isLoading = true;
  Object? _loadError;
  var _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _loadReviewRecords();
  }

  Future<void> _loadReviewRecords() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _saveError = null;
    });

    try {
      final records = await widget.mosaicProfileRepository
          .listHandEvidenceReview(widget.eventId);
      if (!mounted) {
        return;
      }

      setState(() {
        _records = records;
        _selectedRecord = null;
        _tileDraft = HandTileEntryDraft();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _records = [];
        _selectedRecord = null;
        _tileDraft = HandTileEntryDraft();
        _isLoading = false;
        _loadError = error;
      });
    }
  }

  void _selectRecord(HandEvidenceReviewRecord record) {
    if (_isSaving) {
      return;
    }

    setState(() {
      _selectedRecord = record;
      _tileDraft = HandTileEntryDraft();
      _saveError = null;
    });
  }

  Future<void> _saveTiles() async {
    final record = _selectedRecord;
    if (record == null || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final review = calculateHandTileFanReview(
        draft: _tileDraft,
        declaredFanCount: record.declaredFanCount,
        seatWindTileId: record.seatWindTileId ?? 'east',
        roundWindTileId: record.roundWindTileId ?? 'east',
        isSelfDraw: record.winType == 'self_draw',
      );
      final savedEntry =
          await widget.mosaicProfileRepository.upsertHandTileEntry(
        handResultId: record.handResultId,
        tilesJson: _tileDraft.toJson(groups: review.grouping.toJson()),
        calculatedFanCount: review.calculatedFanCount,
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
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _saveError = 'Unable to save tiles. ${error.toString()}';
      });
    }
  }

  void _addTile(String tileId) {
    if (_isSaving) {
      return;
    }

    setState(() {
      _tileDraft = _tileDraft.addTile(tileId);
      _saveError = null;
    });
  }

  void _removeTile(String tileId) {
    if (_isSaving) {
      return;
    }

    setState(() {
      _tileDraft = _tileDraft.removeTile(tileId);
      _saveError = null;
    });
  }

  void _clearTiles() {
    if (_isSaving) {
      return;
    }

    setState(() {
      _tileDraft = HandTileEntryDraft();
      _saveError = null;
    });
  }

  void _setWinningTile(String tileId) {
    if (_isSaving) {
      return;
    }

    setState(() {
      _tileDraft = _tileDraft.setWinningTile(tileId);
      _saveError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hand Evidence Review')),
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
            children: [
              SizedBox(
                width: 340,
                child: _HandEvidenceQueue(
                  records: _records,
                  selectedRecord: _selectedRecord,
                  onSelectRecord: _selectRecord,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _buildEditor()),
            ],
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 240,
              child: _HandEvidenceQueue(
                records: _records,
                selectedRecord: _selectedRecord,
                onSelectRecord: _selectRecord,
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildEditor()),
          ],
        );
      },
    );
  }

  Widget _buildEditor() {
    final record = _selectedRecord;
    if (record == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: EmptyStateCard(
            icon: Icons.touch_app_outlined,
            title: 'Select a hand to review.',
            message: 'Choose a queue row to enter tiles.',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HandEvidenceEditorHeader(
          record: record,
          isSaving: _isSaving,
          saveError: _saveError,
          onSave: _saveTiles,
        ),
        Expanded(
          child: TileKeyboard(
            draft: _tileDraft,
            onAddTile: _addTile,
            onRemoveTile: _removeTile,
            onClear: _clearTiles,
            onSetWinningTile: _setWinningTile,
          ),
        ),
      ],
    );
  }
}

class _HandEvidenceQueue extends StatelessWidget {
  const _HandEvidenceQueue({
    required this.records,
    required this.selectedRecord,
    required this.onSelectRecord,
  });

  final List<HandEvidenceReviewRecord> records;
  final HandEvidenceReviewRecord? selectedRecord;
  final ValueChanged<HandEvidenceReviewRecord> onSelectRecord;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _HandEvidenceReviewRow(
          record: record,
          isSelected: selectedRecord?.handResultId == record.handResultId,
          onTap: () => onSelectRecord(record),
        );
      },
    );
  }
}

class _HandEvidenceReviewRow extends StatelessWidget {
  const _HandEvidenceReviewRow({
    required this.record,
    required this.isSelected,
    required this.onTap,
  });

  final HandEvidenceReviewRecord record;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = _reviewStatusLabel(record);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surface.withValues(alpha: 0.84),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: ListTile(
          onTap: onTap,
          leading: const Icon(Icons.fact_check_outlined),
          title: Text(
            record.handResultId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            _metadataLabel(record),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            status,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}

class _HandEvidenceEditorHeader extends StatelessWidget {
  const _HandEvidenceEditorHeader({
    required this.record,
    required this.isSaving,
    required this.saveError,
    required this.onSave,
  });

  final HandEvidenceReviewRecord record;
  final bool isSaving;
  final String? saveError;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final error = saveError;
    return Material(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Review ${record.handResultId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: isSaving ? null : onSave,
                  icon: isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save Tiles'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _metadataLabel(record),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ],
        ),
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
    tileEntry: tileEntry,
  );
}

String _metadataLabel(HandEvidenceReviewRecord record) {
  final parts = <String>[];
  final handNumber = record.handNumber;
  final tableLabel = record.tableLabel;
  final winnerName = record.winnerName;
  final declaredFanCount = record.declaredFanCount;

  if (handNumber != null) {
    parts.add('Hand $handNumber');
  }
  if (tableLabel != null && tableLabel.trim().isNotEmpty) {
    parts.add(tableLabel);
  }
  if (winnerName != null && winnerName.trim().isNotEmpty) {
    parts.add('Winner $winnerName');
  }
  if (declaredFanCount != null) {
    parts.add('Declared $declaredFanCount fan');
  }

  if (parts.isEmpty) {
    return record.photo.clientPhotoId;
  }

  return parts.join(' • ');
}

String _reviewStatusLabel(HandEvidenceReviewRecord record) {
  final tileEntry = record.tileEntry;
  if (tileEntry == null) {
    return 'Needs tiles';
  }

  return switch (tileEntry.reviewStatus) {
    HandTileReviewStatus.unreviewed => 'Unreviewed',
    HandTileReviewStatus.matched => 'Matched',
    HandTileReviewStatus.underDeclared => 'Under-declared',
    HandTileReviewStatus.flagged => 'Flagged',
    HandTileReviewStatus.resolved => 'Resolved',
  };
}
