import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/features/scoring/models/hand_result_draft.dart';

void main() {
  group('HandResultDraft', () {
    test('win requires winner fan count and win type', () {
      const draft = HandResultDraft(resultType: HandResultType.win);

      expect(draft.winnerSeatError, 'Select a winner.');
      expect(draft.fanCountError, 'Enter a non-negative fan count.');
      expect(draft.winTypeError, 'Select how the hand was won.');
      expect(draft.isValid, isFalse);
    });

    test('discard requires a different discarder seat', () {
      const draft = HandResultDraft(
        resultType: HandResultType.win,
        winnerSeatIndex: 1,
        fanCount: 3,
        winType: HandWinType.discard,
        discarderSeatIndex: 1,
      );

      expect(
          draft.discarderSeatError, 'Discarder must be different from winner.');
      expect(draft.isValid, isFalse);
    });

    test('self draw requires null discarder', () {
      const draft = HandResultDraft(
        resultType: HandResultType.win,
        winnerSeatIndex: 0,
        fanCount: 2,
        winType: HandWinType.selfDraw,
        discarderSeatIndex: 3,
      );

      expect(
          draft.discarderSeatError, 'Self-draw wins do not have a discarder.');
      expect(draft.isValid, isFalse);
    });

    test('washout rejects winner discarder and fan fields', () {
      const draft = HandResultDraft(
        resultType: HandResultType.washout,
        winnerSeatIndex: 2,
        fanCount: 4,
        winType: HandWinType.discard,
        discarderSeatIndex: 1,
      );

      expect(draft.washoutFieldError,
          'Washouts cannot include winner, discarder, or fan fields.');
      expect(draft.isValid, isFalse);
    });

    test('preview payload is only available when the draft is valid', () {
      const invalidDraft = HandResultDraft(resultType: HandResultType.win);
      const validDraft = HandResultDraft(
        resultType: HandResultType.win,
        winnerSeatIndex: 0,
        fanCount: 1,
        winType: HandWinType.selfDraw,
      );

      expect(invalidDraft.canBuildPreview, isFalse);
      expect(validDraft.canBuildPreview, isTrue);
      expect(validDraft.toRecordInput(tableSessionId: 'ses_01').winType,
          HandWinType.selfDraw);
    });
  });
}
