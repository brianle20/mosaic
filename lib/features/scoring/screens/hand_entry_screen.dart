import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/controllers/hand_entry_controller.dart';
import 'package:mosaic/features/scoring/models/hand_result_draft.dart';
import 'package:mosaic/features/scoring/models/round_timer_state.dart';
import 'package:mosaic/services/media/hand_photo_service.dart';

enum _PlayerScanTarget { winner, discarder, penaltyCaller }

const _tableSeatOrder = [0, 3, 1, 2];
const _quickFanCounts = [3, 4, 5, 6, 7];
const _maximumWinningFan = 13;

class HandEntryScreen extends StatefulWidget {
  const HandEntryScreen({
    super.key,
    required this.sessionDetail,
    required this.guestNamesById,
    required this.sessionRepository,
    this.handPhotoService,
    this.initialHand,
  });

  final SessionDetailRecord sessionDetail;
  final Map<String, String> guestNamesById;
  final SessionRepository sessionRepository;
  final HandPhotoService? handPhotoService;
  final HandResultRecord? initialHand;

  @override
  State<HandEntryScreen> createState() => _HandEntryScreenState();
}

class _HandEntryScreenState extends State<HandEntryScreen> {
  late final HandEntryController _controller;
  late SessionDetailRecord _sessionDetail;
  late HandResultType _resultType;
  HandWinType? _winType;
  int? _winnerSeatIndex;
  int? _discarderSeatIndex;
  int? _penaltySeatIndex;
  bool _choosingFalseWinCaller = false;
  bool _isCapturingPhoto = false;
  bool _showValidationSummary = false;
  CapturedHandPhoto? _capturedPhoto;
  late final HandPhotoService _handPhotoService;
  late int _fanCount;

  @override
  void initState() {
    super.initState();
    _sessionDetail = widget.sessionDetail;
    _handPhotoService =
        widget.handPhotoService ?? ImagePickerHandPhotoService();
    _controller =
        HandEntryController(sessionRepository: widget.sessionRepository)
          ..addListener(_handleUpdate);
    final initialHand = widget.initialHand;
    _resultType = initialHand?.resultType ?? HandResultType.win;
    _winType = initialHand?.winType ?? HandWinType.selfDraw;
    _winnerSeatIndex = initialHand?.winnerSeatIndex;
    _discarderSeatIndex = initialHand?.discarderSeatIndex;
    _penaltySeatIndex = initialHand?.penaltySeatIndex;
    _fanCount = (initialHand?.fanCount ?? minimumWinningFan)
        .clamp(minimumWinningFan, _maximumWinningFan)
        .toInt();
  }

  @override
  void didUpdateWidget(covariant HandEntryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionDetail != widget.sessionDetail) {
      _sessionDetail = widget.sessionDetail;
    }
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

  int get _drawDealerSeatIndex =>
      widget.initialHand?.eastSeatIndexBeforeHand ??
      _sessionDetail.session.currentDealerSeatIndex;

  int get _labelEastSeatIndex =>
      widget.initialHand?.eastSeatIndexBeforeHand ??
      _sessionDetail.session.currentDealerSeatIndex;

  String _seatName(int seatIndex) {
    final seat = _sessionDetail.seats.firstWhere(
      (entry) => entry.seatIndex == seatIndex,
    );
    return widget.guestNamesById[seat.eventGuestId] ?? seat.eventGuestId;
  }

  bool get _isEditingLegacyFalseWin =>
      widget.initialHand?.resultType == HandResultType.falseWinPenalty;

  HandResultDraft get _draft => HandResultDraft(
        resultType: _resultType,
        winnerSeatIndex: _winnerSeatIndex,
        winType: _resultType == HandResultType.win ? _winType : null,
        discarderSeatIndex:
            _resultType == HandResultType.win ? _discarderSeatIndex : null,
        penaltySeatIndex: _isEditingLegacyFalseWin ? _penaltySeatIndex : null,
        fanCount: _resultType == HandResultType.win ? _fanCount : null,
        dealerWasWaitingAtDraw: null,
        blockedWinnerSeatIndexes:
            widget.initialHand == null ? _blockedWinnerSeatIndexes : const {},
        requiresPhoto:
            widget.initialHand == null && _resultType == HandResultType.win,
        photoClientId:
            widget.initialHand == null && _resultType == HandResultType.win
                ? _capturedPhoto?.clientPhotoId
                : null,
        photoLocalPath:
            widget.initialHand == null && _resultType == HandResultType.win
                ? _capturedPhoto?.localPath
                : null,
        photoCapturedAt:
            widget.initialHand == null && _resultType == HandResultType.win
                ? _capturedPhoto?.capturedAt
                : null,
      );

