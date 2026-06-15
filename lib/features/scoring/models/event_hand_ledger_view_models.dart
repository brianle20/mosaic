import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';

class EventHandLedgerRowViewModel {
  const EventHandLedgerRowViewModel({
    required this.handId,
    required this.sessionId,
    required this.isHandRow,
    required this.handLabel,
    required this.loggedTimeLabel,
    required this.resultSummary,
    required this.cells,
    required this.isVoided,
    required this.hasDataIssue,
    required this.isBonusRound,
  });

  final String handId;
  final String sessionId;
  final bool isHandRow;
  final String handLabel;
  final String loggedTimeLabel;
  final String resultSummary;
  final List<EventHandLedgerCellViewModel> cells;
  final bool isVoided;
  final bool hasDataIssue;
  final bool isBonusRound;

  Map<String, String> get guestNamesById => {
        if (isHandRow)
          for (final cell in cells)
            if (cell.eventGuestId.isNotEmpty)
              cell.eventGuestId: cell.fullDisplayName,
      };
}

class EventHandLedgerCellViewModel {
  const EventHandLedgerCellViewModel({
    required this.eventGuestId,
    required this.fullDisplayName,
    required this.displayName,
    required this.pointsDelta,
    required this.pointsLabel,
  });

  final String eventGuestId;
  final String fullDisplayName;
  final String displayName;
  final int pointsDelta;
  final String pointsLabel;
}

List<EventHandLedgerRowViewModel> buildEventHandLedgerViewModels(
  List<EventHandLedgerEntry> entries,
) {
  return entries.map(_buildRow).toList(growable: false);
}

EventHandLedgerRowViewModel _buildRow(EventHandLedgerEntry entry) {
  if (entry.rowType == EventHandLedgerRowType.adjustment) {
    return _buildAdjustmentRow(entry);
  }

  final requiresSettlements = entry.resultType == HandResultType.win ||
      entry.resultType == HandResultType.falseWinPenalty;
  final hasDataIssue = requiresSettlements &&
      entry.status == HandResultStatus.recorded &&
      !entry.hasSettlements;

  return EventHandLedgerRowViewModel(
    handId: entry.handId,
    sessionId: entry.sessionId,
    isHandRow: true,
    handLabel:
        '${entry.tableLabel} · Session ${entry.sessionNumberForTable} · Hand ${entry.handNumber}',
    loggedTimeLabel: _loggedTimeLabel(entry.enteredAt),
    resultSummary: hasDataIssue ? 'needs review' : _resultSummary(entry),
    cells: entry.cells
        .map(
          (cell) => EventHandLedgerCellViewModel(
            eventGuestId: cell.eventGuestId,
            fullDisplayName: cell.displayName,
            displayName: _firstName(cell.displayName),
            pointsDelta: cell.pointsDelta,
            pointsLabel: _signedPoints(cell.pointsDelta),
          ),
        )
        .toList(growable: false),
    isVoided: entry.status == HandResultStatus.voided,
    hasDataIssue: hasDataIssue,
    isBonusRound: entry.bonusRoundId != null,
  );
}

EventHandLedgerRowViewModel _buildAdjustmentRow(EventHandLedgerEntry entry) {
  final amount = entry.adjustmentAmountPoints ?? 0;
  return EventHandLedgerRowViewModel(
    handId: entry.handId,
    sessionId: '',
    isHandRow: false,
    handLabel: _adjustmentLabel(entry),
    loggedTimeLabel: _loggedTimeLabel(entry.enteredAt),
    resultSummary: _adjustmentSummary(entry),
    cells: [
      EventHandLedgerCellViewModel(
        eventGuestId: entry.adjustmentEventGuestId ?? '',
        fullDisplayName: entry.adjustmentDisplayName ?? 'Champion',
        displayName: _firstName(entry.adjustmentDisplayName ?? 'Champion'),
        pointsDelta: amount,
        pointsLabel: _signedPoints(amount),
      ),
    ],
    isVoided: false,
    hasDataIssue: false,
    isBonusRound: entry.bonusRoundId != null,
  );
}

String _resultSummary(EventHandLedgerEntry entry) {
  if (entry.status == HandResultStatus.voided) {
    return 'voided';
  }
  if (entry.resultType == HandResultType.washout) {
    return 'draw';
  }
  if (entry.resultType == HandResultType.falseWinPenalty) {
    return '${entry.fanCount ?? 6} fan false win penalty';
  }

  final fanCount = entry.fanCount;
  final winType = switch (entry.winType) {
    HandWinType.discard => 'discard',
    HandWinType.selfDraw => 'self-draw',
    null => 'win',
  };

  if (fanCount == null) {
    return winType;
  }
  return '$fanCount fan $winType';
}

String _adjustmentLabel(EventHandLedgerEntry entry) {
  return switch (entry.adjustmentType) {
    'finals_champion_award' => 'Champion award',
    _ => 'Event adjustment',
  };
}

String _adjustmentSummary(EventHandLedgerEntry entry) {
  if (entry.adjustmentType != 'finals_champion_award') {
    return _signedPoints(entry.adjustmentAmountPoints ?? 0);
  }

  final bonusScore = _contextInt(
    entry.adjustmentContextJson,
    'champion_bonus_score_points',
  );
  final topUp = _contextInt(
    entry.adjustmentContextJson,
    'champion_top_up_points',
  );

  if (bonusScore == null || topUp == null) {
    return _signedPoints(entry.adjustmentAmountPoints ?? 0);
  }

  return 'Bonus ${_signedPoints(bonusScore)} · Top ${_signedPoints(topUp)}';
}

int? _contextInt(Map<String, dynamic> context, String key) {
  final value = context[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

String _loggedTimeLabel(DateTime enteredAt) {
  final local = enteredAt.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $meridiem';
}

String _firstName(String displayName) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) {
    return displayName;
  }
  return trimmed.split(RegExp(r'\s+')).first;
}

String _signedPoints(int points) {
  if (points > 0) {
    return '+$points';
  }
  return '$points';
}
