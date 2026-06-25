import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/controllers/hand_entry_controller.dart';
import 'package:mosaic/features/scoring/models/hand_result_draft.dart';
import 'package:mosaic/features/scoring/models/round_timer_state.dart';

enum _PlayerScanTarget { winner, discarder, penaltyCaller }

const _tableSeatOrder = [0, 3, 1, 2];

class HandEntryScreen extends StatefulWidget {
  const HandEntryScreen({
    super.key,
    required this.sessionDetail,
    required this.guestNamesById,
    required this.sessionRepository,
    this.initialHand,
  });

  final SessionDetailRecord sessionDetail;
  final Map<String, String> guestNamesById;
  final SessionRepository sessionRepository;
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
  late final TextEditingController _fanCountController;

  @override
  void initState() {
    super.initState();
    _sessionDetail = widget.sessionDetail;
    _controller =
        HandEntryController(sessionRepository: widget.sessionRepository)
          ..addListener(_handleUpdate);
    final initialHand = widget.initialHand;
    _resultType = initialHand?.resultType ?? HandResultType.win;
    _winType = initialHand?.winType ?? HandWinType.selfDraw;
    _winnerSeatIndex = initialHand?.winnerSeatIndex;
    _discarderSeatIndex = initialHand?.discarderSeatIndex;
    _penaltySeatIndex = initialHand?.penaltySeatIndex;
    _fanCountController = TextEditingController(
      text: initialHand?.fanCount?.toString() ?? '',
    );
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
    _fanCountController.dispose();
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
        fanCount: _resultType == HandResultType.win
            ? int.tryParse(_fanCountController.text)
            : null,
        dealerWasWaitingAtDraw: null,
        blockedWinnerSeatIndexes:
            widget.initialHand == null ? _blockedWinnerSeatIndexes : const {},
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

  Future<void> _submit() async {
    if (_choosingFalseWinCaller) {
      return;
    }
    if (!_draft.isValid) {
      setState(() {});
      return;
    }

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialHand == null ? 'Record Hand' : 'Edit Hand'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _controller.isSubmitting || _choosingFalseWinCaller
              ? null
              : _submit,
          child: Text(_controller.isSubmitting ? 'Saving...' : 'Save Hand'),
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
                Column(
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
                )
              else
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
                      } else {
                        _winType ??= HandWinType.selfDraw;
                        _penaltySeatIndex = null;
                      }
                      _choosingFalseWinCaller = false;
                    });
                  },
                ),
              const SizedBox(height: 16),
              if (widget.initialHand == null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _controller.isSubmitting
                        ? null
                        : _showFalseWinCallerPicker,
                    icon: const Icon(Icons.warning_amber_outlined),
                    label: const Text('Record False Win'),
                  ),
                ),
              ],
              if (_sessionDetail.pendingFalseWinPenalties.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'False win callers: ${_sessionDetail.pendingFalseWinPenalties.map((penalty) => _seatLabel(penalty.penaltySeatIndex)).join(', ')}',
                ),
              ],
              if (_choosingFalseWinCaller) ...[
                const SizedBox(height: 16),
                _buildSeatButtonGrid(
                  prompt: 'Choose false win caller',
                  target: _PlayerScanTarget.penaltyCaller,
                ),
              ],
              const SizedBox(height: 16),
              if (!_choosingFalseWinCaller &&
                  _resultType == HandResultType.win) ...[
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
                const SizedBox(height: 16),
                _buildSeatButtonGrid(
                  prompt: 'Choose winner',
                  target: _PlayerScanTarget.winner,
                ),
                if (_draft.winnerSeatError != null) ...[
                  const SizedBox(height: 6),
                  Text(_draft.winnerSeatError!),
                ],
                const SizedBox(height: 16),
                if (_winType == HandWinType.discard) ...[
                  _buildSeatButtonGrid(
                    prompt: 'Choose discarder',
                    target: _PlayerScanTarget.discarder,
                  ),
                  if (_draft.discarderSeatError != null) ...[
                    const SizedBox(height: 6),
                    Text(_draft.discarderSeatError!),
                  ],
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _fanCountController,
                  decoration: const InputDecoration(labelText: 'Fan Count'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                if (_draft.fanCountError != null) ...[
                  const SizedBox(height: 6),
                  Text(_draft.fanCountError!),
                ],
              ],
              if (_draft.washoutFieldError != null) ...[
                const SizedBox(height: 6),
                Text(_draft.washoutFieldError!),
              ],
              if (!_choosingFalseWinCaller &&
                  _resultType == HandResultType.washout) ...[
                Text(
                  'Dealer: ${_seatName(_drawDealerSeatIndex)}',
                  style: Theme.of(context).textTheme.labelLarge,
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
    final fanCount = int.tryParse(_fanCountController.text) ?? 0;
    final winType = _winType == HandWinType.discard ? 'discard' : 'self-draw';
    return '$winner wins by $winType for $fanCount fan.';
  }
}
