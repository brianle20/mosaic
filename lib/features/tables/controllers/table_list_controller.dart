import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/models/table_overview_card_data.dart';

class TableListController extends ChangeNotifier {
  TableListController({
    required TableRepository tableRepository,
    required SessionRepository sessionRepository,
    required GuestRepository guestRepository,
  })  : _tableRepository = tableRepository,
        _sessionRepository = sessionRepository,
        _guestRepository = guestRepository;

  final TableRepository _tableRepository;
  final SessionRepository _sessionRepository;
  final GuestRepository _guestRepository;

  bool isLoading = true;
  String? error;
  List<EventTableRecord> tables = const [];
  Map<String, TableSessionRecord> activeSessionsByTableId = const {};
  Map<String, SessionDetailRecord> sessionDetailsBySessionId = const {};
  Map<String, String> guestNamesById = const {};
  List<TableOverviewCardData> cards = const [];

  Future<void> load(String eventId) async {
    final cachedTables = await _tableRepository.readCachedTables(eventId);
    final cachedSessions = await _sessionRepository.readCachedSessions(eventId);
    final cachedGuests = await _guestRepository.readCachedGuests(eventId);

    isLoading = true;
    error = null;
    tables = cachedTables;
    activeSessionsByTableId = _activeSessionsByTable(cachedSessions);
    guestNamesById = _guestNamesById(cachedGuests);
    sessionDetailsBySessionId =
        await _readCachedDetails(activeSessionsByTableId.values);
    cards = _buildCards();
    notifyListeners();

    try {
      tables = await _tableRepository.listTables(eventId);
    } catch (exception) {
      if (tables.isEmpty && activeSessionsByTableId.isEmpty) {
        error = exception.toString();
      }
    }

    try {
      final guests = await _guestRepository.listGuests(eventId);
      guestNamesById = _guestNamesById(guests);
    } catch (_) {
      // Cached guest names are enough for the table list fallback.
    }

    try {
      final sessions = await _sessionRepository.listSessions(eventId);
      activeSessionsByTableId = _activeSessionsByTable(sessions);
      sessionDetailsBySessionId =
          await _loadDetails(activeSessionsByTableId.values);
    } catch (exception) {
      if (tables.isEmpty && activeSessionsByTableId.isEmpty) {
        error ??= exception.toString();
      }
    }

    cards = _buildCards();
    isLoading = false;
    notifyListeners();
  }

  Map<String, TableSessionRecord> _activeSessionsByTable(
    List<TableSessionRecord> sessions,
  ) {
    return {
      for (final session in sessions)
        if (session.status == SessionStatus.active ||
            session.status == SessionStatus.paused)
          session.eventTableId: session,
    };
  }

  Map<String, String> _guestNamesById(List<EventGuestRecord> guests) {
    return {
      for (final guest in guests) guest.id: guest.displayName,
    };
  }

  Future<Map<String, SessionDetailRecord>> _readCachedDetails(
    Iterable<TableSessionRecord> sessions,
  ) async {
    final details = <String, SessionDetailRecord>{};
    for (final session in sessions) {
      final detail = await _sessionRepository.readCachedSessionDetail(
        session.id,
      );
      if (detail != null) {
        details[session.id] = detail;
      }
    }
    return details;
  }

  Future<Map<String, SessionDetailRecord>> _loadDetails(
    Iterable<TableSessionRecord> sessions,
  ) async {
    final entries = await Future.wait(
      sessions.map((session) async {
        try {
          final detail = await _sessionRepository.loadSessionDetail(
            session.id,
          );
          return MapEntry(session.id, detail);
        } catch (_) {
          final cached = await _sessionRepository.readCachedSessionDetail(
            session.id,
          );
          if (cached != null) {
            return MapEntry(session.id, cached);
          }
        }
        return null;
      }),
    );

    return {
      for (final entry in entries)
        if (entry != null) entry.key: entry.value,
    };
  }

  List<TableOverviewCardData> _buildCards() {
    return [
      for (final table in tables)
        TableOverviewCardData(
          table: table,
          liveSummary: _liveSummaryFor(table),
        ),
    ];
  }

  LiveTableSummary? _liveSummaryFor(EventTableRecord table) {
    final session = activeSessionsByTableId[table.id];
    if (session == null) {
      return null;
    }

    final detail = sessionDetailsBySessionId[session.id];
    if (detail == null) {
      return LiveTableSummary(
        sessionId: session.id,
        status: session.status,
        seats: _fallbackSeats(session),
        handCount: session.handCount,
        progressLabel: _progressLabel(session.handCount),
        lastHand: const LastHandSummary(title: 'No scores yet'),
      );
    }

    final recordedHands = detail.hands
        .where((hand) => hand.status == HandResultStatus.recorded)
        .toList(growable: false)
      ..sort((left, right) => left.handNumber.compareTo(right.handNumber));
    final latestHand = recordedHands.isEmpty ? null : recordedHands.last;
    final handCount = recordedHands.length;

    return LiveTableSummary(
      sessionId: session.id,
      status: session.status,
      seats: _seatSummaries(detail),
      handCount: handCount,
      progressLabel: _progressLabel(handCount),
      lastHand: _lastHandSummary(detail, latestHand),
    );
  }

  List<SeatSummary> _fallbackSeats(TableSessionRecord session) {
    return [
      for (var index = 0; index < 4; index += 1)
        SeatSummary(
          seatIndex: index,
          windLabel: _windLabel(index),
          guestName: 'Unassigned',
          isDealer: index == session.currentDealerSeatIndex,
        ),
    ];
  }

  List<SeatSummary> _seatSummaries(SessionDetailRecord detail) {
    return [
      for (var index = 0; index < 4; index += 1)
        SeatSummary(
          seatIndex: index,
          windLabel: _windLabel(index),
          guestName: _guestNameForSeat(detail, index),
          isDealer: index == detail.session.currentDealerSeatIndex,
        ),
    ];
  }

  String _guestNameForSeat(SessionDetailRecord detail, int seatIndex) {
    final matchingSeats =
        detail.seats.where((seat) => seat.seatIndex == seatIndex);
    if (matchingSeats.isEmpty) {
      return 'Unassigned';
    }

    final guestId = matchingSeats.first.eventGuestId;
    return guestNamesById[guestId] ?? guestId;
  }

  LastHandSummary _lastHandSummary(
    SessionDetailRecord detail,
    HandResultRecord? hand,
  ) {
    if (hand == null) {
      return const LastHandSummary(title: 'No scores yet');
    }

    if (hand.resultType == HandResultType.washout) {
      return const LastHandSummary(
        title: 'Washout',
        detail: 'East retains. Ready for the next hand.',
      );
    }

    final winnerSeatIndex = hand.winnerSeatIndex;
    final winner = winnerSeatIndex == null
        ? 'Winner'
        : _guestNameForSeat(detail, winnerSeatIndex);
    final winLabel =
        hand.winType == HandWinType.discard ? 'wins by discard' : 'self-draw';
    final fanCount = hand.fanCount;
    return LastHandSummary(
      title: '$winner $winLabel',
      detail: fanCount == null
          ? 'Score recorded. Ready for the next hand.'
          : '$fanCount fan recorded. Ready for the next hand.',
    );
  }

  String _progressLabel(int handCount) {
    if (handCount == 0) {
      return 'No hands recorded';
    }
    return 'Hand $handCount';
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
}
