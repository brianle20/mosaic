import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/controllers/hand_entry_controller.dart';
import 'package:mosaic/features/scoring/models/hand_result_draft.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

enum _PlayerScanTarget { winner, discarder }

class HandEntryScreen extends StatefulWidget {
  const HandEntryScreen({
    super.key,
    required this.sessionDetail,
    required this.guestNamesById,
    required this.sessionRepository,
    this.guestTagAssignmentsByGuestId = const {},
    this.nfcService,
    this.initialHand,
  });

  final SessionDetailRecord sessionDetail;
  final Map<String, String> guestNamesById;
  final Map<String, GuestTagAssignmentSummary> guestTagAssignmentsByGuestId;
  final SessionRepository sessionRepository;
  final NfcService? nfcService;
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
  _PlayerScanTarget _playerScanTarget = _PlayerScanTarget.winner;
  late final TextEditingController _fanCountController;
  StreamSubscription<TagScanResult>? _playerTagSubscription;

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
    _fanCountController = TextEditingController(
      text: initialHand?.fanCount?.toString() ?? '',
    );
    if (widget.nfcService case final PassiveNfcService passiveNfcService) {
      _playerTagSubscription = passiveNfcService.playerTagScans.listen(
        _handlePlayerTagScan,
      );
    }
  }

  @override
  void dispose() {
    _playerTagSubscription?.cancel();
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

  void _handlePlayerTagScan(TagScanResult scanResult) {
    if (_resultType != HandResultType.win) {
      return;
    }

    final scannedSeatIndex = _seatIndexForPlayerTag(scanResult.normalizedUid);
    if (scannedSeatIndex == null || !mounted) {
      return;
    }

    setState(() {
      _winType ??= HandWinType.selfDraw;
      final scanSetsDiscarder = _winType == HandWinType.discard &&
          _playerScanTarget == _PlayerScanTarget.discarder;
      if (scanSetsDiscarder) {
        if (_winnerSeatIndex != scannedSeatIndex) {
          _discarderSeatIndex = scannedSeatIndex;
        }
      } else {
        _winnerSeatIndex = scannedSeatIndex;
        if (_discarderSeatIndex == scannedSeatIndex) {
          _discarderSeatIndex = null;
        }
        if (_winType == HandWinType.discard) {
          _playerScanTarget = _PlayerScanTarget.discarder;
        }
      }
    });
  }

  int? _seatIndexForPlayerTag(String normalizedUid) {
    final scannedUid = normalizedUid.toUpperCase();
    for (final seat in widget.sessionDetail.seats) {
      final assignment = widget.guestTagAssignmentsByGuestId[seat.eventGuestId];
      if (assignment == null) {
        continue;
      }

      if (assignment.tag.uidHex.toUpperCase() == scannedUid) {
        return seat.seatIndex;
      }
    }
    return null;
  }

  HandResultDraft get _draft => HandResultDraft(
        resultType: _resultType,
        winnerSeatIndex: _winnerSeatIndex,
        winType: _resultType == HandResultType.win ? _winType : null,
        discarderSeatIndex:
            _resultType == HandResultType.win ? _discarderSeatIndex : null,
        fanCount: _resultType == HandResultType.win
            ? int.tryParse(_fanCountController.text)
            : null,
      );

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
    final seat = widget.sessionDetail.seats.firstWhere(
      (entry) => entry.seatIndex == seatIndex,
    );
    final guestName =
        widget.guestNamesById[seat.eventGuestId] ?? seat.eventGuestId;
    final wind = switch (seat.seatIndex) {
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

  bool get _canScanPlayers =>
      widget.nfcService is PassiveNfcService &&
      widget.guestTagAssignmentsByGuestId.isNotEmpty;

  String get _playerScanHelpText {
    if (_winType == HandWinType.discard &&
        _playerScanTarget == _PlayerScanTarget.discarder) {
      return 'Next scan sets discarder.';
    }
    return _winType == HandWinType.discard
        ? 'Next scan sets winner.'
        : 'Scan a player tag to set winner.';
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<HandResultType>(
            segments: const [
              ButtonSegment(
                value: HandResultType.win,
                label: Text('Win'),
              ),
              ButtonSegment(
                value: HandResultType.washout,
                label: Text('Washout'),
              ),
            ],
            selected: {_resultType},
            onSelectionChanged: (selection) {
              setState(() {
                _resultType = selection.first;
                if (_resultType == HandResultType.washout) {
                  _winnerSeatIndex = null;
                  _discarderSeatIndex = null;
                  _winType = null;
                  _playerScanTarget = _PlayerScanTarget.winner;
                } else {
                  _winType ??= HandWinType.selfDraw;
                }
              });
            },
          ),
          const SizedBox(height: 16),
          if (_resultType == HandResultType.win) ...[
            DropdownButtonFormField<int>(
              initialValue: _winnerSeatIndex,
              decoration: const InputDecoration(labelText: 'Winner'),
              items: winnerItems,
              onChanged: (value) {
                setState(() {
                  _winnerSeatIndex = value;
                  if (_discarderSeatIndex == value) {
                    _discarderSeatIndex = null;
                  }
                  if (_winType == HandWinType.discard && value != null) {
                    _playerScanTarget = _PlayerScanTarget.discarder;
                  }
                });
              },
            ),
            if (_draft.winnerSeatError != null) ...[
              const SizedBox(height: 6),
              Text(_draft.winnerSeatError!),
            ],
            if (_canScanPlayers) ...[
              const SizedBox(height: 6),
              Text(
                _playerScanHelpText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Self Draw'),
                  selected: _winType == HandWinType.selfDraw,
                  onSelected: (_) {
                    setState(() {
                      _winType = HandWinType.selfDraw;
                      _discarderSeatIndex = null;
                      _playerScanTarget = _PlayerScanTarget.winner;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Discard'),
                  selected: _winType == HandWinType.discard,
                  onSelected: (_) {
                    setState(() {
                      _winType = HandWinType.discard;
                      _playerScanTarget = _winnerSeatIndex == null
                          ? _PlayerScanTarget.winner
                          : _PlayerScanTarget.discarder;
                    });
                  },
                ),
              ],
            ),
            if (_draft.winTypeError != null) ...[
              const SizedBox(height: 6),
              Text(_draft.winTypeError!),
            ],
            if (_canScanPlayers && _winType == HandWinType.discard) ...[
              const SizedBox(height: 16),
              Text(
                'Scan Target',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SegmentedButton<_PlayerScanTarget>(
                segments: const [
                  ButtonSegment(
                    value: _PlayerScanTarget.winner,
                    label: Text('Winner scan'),
                  ),
                  ButtonSegment(
                    value: _PlayerScanTarget.discarder,
                    label: Text('Discarder scan'),
                  ),
                ],
                selected: {_playerScanTarget},
                onSelectionChanged: (selection) {
                  setState(() {
                    _playerScanTarget = selection.first;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            if (_winType == HandWinType.discard)
              DropdownButtonFormField<int>(
                initialValue: _discarderSeatIndex,
                decoration: const InputDecoration(labelText: 'Discarder'),
                items: discarderItems,
                onChanged: (value) {
                  setState(() {
                    _discarderSeatIndex = value;
                  });
                },
              ),
            if (_draft.discarderSeatError != null) ...[
              const SizedBox(height: 6),
              Text(_draft.discarderSeatError!),
            ],
          ],
          if (_draft.washoutFieldError != null) ...[
            const SizedBox(height: 6),
            Text(_draft.washoutFieldError!),
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
    );
  }

  String _buildPreviewText() {
    if (_resultType == HandResultType.washout) {
      return 'Washout. East retains.';
    }

    final winner =
        _winnerSeatIndex == null ? 'Unknown' : _seatLabel(_winnerSeatIndex!);
    final fanCount = int.tryParse(_fanCountController.text) ?? 0;
    final winType = _winType == HandWinType.discard ? 'discard' : 'self-draw';
    return '$winner wins by $winType for $fanCount fan.';
  }
}
