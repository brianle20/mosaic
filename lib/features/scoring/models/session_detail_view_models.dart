import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/features/scoring/models/round_timer_state.dart';

class SessionDetailViewModel {
  const SessionDetailViewModel({
    required this.title,
    required this.contextLabel,
    required this.statusLabel,
    required this.handCountLabel,
    required this.currentEastLabel,
    required this.progressLabel,
    required this.roundTimeLabel,
    required this.isRoundExpired,
    required this.isRoundEndingSoon,
    required this.seats,
    required this.hands,
    required this.archivedHands,
    required this.emptyHandHistoryLabel,
  });

  final String title;
  final String contextLabel;
  final String statusLabel;
  final String handCountLabel;
  final String currentEastLabel;
  final String progressLabel;
  final String roundTimeLabel;
  final bool isRoundExpired;
  final bool isRoundEndingSoon;
  final List<SessionSeatViewModel> seats;
  final List<SessionHandViewModel> hands;
  final List<SessionHandViewModel> archivedHands;
  final String emptyHandHistoryLabel;
}

class SessionSeatViewModel {
  const SessionSeatViewModel({
    required this.seatIndex,
    required this.guestId,
    required this.guestName,
    required this.seatLabel,
    required this.isCurrentEast,
  });

  final int seatIndex;
  final String guestId;
  final String guestName;
  final String seatLabel;
  final bool isCurrentEast;
}

class SessionHandViewModel {
  const SessionHandViewModel({
    required this.handId,
    required this.handNumber,
    required this.title,
    required this.summaryLabel,
    required this.isVoided,
  });

  final String handId;
  final int handNumber;
  final String title;
  final String summaryLabel;
  final bool isVoided;
}

SessionDetailViewModel buildSessionDetailViewModel({
  required SessionDetailRecord detail,
  required Map<String, String> guestNamesById,
  DateTime? now,
}) {
  final currentEastSeatIndex = detail.session.currentDealerSeatIndex;
  final roundTime = RoundTimerState.fromStartedAt(
    startedAt: detail.session.startedAt,
    now: now,
  );
  final currentEastName = _guestNameForSeat(
    detail,
    guestNamesById,
    currentEastSeatIndex,
  );
  final recordedHandCount = detail.hands
      .where((hand) => hand.status != HandResultStatus.voided)
      .length;

  return SessionDetailViewModel(
    title: detail.tableLabel ?? 'Table Session',
    contextLabel: _contextLabel(detail),
    statusLabel: _statusLabel(detail.session.status),
    handCountLabel: _handCountLabel(recordedHandCount),
    currentEastLabel: 'East: ${_firstName(currentEastName)}',
    progressLabel: _progressLabel(detail),
    roundTimeLabel: roundTime.label,
    isRoundExpired: roundTime.isExpired,
    isRoundEndingSoon: roundTime.isEndingSoon,
    seats: detail.seats
        .map(
          (seat) => SessionSeatViewModel(
            seatIndex: seat.seatIndex,
            guestId: seat.eventGuestId,
            guestName: guestNamesById[seat.eventGuestId] ?? seat.eventGuestId,
            seatLabel: _seatLabel(seat.seatIndex, currentEastSeatIndex),
            isCurrentEast: seat.seatIndex == currentEastSeatIndex,
          ),
        )
        .toList(growable: false),
    hands: detail.hands
        .where((hand) => hand.status == HandResultStatus.recorded)
        .map(
          (hand) => SessionHandViewModel(
            handId: hand.id,
            handNumber: hand.handNumber,
            title: 'Hand ${hand.handNumber}',
            summaryLabel: _handSummary(detail, guestNamesById, hand),
            isVoided: hand.status == HandResultStatus.voided,
          ),
        )
        .toList(growable: false),
    archivedHands: detail.hands
        .where((hand) => hand.status == HandResultStatus.voided)
        .map(
          (hand) => SessionHandViewModel(
            handId: hand.id,
            handNumber: hand.handNumber,
            title: 'Voided Hand ${hand.handNumber}',
            summaryLabel: _handSummary(detail, guestNamesById, hand),
            isVoided: true,
          ),
        )
        .toList(growable: false),
    emptyHandHistoryLabel: 'No hands recorded yet.',
  );
}

String _contextLabel(SessionDetailRecord detail) {
  final sessionNumber = detail.session.sessionNumberForTable;
  return 'Current session · Session $sessionNumber';
}

String _statusLabel(SessionStatus status) {
  return switch (status) {
    SessionStatus.active => 'Active',
    SessionStatus.paused => 'Paused',
    SessionStatus.completed => 'Completed',
    SessionStatus.endedEarly => 'Ended Early',
    SessionStatus.aborted => 'Aborted',
  };
}

String _handCountLabel(int recordedHandCount) {
  final noun = recordedHandCount == 1 ? 'Hand' : 'Hands';
  return '$noun $recordedHandCount';
}

String _progressLabel(SessionDetailRecord detail) {
  final completedGames = detail.session.completedGamesCount;
  final noun = completedGames == 1 ? 'game' : 'games';
  return '$completedGames $noun complete';
}

