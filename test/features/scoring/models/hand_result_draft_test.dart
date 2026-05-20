import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/features/scoring/models/hand_result_draft.dart';

void main() {
  group('HandResultDraft', () {
    test('win requires winner fan count and win type', () {
      const draft = HandResultDraft(resultType: HandResultType.win);

      expect(draft.winnerSeatError, 'Select a winner.');
      expect(draft.fanCountError, 'Enter at least 3 fan.');
      expect(draft.winTypeError, 'Select how the hand was won.');
      expect(draft.isValid, isFalse);
    });

    test('win requires at least three fan', () {
      const twoFanDraft = HandResultDraft(
        resultType: HandResultType.win,
        winnerSeatIndex: 0,
        fanCount: 2,
        winType: HandWinType.selfDraw,
      );
      const threeFanDraft = HandResultDraft(
        resultType: HandResultType.win,
        winnerSeatIndex: 0,
        fanCount: 3,
        winType: HandWinType.selfDraw,
      );

      expect(twoFanDraft.fanCountError, 'Enter at least 3 fan.');
      expect(twoFanDraft.isValid, isFalse);
      expect(threeFanDraft.fanCountError, isNull);
      expect(threeFanDraft.isValid, isTrue);
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

    test('draw rejects winner discarder and fan fields', () {
      const draft = HandResultDraft(
        resultType: HandResultType.washout,
        winnerSeatIndex: 2,
        fanCount: 4,
        winType: HandWinType.discard,
        discarderSeatIndex: 1,
      );

      expect(draft.washoutFieldError,
          'Draws cannot include winner, discarder, or fan fields.');
      expect(draft.isValid, isFalse);
    });

    test('draw requires whether dealer was waiting', () {
      const missingWaitingDraft = HandResultDraft(
        resultType: HandResultType.washout,
      );
      const dealerWaitingDraft = HandResultDraft(
        resultType: HandResultType.washout,
        dealerWasWaitingAtDraw: true,
      );
      const dealerNotWaitingDraft = HandResultDraft(
        resultType: HandResultType.washout,
        dealerWasWaitingAtDraw: false,
      );

      expect(
        missingWaitingDraft.washoutDealerWaitingError,
        'Select whether dealer was waiting.',
      );
      expect(missingWaitingDraft.isValid, isFalse);
      expect(dealerWaitingDraft.isValid, isTrue);
      expect(
          dealerWaitingDraft
              .toRecordInput(tableSessionId: 'ses_01')
              .dealerWasWaitingAtDraw,
          isTrue);
      expect(dealerNotWaitingDraft.isValid, isTrue);
      expect(
          dealerNotWaitingDraft
              .toRecordInput(tableSessionId: 'ses_01')
              .dealerWasWaitingAtDraw,
          isFalse);
    });

    test('false win penalty requires caller and clears win-only fields', () {
      const missingCallerDraft = HandResultDraft(
        resultType: HandResultType.falseWinPenalty,
      );
      const validDraft = HandResultDraft(
        resultType: HandResultType.falseWinPenalty,
        penaltySeatIndex: 1,
        winnerSeatIndex: 2,
        fanCount: 8,
        winType: HandWinType.discard,
        discarderSeatIndex: 3,
        dealerWasWaitingAtDraw: true,
      );

      expect(
        missingCallerDraft.falseWinPenaltySeatError,
        'Select the false win caller.',
      );
      expect(missingCallerDraft.isValid, isFalse);
      expect(validDraft.isValid, isTrue);

      final input = validDraft.toRecordInput(tableSessionId: 'ses_01');
      expect(input.resultType, HandResultType.falseWinPenalty);
      expect(input.penaltySeatIndex, 1);
      expect(input.winnerSeatIndex, isNull);
      expect(input.winType, isNull);
      expect(input.discarderSeatIndex, isNull);
      expect(input.fanCount, isNull);
      expect(input.dealerWasWaitingAtDraw, isNull);
    });

    test('preview payload is only available when the draft is valid', () {
      const invalidDraft = HandResultDraft(resultType: HandResultType.win);
      const validDraft = HandResultDraft(
        resultType: HandResultType.win,
        winnerSeatIndex: 0,
        fanCount: 3,
        winType: HandWinType.selfDraw,
      );

      expect(invalidDraft.canBuildPreview, isFalse);
      expect(validDraft.canBuildPreview, isTrue);
      expect(validDraft.toRecordInput(tableSessionId: 'ses_01').winType,
          HandWinType.selfDraw);
    });
  });
}
