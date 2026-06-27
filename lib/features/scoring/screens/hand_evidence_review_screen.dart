import 'package:flutter/material.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/models/hand_tile_entry_draft.dart';
import 'package:mosaic/features/scoring/models/hand_tile_fan_calculator.dart';
import 'package:mosaic/features/scoring/models/mahjong_tile.dart';
import 'package:mosaic/features/scoring/widgets/tile_keyboard.dart';
import 'package:mosaic/widgets/app_chrome.dart';
import 'package:mosaic/widgets/app_surfaces.dart';
import 'package:mosaic/widgets/empty_state_card.dart';
import 'package:mosaic/widgets/status_chip.dart';

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
  Uri? _photoUri;
  Object? _photoError;
  var _isPhotoLoading = false;
  var _photoRequestToken = 0;

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
      _photoUri = null;
      _photoError = null;
      _isPhotoLoading = false;
    });
    _photoRequestToken++;

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
        _selectedRecord = null;
        _tileDraft = HandTileEntryDraft();
        _isLoading = false;
        _loadError = error;
        _photoUri = null;
        _photoError = null;
        _isPhotoLoading = false;
      });
    }
  }

  void _selectRecord(HandEvidenceReviewRecord record) {
    if (_isSaving) {
      return;
    }

    setState(() {
      _selectedRecord = record;
      _tileDraft =
          _draftFromTileEntry(record.tileEntry) ?? HandTileEntryDraft();
      _saveError = null;
      _photoUri = null;
      _photoError = null;
      _isPhotoLoading = true;
    });
    _loadPhotoForRecord(record);
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
    } catch (error) {
      if (!mounted || requestToken != _photoRequestToken) {
        return;
      }

      setState(() {
        _photoUri = null;
        _photoError = error;
        _isPhotoLoading = false;
      });
    }
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
                child: _HandEvidenceQueue(
                  records: _records,
                  selectedRecord: _selectedRecord,
                  onSelectRecord: _selectRecord,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: _buildEditor()),
            ],
          );
        }

        final isShort = constraints.maxHeight < 560;
        return Column(
          children: [
            SizedBox(
              height: isShort ? 96 : 220,
              child: _HandEvidenceQueue(
                records: _records,
                selectedRecord: _selectedRecord,
                onSelectRecord: _selectRecord,
              ),
            ),
            SizedBox(height: isShort ? 8 : 12),
            Expanded(child: _buildEditor()),
          ],
        );
      },
    );
  }

  Widget _buildEditor() {
    final record = _selectedRecord;
    if (record == null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          const emptyState = Padding(
            padding: EdgeInsets.all(24),
            child: EmptyStateCard(
              icon: Icons.touch_app_outlined,
              title: 'Select a hand to review.',
              message: 'Choose a queue row to enter tiles.',
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
        final isCompact = constraints.maxHeight < 360;
        final gap = isCompact ? 8.0 : 12.0;
        final photoHeight = isCompact ? 144.0 : 180.0;
        final keyboard = TileKeyboard(
          draft: _tileDraft,
          onAddTile: _addTile,
          onRemoveTile: _removeTile,
          onClear: _clearTiles,
          onSetWinningTile: _setWinningTile,
        );
        final children = [
          _HandEvidenceEditorHeader(
            record: record,
            isSaving: _isSaving,
            saveError: _saveError,
            onSave: _saveTiles,
          ),
          SizedBox(height: gap),
          _HandPhotoPreview(
            record: record,
            photoUri: _photoUri,
            isLoading: _isPhotoLoading,
            error: _photoError,
            height: photoHeight,
          ),
          SizedBox(height: gap),
        ];

        if (isCompact) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              ...children,
              SizedBox(
                height: 360,
                child: keyboard,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...children,
            Expanded(child: keyboard),
          ],
        );
      },
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
      padding: EdgeInsets.zero,
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _HandEvidenceReviewRow(
            record: record,
            isSelected: selectedRecord?.handResultId == record.handResultId,
            onTap: () => onSelectRecord(record),
          ),
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
                  _reviewTitle(record),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isSelected ? colorScheme.primary : null,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: _reviewStatusLabel(record),
                tone: _reviewStatusTone(record),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _metadataLabel(record),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppListSurface(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusChip(
                    label: _reviewStatusLabel(record),
                    tone: _reviewStatusTone(record),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Review ${_reviewTitle(record)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _metadataLabel(record),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isSaving ? null : onSave,
                  icon: isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save Tiles'),
                ),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          InlineErrorBanner(message: error),
        ],
      ],
    );
  }
}

class _HandPhotoPreview extends StatelessWidget {
  const _HandPhotoPreview({
    required this.record,
    required this.photoUri,
    required this.isLoading,
    required this.error,
    required this.height,
  });

  final HandEvidenceReviewRecord record;
  final Uri? photoUri;
  final bool isLoading;
  final Object? error;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final uri = photoUri;
    final photoError = error;

    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Winning hand photo',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: double.infinity,
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Builder(
                  builder: (context) {
                    if (isLoading) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Loading photo'),
                          ],
                        ),
                      );
                    }

                    if (photoError != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                color: colorScheme.error,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Photo could not be loaded',
                                style: TextStyle(color: colorScheme.error),
                              ),
                              Text(
                                photoError.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (uri == null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 6),
                              const Text('Photo unavailable'),
                              Text(
                                record.photo.clientPhotoId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Image.network(
                      uri.toString(),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    );
                  },
                ),
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

    return HandTileEntryDraft(
      coreTileIds: coreTileIds,
      flowerTileIds: flowerTileIds,
      winningTileId: winningTileId,
      winningTileKnown: winningTileKnown,
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

String _reviewTitle(HandEvidenceReviewRecord record) {
  final handNumber = record.handNumber;
  if (handNumber != null) {
    return 'Hand $handNumber';
  }
  return record.handResultId;
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

StatusChipTone _reviewStatusTone(HandEvidenceReviewRecord record) {
  final tileEntry = record.tileEntry;
  if (tileEntry == null) {
    return StatusChipTone.warning;
  }

  return switch (tileEntry.reviewStatus) {
    HandTileReviewStatus.unreviewed => StatusChipTone.neutral,
    HandTileReviewStatus.matched => StatusChipTone.success,
    HandTileReviewStatus.underDeclared => StatusChipTone.warning,
    HandTileReviewStatus.flagged => StatusChipTone.danger,
    HandTileReviewStatus.resolved => StatusChipTone.success,
  };
}
