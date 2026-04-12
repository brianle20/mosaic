import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/controllers/session_detail_controller.dart';
import 'package:mosaic/features/scoring/screens/hand_entry_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.eventId,
    required this.sessionId,
    required this.guestRepository,
    required this.sessionRepository,
  });

  final String eventId;
  final String sessionId;
  final GuestRepository guestRepository;
  final SessionRepository sessionRepository;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final SessionDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SessionDetailController(
      guestRepository: widget.guestRepository,
      sessionRepository: widget.sessionRepository,
    )
      ..addListener(_handleUpdate)
      ..load(eventId: widget.eventId, sessionId: widget.sessionId);
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

  Future<void> _openHandEntry({HandResultRecord? hand}) async {
    final detail = _controller.detail;
    if (detail == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<SessionDetailRecord>(
        builder: (_) => HandEntryScreen(
          sessionDetail: detail,
          guestNamesById: _controller.guestNamesById,
          sessionRepository: widget.sessionRepository,
          initialHand: hand,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _controller.load(
        eventId: widget.eventId, sessionId: widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _controller.detail;

    return Scaffold(
      appBar: AppBar(title: const Text('Session Detail')),
      floatingActionButton: FilledButton(
        onPressed: detail == null ? null : _openHandEntry,
        child: const Text('Record Hand'),
      ),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: () => _controller.load(
          eventId: widget.eventId,
          sessionId: widget.sessionId,
        ),
        child: detail == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Current East',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(_guestNameForSeat(
                      detail, detail.session.currentDealerSeatIndex)),
                  const SizedBox(height: 16),
                  Text(
                    'Seats',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final seat in detail.seats)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_guestNameForSeat(detail, seat.seatIndex)),
                      subtitle: Text(_windLabel(seat.seatIndex)),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Hand History',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final hand in detail.hands)
                    Card(
                      child: ListTile(
                        title: Text('Hand ${hand.handNumber}'),
                        subtitle: Text(_handSummary(detail, hand)),
                        onTap: () => _openHandEntry(hand: hand),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  String _guestNameForSeat(SessionDetailRecord detail, int seatIndex) {
    final seat =
        detail.seats.firstWhere((entry) => entry.seatIndex == seatIndex);
    return _controller.guestNamesById[seat.eventGuestId] ?? seat.eventGuestId;
  }

  String _windLabel(int seatIndex) {
    return switch (seatIndex) {
      0 => 'East',
      1 => 'South',
      2 => 'West',
      3 => 'North',
      _ => 'Seat',
    };
  }

  String _handSummary(SessionDetailRecord detail, HandResultRecord hand) {
    if (hand.resultType == HandResultType.washout) {
      return 'Washout. East retains.';
    }

    final winnerName = _guestNameForSeat(detail, hand.winnerSeatIndex!);
    if (hand.winType == HandWinType.discard) {
      return '$winnerName wins by discard, ${hand.fanCount} fan';
    }

    return '$winnerName wins by self-draw, ${hand.fanCount} fan';
  }
}
