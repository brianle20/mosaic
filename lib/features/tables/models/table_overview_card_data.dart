import 'package:meta/meta.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';

@immutable
class TableOverviewCardData {
  const TableOverviewCardData({
    required this.table,
    this.liveSummary,
  });

  final EventTableRecord table;
  final LiveTableSummary? liveSummary;

  bool get isLive => liveSummary != null;
}

@immutable
class LiveTableSummary {
  const LiveTableSummary({
    required this.sessionId,
    required this.status,
    required this.seats,
    required this.handCount,
    required this.progressLabel,
    required this.lastHand,
  });

  final String sessionId;
  final SessionStatus status;
  final List<SeatSummary> seats;
  final int handCount;
  final String progressLabel;
  final LastHandSummary lastHand;
}

@immutable
class SeatSummary {
  const SeatSummary({
    required this.seatIndex,
    required this.windLabel,
    required this.guestName,
    required this.isDealer,
  });

  final int seatIndex;
  final String windLabel;
  final String guestName;
  final bool isDealer;
}

@immutable
class LastHandSummary {
  const LastHandSummary({
    required this.title,
    this.detail,
  });

  final String title;
  final String? detail;
}
