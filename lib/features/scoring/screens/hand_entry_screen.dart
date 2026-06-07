import 'package:flutter/material.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/controllers/hand_entry_controller.dart';
import 'package:mosaic/features/scoring/models/hand_result_draft.dart';
import 'package:mosaic/features/scoring/models/round_timer_state.dart';

enum _PlayerScanTarget { winner, discarder }

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
  late HandResultType _resultType;
  HandWinType? _winType;
  int? _winnerSeatIndex;
  int? _discarderSeatIndex;
  int? _penaltySeatIndex;
  late final TextEditingController _fanCountController;

  @override
  void initState() {
    super.initState();
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
      widget.sessionDetail.session.currentDealerSeatIndex;

  int get _labelEastSeatIndex =>
      widget.initialHand?.eastSeatIndexBeforeHand ??
      widget.sessionDetail.session.currentDealerSeatIndex;

  String _seatName(int seatIndex) {
    final seat = widget.sessionDetail.seats.firstWhere(
      (entry) => entry.seatIndex == seatIndex,
    );
    return widget.guestNamesById[seat.eventGuestId] ?? seat.eventGuestId;
  }

  HandResultDraft get _draft => HandResultDraft(
        resultType: _resultType,
        winnerSeatIndex: _winnerSeatIndex,
        winType: _resultType == HandResultType.win ? _winType : null,
        discarderSeatIndex:
            _resultType == HandResultType.win ? _discarderSeatIndex : null,
        penaltySeatIndex: _resultType == HandResultType.falseWinPenalty
            ? _penaltySeatIndex
            : null,
        fanCount: _resultType == HandResultType.win
            ? int.tryParse(_fanCountController.text)
            : null,
        dealerWasWaitingAtDraw: null,
      );

  bool get _roundExpired =>
      widget.initialHand == null &&
      _sessionHasRoundTimer &&
      RoundTimerState.fromStartedAt(
        startedAt: widget.sessionDetail.session.startedAt,
        pausedAt: widget.sessionDetail.session.roundTimerPausedAt,
        pausedSeconds: widget.sessionDetail.session.roundTimerPausedSeconds,
      ).isExpired;

  bool get _sessionHasRoundTimer =>
      widget.sessionDetail.session.scoringPhase ==
          EventScoringPhase.tournament ||
      widget.sessionDetail.session.scoringPhase == EventScoringPhase.bonus;

  Future<void> _submit() async {
    if (!_draft.isValid) {
      setState(() {});
      return;
    }

    final detail = await _controller.submit(
      tableSessionId: widget.sessionDetail.session.id,
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

  List<DropdownMenuItem<int>> _seatItems({int? excludingSeatIndex}) {
    return [
      for (var index = 0; index < widget.sessionDetail.seats.length; index++)
        if (index != excludingSeatIndex)
          DropdownMenuItem<int>(
            value: index,
            child: Text(_seatLabel(index)),
          ),
    ];
  }

  _PlayerScanTarget get _activePlayerTarget {
    if (_resultType == HandResultType.win &&
        _winType == HandWinType.discard &&
        _winnerSeatIndex != null) {
      return _PlayerScanTarget.discarder;
    }
    return _PlayerScanTarget.winner;
  }

  String get _seatButtonPrompt {
    if (_activePlayerTarget == _PlayerScanTarget.discarder) {
      return 'Choose discarder';
    }
    return 'Choose winner';
  }

  void _selectSeat(int seatIndex, {_PlayerScanTarget? targetOverride}) {
    if (_resultType != HandResultType.win) {
      return;
    }

    setState(() {
      _winType ??= HandWinType.selfDraw;
      final target = targetOverride ?? _activePlayerTarget;
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

  Widget _buildSeatButtonGrid() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _seatButtonPrompt,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.sessionDetail.seats.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.4,
          ),
          itemBuilder: (context, index) {
            final seat = widget.sessionDetail.seats[index];
            final isDealer = seat.seatIndex == _labelEastSeatIndex;
            final isWinner = seat.seatIndex == _winnerSeatIndex;
            final isDiscarder = seat.seatIndex == _discarderSeatIndex;
            final selectingDiscarder =
                _activePlayerTarget == _PlayerScanTarget.discarder;
            final disabled =
                selectingDiscarder && seat.seatIndex == _winnerSeatIndex;
            final selected = selectingDiscarder ? isDiscarder : isWinner;
            final label = _seatLabelLines(seat.seatIndex);

            return FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: selected
                    ? colorScheme.primary
                    : isDealer
                        ? colorScheme.secondaryContainer
                        : null,
                foregroundColor: selected
                    ? colorScheme.onPrimary
                    : isDealer
                        ? colorScheme.onSecondaryContainer
                        : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: disabled ? null : () => _selectSeat(seat.seatIndex),
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
    final winnerItems = _seatItems();
    final discarderItems = _seatItems(excludingSeatIndex: _winnerSeatIndex);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialHand == null ? 'Record Hand' : 'Edit Hand'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _controller.isSubmitting ? null : _submit,
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
                  ButtonSegment(
                    value: HandResultType.falseWinPenalty,
                    label: Text('False Win'),
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
                    } else if (_resultType == HandResultType.falseWinPenalty) {
                      _winnerSeatIndex = null;
                      _discarderSeatIndex = null;
                      _winType = null;
                    } else {
                      _winType ??= HandWinType.selfDraw;
                      _penaltySeatIndex = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_resultType == HandResultType.win) ...[
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
                _buildSeatButtonGrid(),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _winnerSeatIndex,
                  decoration: const InputDecoration(labelText: 'Winner'),
                  items: winnerItems,
                  onChanged: (value) {
                    if (value != null) {
                      _selectSeat(value,
                          targetOverride: _PlayerScanTarget.winner);
                    }
                  },
                ),
                if (_draft.winnerSeatError != null) ...[
                  const SizedBox(height: 6),
                  Text(_draft.winnerSeatError!),
                ],
                const SizedBox(height: 16),
                if (_winType == HandWinType.discard) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _discarderSeatIndex,
                    decoration: const InputDecoration(labelText: 'Discarder'),
                    items: discarderItems,
                    onChanged: (value) {
                      if (value != null) {
                        _selectSeat(
                          value,
                          targetOverride: _PlayerScanTarget.discarder,
                        );
                      }
                    },
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
              if (_resultType == HandResultType.washout) ...[
                Text(
                  'Dealer: ${_seatName(_drawDealerSeatIndex)}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
              if (_resultType == HandResultType.falseWinPenalty) ...[
                DropdownButtonFormField<int>(
                  initialValue: _penaltySeatIndex,
                  decoration: const InputDecoration(labelText: 'Caller'),
                  items: winnerItems,
                  onChanged: (value) {
                    setState(() {
                      _penaltySeatIndex = value;
                    });
                  },
                ),
                if (_draft.falseWinPenaltySeatError != null) ...[
                  const SizedBox(height: 6),
                  Text(_draft.falseWinPenaltySeatError!),
                ],
                const SizedBox(height: 8),
                const Text('6 fan to each player.'),
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
