import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/offline/offline_models.dart';

class ProjectedSessionDetail {
  const ProjectedSessionDetail({
    required this.detail,
    required this.syncSnapshot,
  });

  final SessionDetailRecord detail;
  final SessionSyncSnapshot syncSnapshot;
}

class OfflineSessionProjector {
  const OfflineSessionProjector();

  static const duplicateFalseWinPenaltyMessage =
      'False win caller already has a pending penalty.';

  static final DateTime _dealerCompoundCapEffectiveAt =
      DateTime.utc(2026, 5, 19, 14);

  ProjectedSessionDetail project({
    required SessionDetailRecord detail,
    required List<OfflineMutationRecord> mutations,
  }) {
    final remoteHandMutationIds = detail.hands
        .map((hand) => hand.clientMutationId)
        .whereType<String>()
        .toSet();
    final relevant = mutations
        .where(
          (mutation) =>
              mutation.sessionId == detail.session.id &&
              mutation.status != OfflineMutationStatus.synced &&
              !remoteHandMutationIds.contains(mutation.id),
        )
        .toList(growable: false)
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));

    var dealer = detail.session.currentDealerSeatIndex;
    var dealerPassCount = detail.session.dealerPassCount;
    var dealerWinStreak = _currentDealerWinStreak(detail.hands);
    var completedGames = detail.session.completedGamesCount;
    var handCount = detail.session.handCount;
    final hands = [...detail.hands];
    final falseWinPenalties = [...detail.falseWinPenalties];
    final pendingFalseWinPenaltySeats = <int>{};
    for (final penalty in falseWinPenalties) {
      if (penalty.status != FalseWinPenaltyStatus.pending) {
        continue;
      }
      if (!pendingFalseWinPenaltySeats.add(penalty.penaltySeatIndex)) {
        throw StateError(duplicateFalseWinPenaltyMessage);
      }
    }
    final pendingHandIds = <String>{};
    final blockedHandIds = <String>{};
    String? blockedReason;

    for (final mutation in relevant) {
      final pendingHandId = 'pending:${mutation.id}';
      final isBlocked = mutation.status == OfflineMutationStatus.blocked;

      if (mutation.kind == OfflineMutationKind.recordFalseWinPenalty) {
        if (isBlocked) {
          blockedHandIds.add(pendingHandId);
          blockedReason ??= mutation.lastError;
        } else {
          final penaltySeatIndex = _requiredInt(
            mutation.payload['target_penalty_seat_index'],
          );
          if (!pendingFalseWinPenaltySeats.add(penaltySeatIndex)) {
            throw StateError(duplicateFalseWinPenaltyMessage);
          }
          falseWinPenalties.add(
            FalseWinPenaltyRecord(
              id: pendingHandId,
              tableSessionId: detail.session.id,
              penaltySeatIndex: penaltySeatIndex,
              fanCount: 6,
              enteredByUserId: 'offline',
              enteredAt: mutation.createdAt,
              status: FalseWinPenaltyStatus.pending,
              correctionNote:
                  mutation.payload['target_correction_note'] as String?,
            ),
          );
          pendingHandIds.add(pendingHandId);
        }
        continue;
      }

      final resultType = _resultType(mutation.payload['target_result_type']);
      final winnerSeatIndex =
          _optionalInt(mutation.payload['target_winner_seat_index']);
      final eastBefore = dealer;
      final projectedState = isBlocked
          ? _ProjectedHandState(
              eastAfter: dealer,
              dealerPassCount: dealerPassCount,
              dealerWinStreak: dealerWinStreak,
            )
          : _projectHandState(
              currentEast: dealer,
              dealerPassCount: dealerPassCount,
              dealerWinStreak: dealerWinStreak,
              resultType: resultType,
              winnerSeatIndex: winnerSeatIndex,
              enteredAt: mutation.createdAt,
            );
      final dealerRotated = projectedState.eastAfter != eastBefore;

      hands.add(
        HandResultRecord(
          id: pendingHandId,
          tableSessionId: detail.session.id,
          handNumber: mutation.localHandNumber,
          resultType: resultType,
          winnerSeatIndex: winnerSeatIndex,
          winType: _winType(mutation.payload['target_win_type']),
          discarderSeatIndex:
              _optionalInt(mutation.payload['target_discarder_seat_index']),
          penaltySeatIndex:
              _optionalInt(mutation.payload['target_penalty_seat_index']),
          fanCount: _projectedFanCount(resultType, mutation.payload),
          dealerWasWaitingAtDraw: _optionalBool(
            mutation.payload['target_dealer_was_waiting_at_draw'],
          ),
          eastSeatIndexBeforeHand: eastBefore,
          eastSeatIndexAfterHand: projectedState.eastAfter,
          dealerRotated: dealerRotated,
          sessionCompletedAfterHand: false,
          status: HandResultStatus.recorded,
          enteredByUserId: 'offline',
          enteredAt: mutation.createdAt,
          correctionNote: 'Pending sync',
        ),
      );

      if (isBlocked) {
        blockedHandIds.add(pendingHandId);
        blockedReason ??= mutation.lastError;
        continue;
      } else {
        pendingHandIds.add(pendingHandId);
      }

      if (resultType == HandResultType.win ||
          resultType == HandResultType.washout) {
        for (var index = 0; index < falseWinPenalties.length; index += 1) {
          final penalty = falseWinPenalties[index];
          if (penalty.status != FalseWinPenaltyStatus.pending) {
            continue;
          }
          falseWinPenalties[index] = FalseWinPenaltyRecord(
            id: penalty.id,
            tableSessionId: penalty.tableSessionId,
            handResultId: pendingHandId,
            penaltySeatIndex: penalty.penaltySeatIndex,
            fanCount: penalty.fanCount,
            enteredByUserId: penalty.enteredByUserId,
            enteredAt: penalty.enteredAt,
            status: FalseWinPenaltyStatus.attached,
            correctionNote: penalty.correctionNote,
          );
          pendingFalseWinPenaltySeats.remove(penalty.penaltySeatIndex);
        }
      }

      dealer = projectedState.eastAfter;
      dealerPassCount = projectedState.dealerPassCount;
      dealerWinStreak = projectedState.dealerWinStreak;
      completedGames += 1;
      handCount += 1;
    }

    final projectedSession = TableSessionRecord.fromJson({
      ...detail.session.toJson(),
      'current_dealer_seat_index': dealer,
      'dealer_pass_count': dealerPassCount,
      'completed_games_count': completedGames,
      'hand_count': handCount,
    });

    return ProjectedSessionDetail(
      detail: SessionDetailRecord(
        session: projectedSession,
        seats: detail.seats,
        hands: hands,
        settlements: detail.settlements,
        falseWinPenalties: falseWinPenalties,
        tableLabel: detail.tableLabel,
      ),
      syncSnapshot: SessionSyncSnapshot(
        sessionId: detail.session.id,
        pendingHandIds: pendingHandIds,
        blockedHandIds: blockedHandIds,
        pendingCount: pendingHandIds.length,
        isBlocked: blockedHandIds.isNotEmpty,
        blockedReason: blockedReason,
      ),
    );
  }

  HandResultType _resultType(Object? value) {
    return switch (value) {
      'win' => HandResultType.win,
      'washout' => HandResultType.washout,
      'false_win_penalty' => HandResultType.falseWinPenalty,
      _ => throw FormatException('Unknown pending hand result type: $value'),
    };
  }

  HandWinType? _winType(Object? value) {
    return switch (value) {
      'discard' => HandWinType.discard,
      'self_draw' => HandWinType.selfDraw,
      null => null,
      _ => throw FormatException('Unknown pending win type: $value'),
    };
  }

  _ProjectedHandState _projectHandState({
    required int currentEast,
    required int dealerPassCount,
    required int dealerWinStreak,
    required HandResultType resultType,
    required int? winnerSeatIndex,
    required DateTime enteredAt,
  }) {
    var eastAfter = currentEast;
    var nextPassCount = dealerPassCount;
    var nextDealerWinStreak = dealerWinStreak;

    switch (resultType) {
      case HandResultType.win when winnerSeatIndex == currentEast:
        if (_isDealerCompoundCapEffective(enteredAt)) {
          nextDealerWinStreak += 1;

          if (nextDealerWinStreak >= 2) {
            eastAfter = _nextDealer(currentEast);
            nextPassCount += 1;
            nextDealerWinStreak = 0;
          }
        }
      case HandResultType.win:
        eastAfter = _nextDealer(currentEast);
        nextPassCount += 1;
        nextDealerWinStreak = 0;
      case HandResultType.washout:
        eastAfter = _nextDealer(currentEast);
        nextPassCount += 1;
        nextDealerWinStreak = 0;
      case HandResultType.falseWinPenalty:
        break;
    }

    return _ProjectedHandState(
      eastAfter: eastAfter,
      dealerPassCount: nextPassCount,
      dealerWinStreak: nextDealerWinStreak,
    );
  }

  int? _projectedFanCount(
    HandResultType resultType,
    Map<String, dynamic> payload,
  ) {
    if (resultType == HandResultType.falseWinPenalty) {
      return _optionalInt(payload['target_fan_count']) ?? 6;
    }
    return _optionalInt(payload['target_fan_count']);
  }

  int? _optionalInt(Object? value) {
    return switch (value) {
      null => null,
      int() => value,
      num() => value.toInt(),
      _ => throw FormatException('Expected int or null, got $value.'),
    };
  }

  int _requiredInt(Object? value) {
    final parsed = _optionalInt(value);
    if (parsed == null) {
      throw const FormatException('Expected int, got null.');
    }
    return parsed;
  }

  bool? _optionalBool(Object? value) {
    return switch (value) {
      null => null,
      bool() => value,
      _ => throw FormatException('Expected bool or null, got $value.'),
    };
  }

  int _currentDealerWinStreak(List<HandResultRecord> hands) {
    var streak = 0;
    final recordedHands = hands
        .where((hand) => hand.status == HandResultStatus.recorded)
        .toList(growable: false)
      ..sort((left, right) => left.handNumber.compareTo(right.handNumber));

    for (final hand in recordedHands) {
      switch (hand.resultType) {
        case HandResultType.win:
          final dealerWon =
              hand.winnerSeatIndex == hand.eastSeatIndexBeforeHand;
          if (!dealerWon) {
            streak = 0;
          } else if (hand.dealerRotated) {
            streak = 0;
          } else if (_isDealerCompoundCapEffective(hand.enteredAt)) {
            streak += 1;
          }
        case HandResultType.washout:
          if (hand.dealerRotated) {
            streak = 0;
          }
        case HandResultType.falseWinPenalty:
          if (hand.dealerRotated) {
            streak = 0;
          }
      }
    }

    return streak;
  }

  bool _isDealerCompoundCapEffective(DateTime enteredAt) {
    return !enteredAt.toUtc().isBefore(_dealerCompoundCapEffectiveAt);
  }

  int _nextDealer(int currentEast) => (currentEast + 1) % 4;
}

class _ProjectedHandState {
  const _ProjectedHandState({
    required this.eastAfter,
    required this.dealerPassCount,
    required this.dealerWinStreak,
  });

  final int eastAfter;
  final int dealerPassCount;
  final int dealerWinStreak;
}