  Set<int> get _blockedWinnerSeatIndexes =>
      _sessionDetail.pendingFalseWinPenaltySeatIndexes.toSet();

  bool get _roundExpired =>
      widget.initialHand == null &&
      _sessionHasRoundTimer &&
      RoundTimerState.fromStartedAt(
        startedAt: _sessionDetail.session.startedAt,
        pausedAt: _sessionDetail.session.roundTimerPausedAt,
        pausedSeconds: _sessionDetail.session.roundTimerPausedSeconds,
      ).isExpired;

  bool get _sessionHasRoundTimer =>
      _sessionDetail.session.scoringPhase == EventScoringPhase.tournament ||
      _sessionDetail.session.scoringPhase == EventScoringPhase.bonus;

  bool get _hasNonPhotoDraftError {
    final draft = _draft;
    return draft.winnerSeatError != null ||
        draft.fanCountError != null ||
        draft.winTypeError != null ||
        draft.discarderSeatError != null ||
        draft.washoutFieldError != null ||
        draft.falseWinPenaltySeatError != null ||
        draft.washoutDealerWaitingError != null;
  }

  String? get _firstDraftError {
    final draft = _draft;
    return draft.winnerSeatError ??
        draft.fanCountError ??
        draft.winTypeError ??
        draft.discarderSeatError ??
        draft.washoutFieldError ??
        draft.falseWinPenaltySeatError ??
        draft.washoutDealerWaitingError ??
        draft.photoEvidenceError;
  }

  String? get _saveBlockingMessage =>
      (_showValidationSummary ? _firstDraftError : null) ??
      _controller.submitError;

  String? get _existingPhotoStatusLabel {
    final hand = widget.initialHand;
    if (hand == null ||
        hand.resultType != HandResultType.win ||
        hand.photoClientId == null) {
      return null;
    }

    return switch (hand.photoUploadStatus) {
      'uploaded' => 'Winning hand photo uploaded',
      'pending' => 'Winning hand photo pending upload',
      'failed' => 'Winning hand photo upload failed',
      _ => 'Winning hand photo captured',
    };
  }

