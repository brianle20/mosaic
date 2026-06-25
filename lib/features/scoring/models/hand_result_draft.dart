import 'package:meta/meta.dart';
import 'package:mosaic/data/models/scoring_models.dart';

const int minimumWinningFan = 3;

@immutable
class HandResultDraft {
  const HandResultDraft({
    required this.resultType,
    this.winnerSeatIndex,
    this.winType,
    this.discarderSeatIndex,
    this.penaltySeatIndex,
    this.fanCount,
    this.dealerWasWaitingAtDraw,
    this.correctionNote = '',
    this.blockedWinnerSeatIndexes = const {},
  });

  final HandResultType resultType;
  final int? winnerSeatIndex;
  final HandWinType? winType;
  final int? discarderSeatIndex;
  final int? penaltySeatIndex;
  final int? fanCount;
  final bool? dealerWasWaitingAtDraw;
  final String correctionNote;
  final Set<int> blockedWinnerSeatIndexes;

  String? get winnerSeatError {
    if (resultType == HandResultType.win && winnerSeatIndex == null) {
      return 'Select a winner.';
    }

    if (resultType == HandResultType.win &&
        winnerSeatIndex != null &&
        blockedWinnerSeatIndexes.contains(winnerSeatIndex)) {
      return 'False win callers cannot win this hand.';
    }

    return null;
  }

  String? get fanCountError {
    if (resultType == HandResultType.win &&
        (fanCount == null || fanCount! < minimumWinningFan)) {
      return 'Enter at least $minimumWinningFan fan.';
    }

    return null;
  }

  String? get winTypeError {
    if (resultType == HandResultType.win && winType == null) {
      return 'Select how the hand was won.';
    }

    return null;
  }

  String? get discarderSeatError {
    if (resultType != HandResultType.win || winType == null) {
      return null;
    }

    if (winType == HandWinType.discard) {
      if (discarderSeatIndex == null) {
        return 'Select the discarder.';
      }

      if (discarderSeatIndex == winnerSeatIndex) {
        return 'Discarder must be different from winner.';
      }
    }

    if (winType == HandWinType.selfDraw && discarderSeatIndex != null) {
      return 'Self-draw wins do not have a discarder.';
    }

    return null;
  }

  String? get washoutFieldError {
    if (resultType == HandResultType.washout &&
        (winnerSeatIndex != null ||
            winType != null ||
            discarderSeatIndex != null ||
            fanCount != null)) {
      return 'Draws cannot include winner, discarder, or fan fields.';
    }

    return null;
  }

  String? get falseWinPenaltySeatError {
    if (resultType == HandResultType.falseWinPenalty &&
        penaltySeatIndex == null) {
      return 'Select the false win caller.';
    }

    return null;
  }

  String? get washoutDealerWaitingError {
    if (resultType == HandResultType.win && dealerWasWaitingAtDraw != null) {
      return 'Wins cannot include dealer waiting state.';
    }

    return null;
  }

  bool get isValid {
    return winnerSeatError == null &&
        fanCountError == null &&
        winTypeError == null &&
        discarderSeatError == null &&
        washoutFieldError == null &&
        falseWinPenaltySeatError == null &&
        washoutDealerWaitingError == null;
  }

  bool get canBuildPreview => isValid;

  RecordHandResultInput toRecordInput({required String tableSessionId}) {
    if (resultType == HandResultType.falseWinPenalty) {
      throw StateError(
        'False win penalties must be recorded with recordFalseWinPenalty.',
      );
    }

    return RecordHandResultInput(
      tableSessionId: tableSessionId,
      resultType: resultType,
      winnerSeatIndex:
          resultType == HandResultType.win ? winnerSeatIndex : null,
      winType: resultType == HandResultType.win ? winType : null,
      discarderSeatIndex:
          resultType == HandResultType.win ? discarderSeatIndex : null,
      penaltySeatIndex: null,
      fanCount: resultType == HandResultType.win ? fanCount : null,
      dealerWasWaitingAtDraw: null,
      correctionNote:
          correctionNote.trim().isEmpty ? null : correctionNote.trim(),
    );
  }

  EditHandResultInput toEditInput({
    required String handResultId,
    bool? legacyDealerWasWaitingAtDraw,
  }) {
    return EditHandResultInput(
      handResultId: handResultId,
      resultType: resultType,
      winnerSeatIndex:
          resultType == HandResultType.win ? winnerSeatIndex : null,
      winType: resultType == HandResultType.win ? winType : null,
      discarderSeatIndex:
          resultType == HandResultType.win ? discarderSeatIndex : null,
      penaltySeatIndex: resultType == HandResultType.falseWinPenalty
          ? penaltySeatIndex
          : null,
      fanCount: resultType == HandResultType.win ? fanCount : null,
      dealerWasWaitingAtDraw: resultType == HandResultType.washout
          ? legacyDealerWasWaitingAtDraw
          : null,
      correctionNote:
          correctionNote.trim().isEmpty ? null : correctionNote.trim(),
    );
  }
}