String _seatLabel(int seatIndex, int currentEastSeatIndex) {
  return _windLabel(seatIndex, currentEastSeatIndex).toUpperCase();
}

String _handSummary(
  SessionDetailRecord detail,
  Map<String, String> guestNamesById,
  HandResultRecord hand,
) {
  if (hand.status == HandResultStatus.voided) {
    final correctionNote = hand.correctionNote?.trim();
    if (correctionNote == null || correctionNote.isEmpty) {
      return 'Voided';
    }
    return 'Voided · $correctionNote';
  }

  if (hand.resultType == HandResultType.washout) {
    return [
      'Draw',
      hand.dealerRotated ? 'East rotated' : 'East retained',
      'No points exchanged',
    ].join(' · ');
  }

  if (hand.resultType == HandResultType.falseWinPenalty) {
    return _falseWinPenaltySummary(detail, guestNamesById, hand);
  }

  return _winSummary(detail, guestNamesById, hand);
}

String _falseWinPenaltySummary(
  SessionDetailRecord detail,
  Map<String, String> guestNamesById,
  HandResultRecord hand,
) {
  final penaltySeatIndex = hand.penaltySeatIndex;
  final callerName = penaltySeatIndex == null
      ? 'Caller'
      : _guestNameForSeat(detail, guestNamesById, penaltySeatIndex);
  final fanCount = hand.fanCount ?? 6;
  final parts = <String>[
    '$callerName false win penalty',
    '$fanCount fan to each player',
    hand.dealerRotated ? 'East rotated' : 'East retained',
  ];

  final callerGuestId = penaltySeatIndex == null
      ? null
      : _guestIdForSeat(detail, penaltySeatIndex);
  final pointImpact = callerGuestId == null
      ? null
      : _pointImpactForGuest(detail, hand.id, callerGuestId);
  if (pointImpact != null) {
    parts.add('$callerName ${_signedPoints(pointImpact)}');
  } else {
    parts.add('No points exchanged');
  }

  return parts.join(' · ');
}

String _winSummary(
  SessionDetailRecord detail,
  Map<String, String> guestNamesById,
  HandResultRecord hand,
) {
  final winnerSeatIndex = hand.winnerSeatIndex;
  final winnerName = winnerSeatIndex == null
      ? 'Winner'
      : _guestNameForSeat(detail, guestNamesById, winnerSeatIndex);
  final winType = switch (hand.winType) {
    HandWinType.discard => 'discard',
    HandWinType.selfDraw => 'self-draw',
    null => 'win',
  };

  final parts = <String>[
    '$winnerName won by $winType',
    if (hand.fanCount case final fanCount?) '$fanCount fan',
  ];

  final discarderSeatIndex = hand.discarderSeatIndex;
  if (hand.winType == HandWinType.discard && discarderSeatIndex != null) {
    final discarderName = _guestNameForSeat(
      detail,
      guestNamesById,
      discarderSeatIndex,
    );
    parts.add('$discarderName discarded');
  }

  parts.add(hand.dealerRotated ? 'East rotated' : 'East retained');

  final winnerGuestId =
      winnerSeatIndex == null ? null : _guestIdForSeat(detail, winnerSeatIndex);
  final pointImpact = winnerGuestId == null
      ? null
      : _pointImpactForGuest(detail, hand.id, winnerGuestId);
  if (pointImpact != null) {
    parts.add('$winnerName ${_signedPoints(pointImpact)}');
  } else {
    parts.add('No points exchanged');
  }

  return parts.join(' · ');
}

int? _pointImpactForGuest(
  SessionDetailRecord detail,
  String handId,
  String guestId,
) {
  var impact = 0;
  var hasSettlement = false;

  for (final settlement in detail.settlements) {
    if (settlement.handResultId != handId) {
      continue;
    }

    hasSettlement = true;
    if (settlement.payeeEventGuestId == guestId) {
      impact += settlement.amountPoints;
    }
    if (settlement.payerEventGuestId == guestId) {
      impact -= settlement.amountPoints;
    }
  }

  return hasSettlement ? impact : null;
}

String _guestNameForSeat(
  SessionDetailRecord detail,
  Map<String, String> guestNamesById,
  int seatIndex,
) {
  final guestId = _guestIdForSeat(detail, seatIndex);
  return guestNamesById[guestId] ?? guestId;
}

String _guestIdForSeat(SessionDetailRecord detail, int seatIndex) {
  for (final seat in detail.seats) {
    if (seat.seatIndex == seatIndex) {
      return seat.eventGuestId;
    }
  }

  return 'seat_$seatIndex';
}

String _firstName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return name;
  }
  return trimmed.split(RegExp(r'\s+')).first;
}

String _windLabel(int seatIndex, int currentEastSeatIndex) {
  final relativeSeatIndex = (seatIndex - currentEastSeatIndex) % 4;
  return switch (relativeSeatIndex) {
    0 => 'East',
    1 => 'South',
    2 => 'West',
    3 => 'North',
    _ => 'Seat $seatIndex',
  };
}

String _signedPoints(int points) {
  if (points > 0) {
    return '+$points';
  }
  return '$points';
}