  Future<void> _captureWinningHandPhoto() async {
    if (_isCapturingPhoto) {
      return;
    }

    setState(() {
      _isCapturingPhoto = true;
    });

    try {
      final captured = await _handPhotoService.captureWinningHandPhoto();
      if (!mounted || captured == null) {
        return;
      }

      setState(() {
        _capturedPhoto = captured;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCapturingPhoto = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_choosingFalseWinCaller) {
      return;
    }

    if (_draft.photoEvidenceError != null && !_hasNonPhotoDraftError) {
      await _captureWinningHandPhoto();
      if (!mounted) {
        return;
      }
    }

    if (!_draft.isValid) {
      setState(() {
        _showValidationSummary = true;
      });
      return;
    }

    setState(() {
      _showValidationSummary = false;
    });
    final detail = await _controller.submit(
      tableSessionId: _sessionDetail.session.id,
      draft: _draft,
      existingHand: widget.initialHand,
    );
    if (!mounted || detail == null) {
      return;
    }

    Navigator.of(context).pop(detail);
  }

  Future<void> _voidHand() async {
    final initialHand = widget.initialHand;
    if (initialHand == null) {
      return;
    }

    final detail = await _controller.voidHand(handResultId: initialHand.id);
    if (!mounted || detail == null) {
      return;
    }

    Navigator.of(context).pop(detail);
  }

  Future<void> _showFalseWinCallerPicker() async {
    setState(() {
      _choosingFalseWinCaller = true;
    });
  }

  Future<void> _recordFalseWinCaller(int seatIndex) async {
    if (_blockedWinnerSeatIndexes.contains(seatIndex)) {
      setState(() {
        _penaltySeatIndex = seatIndex;
      });
      return;
    }

    final detail = await _controller.recordFalseWinPenalty(
      tableSessionId: _sessionDetail.session.id,
      penaltySeatIndex: seatIndex,
    );
    if (!mounted || detail == null) {
      return;
    }

    setState(() {
      _sessionDetail = detail;
      _choosingFalseWinCaller = false;
      _penaltySeatIndex = null;
    });
  }

  void _setFanCount(int fanCount) {
    setState(() {
      _fanCount = fanCount.clamp(minimumWinningFan, _maximumWinningFan).toInt();
    });
  }

  void _adjustFanCount(int delta) {
    _setFanCount(_fanCount + delta);
  }

  String _seatLabel(int seatIndex) {
    final guestName = _seatName(seatIndex);
    final relativeSeatIndex = (seatIndex - _labelEastSeatIndex) % 4;
    final wind = switch (relativeSeatIndex) {
      0 => 'East',
      1 => 'South',
      2 => 'West',
      3 => 'North',
      _ => 'Seat',
    };
    return '$guestName ($wind)';
  }

  void _selectSeat(int seatIndex,
      {_PlayerScanTarget target = _PlayerScanTarget.winner}) {
    if (target == _PlayerScanTarget.penaltyCaller) {
      unawaited(_recordFalseWinCaller(seatIndex));
      return;
    }

    if (_resultType != HandResultType.win) {
      return;
    }

    setState(() {
      _winType ??= HandWinType.selfDraw;
      if (_winType == HandWinType.discard &&
          target == _PlayerScanTarget.discarder) {
        if (_winnerSeatIndex == seatIndex) {
          return;
        }
        _discarderSeatIndex = seatIndex;
        return;
      }

      _winnerSeatIndex = seatIndex;
      if (_discarderSeatIndex == seatIndex) {
        _discarderSeatIndex = null;
      }
    });
  }

  Widget _buildSeatButtonGrid({
    required String prompt,
    required _PlayerScanTarget target,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final orderedSeats = _orderedSeatsForTableView();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prompt,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orderedSeats.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.4,
          ),
          itemBuilder: (context, index) {
            final seat = orderedSeats[index];
            final isDealer = seat.seatIndex == _labelEastSeatIndex;
            final isWinner = seat.seatIndex == _winnerSeatIndex;
            final isDiscarder = seat.seatIndex == _discarderSeatIndex;
            final isPenaltyCaller = seat.seatIndex == _penaltySeatIndex;
            final disabled = _controller.isSubmitting ||
                target == _PlayerScanTarget.discarder &&
                    seat.seatIndex == _winnerSeatIndex;
            final selected = switch (target) {
              _PlayerScanTarget.winner => isWinner,
              _PlayerScanTarget.discarder => isDiscarder,
              _PlayerScanTarget.penaltyCaller => isPenaltyCaller,
            };
            final label = _seatLabelLines(seat.seatIndex);

            return OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: selected
                    ? colorScheme.primary
                    : isDealer
                        ? colorScheme.secondaryContainer.withValues(alpha: 0.55)
                        : colorScheme.surface,
                foregroundColor: selected
                    ? colorScheme.onPrimary
                    : isDealer
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurface,
                side: BorderSide(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: disabled
                  ? null
                  : () => _selectSeat(seat.seatIndex, target: target),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ],
    );
  }

  List<TableSessionSeatRecord> _orderedSeatsForTableView() {
    final seatsByRelativeIndex = {
      for (final seat in _sessionDetail.seats)
        (seat.seatIndex - _labelEastSeatIndex) % 4: seat,
    };
    return [
      for (final relativeIndex in _tableSeatOrder)
        if (seatsByRelativeIndex[relativeIndex] != null)
          seatsByRelativeIndex[relativeIndex]!,
    ];
  }

  String _seatLabelLines(int seatIndex) {
    final relativeSeatIndex = (seatIndex - _labelEastSeatIndex) % 4;
    final wind = switch (relativeSeatIndex) {
      0 => 'East',
      1 => 'South',
      2 => 'West',
      3 => 'North',
      _ => 'Seat',
    };
    return '$wind\n${_seatName(seatIndex)}';
  }

  @override
  Widget build(BuildContext context) {
    final saveBlockingMessage = _saveBlockingMessage;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialHand == null ? 'Record Hand' : 'Edit Hand'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (saveBlockingMessage != null) ...[
              Text(
                saveBlockingMessage,
                key: const ValueKey('saveHandValidationSummary'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _controller.isSubmitting || _choosingFalseWinCaller
                  ? null
                  : _submit,
              child: Text(_controller.isSubmitting ? 'Saving...' : 'Save Hand'),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_roundExpired) ...[
                Text(
                  'Round time has expired.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
              ],
              if (_isEditingLegacyFalseWin)
                _HandEntrySection(
                  number: '1',
                  title: 'Legacy False Win',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Legacy false win penalty',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _penaltySeatIndex == null
                            ? 'False win caller: Unknown'
                            : 'False win caller: ${_seatLabel(_penaltySeatIndex!)}',
                      ),
                    ],
                  ),
                )
              else
                _HandEntrySection(
                  number: '1',
                  title: 'Result',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<HandResultType>(
                        segments: const [
                          ButtonSegment(
                            value: HandResultType.win,
                            label: Text('Win'),
                          ),
                          ButtonSegment(
                            value: HandResultType.washout,
                            label: Text('Draw'),
                          ),
                        ],
                        selected: {_resultType},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _resultType = selection.first;
                            if (_resultType == HandResultType.washout) {
                              _winnerSeatIndex = null;
                              _discarderSeatIndex = null;
                              _penaltySeatIndex = null;
                              _winType = null;
                              _capturedPhoto = null;
                            } else {
                              _winType ??= HandWinType.selfDraw;
                              _penaltySeatIndex = null;
                            }
                            _choosingFalseWinCaller = false;
                          });
                        },
                      ),
                      if (widget.initialHand == null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _controller.isSubmitting
                              ? null
                              : _showFalseWinCallerPicker,
                          icon: const Icon(Icons.warning_amber_outlined),
                          label: const Text('Record False Win'),
                        ),
                      ],
                      if (_sessionDetail
                          .pendingFalseWinPenalties.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'False win callers: ${_sessionDetail.pendingFalseWinPenalties.map((penalty) => _seatLabel(penalty.penaltySeatIndex)).join(', ')}',
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (_choosingFalseWinCaller) ...[
                _HandEntrySection(
                  number: '2',
                  title: 'False Win Caller',
                  child: _buildSeatButtonGrid(
                    prompt: 'Choose false win caller',
                    target: _PlayerScanTarget.penaltyCaller,
                  ),
                ),
              ],
              if (!_choosingFalseWinCaller &&
                  _resultType == HandResultType.win) ...[
                _HandEntrySection(
                  number: '2',
                  title: 'Winner',
                  child: _buildSeatButtonGrid(
                    prompt: 'Choose winner',
                    target: _PlayerScanTarget.winner,
                  ),
                ),
                if (_draft.winnerSeatError != null) ...[
                  const SizedBox(height: 6),
                  Text(_draft.winnerSeatError!),
                ],
                const SizedBox(height: 16),
                _HandEntrySection(
                  number: '3',
                  title: 'Score',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Self-draw'),
                            selected: _winType == HandWinType.selfDraw,
                            onSelected: (_) {
                              setState(() {
                                _winType = HandWinType.selfDraw;
                                _discarderSeatIndex = null;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Discard'),
                            selected: _winType == HandWinType.discard,
                            onSelected: (_) {
                              setState(() {
                                _winType = HandWinType.discard;
                              });
                            },
                          ),
                        ],
                      ),
                      if (_draft.winTypeError != null) ...[
                        const SizedBox(height: 6),
                        Text(_draft.winTypeError!),
                      ],
                      if (_winType == HandWinType.discard) ...[
                        const SizedBox(height: 16),
                        _buildSeatButtonGrid(
                          prompt: 'Choose discarder',
                          target: _PlayerScanTarget.discarder,
                        ),
                        if (_draft.discarderSeatError != null) ...[
                          const SizedBox(height: 6),
                          Text(_draft.discarderSeatError!),
                        ],
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Quick fan',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final fanCount in _quickFanCounts)
                            ChoiceChip(
                              label: Text('${fanCount}F'),
                              selected: _fanCount == fanCount,
                              onSelected: (_) => _setFanCount(fanCount),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _FanCountPicker(
                        fanCount: _fanCount,
                        onChanged: _setFanCount,
                        onDecrement: () => _adjustFanCount(-1),
                        onIncrement: () => _adjustFanCount(1),
                      ),
                      if (_draft.fanCountError != null) ...[
                        const SizedBox(height: 6),
                        Text(_draft.fanCountError!),
                      ],
                      const SizedBox(height: 16),
                      if (widget.initialHand == null)
                        OutlinedButton.icon(
                          onPressed:
                              _controller.isSubmitting || _isCapturingPhoto
                                  ? null
                                  : _captureWinningHandPhoto,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(
                            _capturedPhoto == null
                                ? 'Capture winning hand photo'
                                : 'Retake winning hand photo',
                          ),
                        ),
                      if (_existingPhotoStatusLabel
                          case final photoStatus?) ...[
                        const SizedBox(height: 6),
                        Text(
                          photoStatus,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.initialHand!.photoClientId!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ] else if (_capturedPhoto != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Photo captured',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ] else if (_draft.photoEvidenceError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _draft.photoEvidenceError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (_draft.washoutFieldError != null) ...[
                const SizedBox(height: 6),
                Text(_draft.washoutFieldError!),
              ],
              if (!_choosingFalseWinCaller &&
                  _resultType == HandResultType.washout) ...[
                _HandEntrySection(
                  number: '2',
                  title: 'Draw',
                  child: Text(
                    'Dealer: ${_seatName(_drawDealerSeatIndex)}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
              if (_draft.canBuildPreview) ...[
                const SizedBox(height: 20),
                const Text(
                  'Scoring Preview',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_buildPreviewText()),
              ],
              if (widget.initialHand != null) ...[
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _controller.isSubmitting ? null : _voidHand,
                  child: const Text('Void Hand'),
                ),
              ],
              if (_controller.submitError != null) ...[
                const SizedBox(height: 12),
                Text(_controller.submitError!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildPreviewText() {
    if (_resultType == HandResultType.washout) {
      return 'Draw. Dealer rotates.';
    }

    if (_resultType == HandResultType.falseWinPenalty) {
      final caller = _penaltySeatIndex == null
          ? 'Unknown'
          : _seatLabel(_penaltySeatIndex!);
      return '$caller false win penalty. East retains.';
    }

    final winner =
        _winnerSeatIndex == null ? 'Unknown' : _seatLabel(_winnerSeatIndex!);
    final winType = _winType == HandWinType.discard ? 'discard' : 'self-draw';
    return '$winner wins by $winType for $_fanCount fan.';
  }
}

class _FanCountPicker extends StatelessWidget {
  const _FanCountPicker({
    required this.fanCount,
    required this.onChanged,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int fanCount;
  final ValueChanged<int> onChanged;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canDecrement = fanCount > minimumWinningFan;
    final canIncrement = fanCount < _maximumWinningFan;

    return Semantics(
      key: const ValueKey('fanCountPicker'),
      label: 'Fan Count',
      value: '$fanCount fan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${fanCount}F',
            key: const ValueKey('fanCountValueLabel'),
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('fanCountDecrement'),
                onPressed: canDecrement ? onDecrement : null,
                icon: const Icon(Icons.remove),
                tooltip: 'Decrease fan count',
              ),
              Expanded(
                child: Slider(
                  key: const ValueKey('fanCountSlider'),
                  value: fanCount.toDouble(),
                  min: minimumWinningFan.toDouble(),
                  max: _maximumWinningFan.toDouble(),
                  divisions: _maximumWinningFan - minimumWinningFan,
                  label: '${fanCount}F',
                  semanticFormatterCallback: (value) => '${value.round()} fan',
                  onChanged: (value) => onChanged(value.round()),
                ),
              ),
              IconButton.filledTonal(
                key: const ValueKey('fanCountIncrement'),
                onPressed: canIncrement ? onIncrement : null,
                icon: const Icon(Icons.add),
                tooltip: 'Increase fan count',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 58),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$minimumWinningFan',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '$_maximumWinningFan',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HandEntrySection extends StatelessWidget {
  const _HandEntrySection({
    required this.number,
    required this.title,
    required this.child,
  });

  final String number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$number. $title',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
