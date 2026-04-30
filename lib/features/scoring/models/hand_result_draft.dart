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
    this.fanCount,
    this.correctionNote = '',
  });

  final HandResultType resultType;
  final int? winnerSeatIndex;
  final HandWinType? winType;
  final int? discarderSeatIndex;
  final int? fanCount;
  final String correctionNote;

  String? get winnerSeatError {
    if (resultType == HandResultType.win && winnerSeatIndex == null) {
      return 'Select a winner.';
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
      return 'Washouts cannot include winner, discarder, or fan fields.';
    }

    return null;
  }

  bool get isValid {
    return winnerSeatError == null &&
        fanCountError == null &&
        winTypeError == null &&
        discarderSeatError == null &&
        washoutFieldError == null;
  }

  bool get canBuildPreview => isValid;

  RecordHandResultInput toRecordInput({required String tableSessionId}) {
    return RecordHandResultInput(
      tableSessionId: tableSessionId,
      resultType: resultType,
      winnerSeatIndex:
          resultType == HandResultType.win ? winnerSeatIndex : null,
      winType: resultType == HandResultType.win ? winType : null,
      discarderSeatIndex:
          resultType == HandResultType.win ? discarderSeatIndex : null,
      fanCount: resultType == HandResultType.win ? fanCount : null,
      correctionNote:
          correctionNote.trim().isEmpty ? null : correctionNote.trim(),
    );
  }

  EditHandResultInput toEditInput({required String handResultId}) {
    return EditHandResultInput(
      handResultId: handResultId,
      resultType: resultType,
      winnerSeatIndex:
          resultType == HandResultType.win ? winnerSeatIndex : null,
      winType: resultType == HandResultType.win ? winType : null,
      discarderSeatIndex:
          resultType == HandResultType.win ? discarderSeatIndex : null,
      fanCount: resultType == HandResultType.win ? fanCount : null,
      correctionNote:
          correctionNote.trim().isEmpty ? null : correctionNote.trim(),
    );
  }
}
