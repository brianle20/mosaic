import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';

class EventHandLedgerRowViewModel {
  const EventHandLedgerRowViewModel({
    required this.handId,
    required this.handLabel,
    required this.loggedTimeLabel,
    required this.resultSummary,
    required this.cells,
    required this.isVoided,
    required this.hasDataIssue,
  });

  final String handId;
  final String handLabel;
  final String loggedTimeLabel;
  final String resultSummary;
  final List<EventHandLedgerCellViewModel> cells;
  final bool isVoided;
  final bool hasDataIssue;
}

class EventHandLedgerCellViewModel {
  const EventHandLedgerCellViewModel({
    required this.displayName,
    required this.pointsDelta,
    required this.pointsLabel,
  });

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
  final hasDataIssue = entry.resultType == HandResultType.win &&
      entry.status == HandResultStatus.recorded &&
      !entry.hasSettlements;

  return EventHandLedgerRowViewModel(
    handId: entry.handId,
    handLabel:
        '${entry.tableLabel} · Session ${entry.sessionNumberForTable} · Hand ${entry.handNumber}',
    loggedTimeLabel: _loggedTimeLabel(entry.enteredAt),
    resultSummary: hasDataIssue ? 'needs review' : _resultSummary(entry),
    cells: entry.cells
        .map(
          (cell) => EventHandLedgerCellViewModel(
            displayName: _firstName(cell.displayName),
            pointsDelta: cell.pointsDelta,
            pointsLabel: _signedPoints(cell.pointsDelta),
          ),
        )
        .toList(growable: false),
    isVoided: entry.status == HandResultStatus.voided,
    hasDataIssue: hasDataIssue,
  );
}

String _resultSummary(EventHandLedgerEntry entry) {
  if (entry.status == HandResultStatus.voided) {
    return 'voided';
  }
  if (entry.resultType == HandResultType.washout) {
    return 'washout';
  }

  final fanCount = entry.fanCount;
  final winType = switch (entry.winType) {
    HandWinType.discard => 'discard',
    HandWinType.selfDraw => 'self draw',
    null => 'win',
  };

  if (fanCount == null) {
    return winType;
  }
  return '$fanCount fan $winType';
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
