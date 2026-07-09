import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/features/scoring/models/hand_result_draft.dart';
import 'package:mosaic/features/scoring/models/hand_win_bonus.dart';

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

    test('win draft rejects pending false win caller as winner', () {
      const draft = HandResultDraft(
        resultType: HandResultType.win,
        winnerSeatIndex: 2,
        winType: HandWinType.selfDraw,
        fanCount: 3,
        blockedWinnerSeatIndexes: {2},
      );

      expect(draft.winnerSeatError, 'False win callers cannot win this hand.');
      expect(draft.isValid, isFalse);
    });

    test('new rated win requires local photo path', () {
      const draft = HandResultDraft(
        resultType: HandResultType.win,
        winnerSeatIndex: 0,
        winType: HandWinType.selfDraw,
        fanCount: 3,
        requiresPhoto: true,
      );

      expect(draft.photoEvidenceError, 'Capture a photo of the winning hand.');
      expect(draft.isValid, isFalse);
      expect(draft.canBuildPreview, isTrue);
    });

    test('photo is not required for washout or correction', () {
      const washout = HandResultDraft(
        resultType: HandResultType.washout,
        requiresPhoto: true,
      );
      const correction = HandResultDraft(
        resultType: HandResultType.win,
        winnerSeatIndex: 0,
        winType: HandWinType.selfDraw,
        fanCount: 3,
        requiresPhoto: false,
      );

      expect(washout.photoEvidenceError, isNull);
      expect(correction.photoEvidenceError, isNull);
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

    test('draw does not require or send dealer waiting state', () {
      const draft = HandResultDraft(
        resultType: HandResultType.washout,
      );
      const legacyDealerWaitingDraft = HandResultDraft(
        resultType: HandResultType.washout,
        dealerWasWaitingAtDraw: true,
      );

      expect(draft.washoutDealerWaitingError, isNull);
      expect(draft.isValid, isTrue);
      expect(
        draft.toRecordInput(tableSessionId: 'ses_01').dealerWasWaitingAtDraw,
        isNull,
      );
      expect(legacyDealerWaitingDraft.isValid, isTrue);
      expect(
          legacyDealerWaitingDraft
              .toRecordInput(tableSessionId: 'ses_01')
              .dealerWasWaitingAtDraw,
          isNull);
    });

    test('false win penalty requires caller and clears win-only edit fields',
        () {
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

      final input = validDraft.toEditInput(handResultId: 'hand_01');
      expect(input.resultType, HandResultType.falseWinPenalty);
      expect(input.penaltySeatIndex, 1);
      expect(input.winnerSeatIndex, isNull);
      expect(input.winType, isNull);
      expect(input.discarderSeatIndex, isNull);
      expect(input.fanCount, isNull);
      expect(input.dealerWasWaitingAtDraw, isNull);
    });

    test('false win penalty cannot build a new hand record input', () {
      const draft = HandResultDraft(
        resultType: HandResultType.falseWinPenalty,
        penaltySeatIndex: 1,
      );

      expect(
        () => draft.toRecordInput(tableSessionId: 'ses_01'),
        throwsStateError,
      );
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

    test('win record input serializes explicit win bonuses', () {
      const draft = HandResultDraft(
        resultType: HandResultType.win,
        winnerSeatIndex: 0,
        fanCount: 5,
        winType: HandWinType.selfDraw,
        winBonuses: [HandWinBonus.concealedHand, HandWinBonus.moonUnderTheSea],
      );

      final input = draft.toRecordInput(tableSessionId: 'ses_01');

      expect(input.winBonuses, [
        HandWinBonus.concealedHand,
        HandWinBonus.moonUnderTheSea,
      ]);
      expect(input.toRpcParams()['target_win_bonuses'], [
        'concealed_hand',
        'moon_under_the_sea',
      ]);
    });

    test('win record input normalizes unknown win bonuses to explicit empty',
        () {
      const draft = HandResultDraft(
        resultType: HandResultType.win,
        winnerSeatIndex: 0,
        fanCount: 3,
        winType: HandWinType.selfDraw,
        winBonuses: null,
      );

      expect(
        draft
            .toRecordInput(tableSessionId: 'ses_01')
            .toRpcParams()['target_win_bonuses'],
        <String>[],
      );
    });

    test('known empty win bonuses serialize as an empty list', () {
      const draft = HandResultDraft(
        resultType: HandResultType.win,
        winnerSeatIndex: 0,
        fanCount: 3,
        winType: HandWinType.selfDraw,
        winBonuses: [],
      );

      expect(
        draft
            .toRecordInput(tableSessionId: 'ses_01')
            .toRpcParams()['target_win_bonuses'],
        <String>[],
      );
    });

    test('non-win drafts clear win bonuses', () {
      const draw = HandResultDraft(
        resultType: HandResultType.washout,
        winBonuses: [HandWinBonus.concealedHand],
      );
      const penalty = HandResultDraft(
        resultType: HandResultType.falseWinPenalty,
        penaltySeatIndex: 1,
        winBonuses: [HandWinBonus.moonUnderTheSea],
      );

      expect(draw.toRecordInput(tableSessionId: 'ses_01').winBonuses, isNull);
      expect(penalty.toEditInput(handResultId: 'hand_01').winBonuses, isNull);
    });

    test('win edit input preserves unknown win bonuses', () {
      const draft = HandResultDraft(
        resultType: HandResultType.win,
        winnerSeatIndex: 0,
        fanCount: 3,
        winType: HandWinType.selfDraw,
        winBonuses: null,
      );

      expect(draft.toEditInput(handResultId: 'hand_01').winBonuses, isNull);
      expect(
        draft.toEditInput(handResultId: 'hand_01').toRpcParams(),
        containsPair('target_win_bonuses', null),
      );
    });

    test('hand result record preserves unknown empty and selected bonuses', () {
      final unknown = HandResultRecord.fromJson({
        ..._handResultJson(),
        'win_bonuses': null,
      });
      final none = HandResultRecord.fromJson({
        ..._handResultJson(),
        'win_bonuses': <String>[],
      });
      final selected = HandResultRecord.fromJson({
        ..._handResultJson(),
        'win_bonuses': ['robbing_the_kong'],
      });

      expect(unknown.winBonuses, isNull);
      expect(none.winBonuses, isEmpty);
      expect(selected.winBonuses, [HandWinBonus.robbingTheKong]);
      expect(selected.toJson()['win_bonuses'], ['robbing_the_kong']);
    });

    test('hand result record rejects malformed win bonus arrays', () {
      expect(
        () => HandResultRecord.fromJson({
          ..._handResultJson(),
          'win_bonuses': [1],
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

Map<String, dynamic> _handResultJson() {
  return {
    'id': 'hand_01',
    'table_session_id': 'ses_01',
    'hand_number': 1,
    'result_type': 'win',
    'winner_seat_index': 0,
    'win_type': 'self_draw',
    'discarder_seat_index': null,
    'penalty_seat_index': null,
    'fan_count': 3,
    'base_points': null,
    'dealer_was_waiting_at_draw': null,
    'east_seat_index_before_hand': 0,
    'east_seat_index_after_hand': 0,
    'dealer_rotated': false,
    'session_completed_after_hand': false,
    'status': 'recorded',
    'entered_by_user_id': 'host_01',
    'entered_at': '2026-07-09T12:00:00Z',
    'correction_note': null,
    'row_version': 1,
    'client_mutation_id': null,
    'photo_id': null,
    'photo_client_id': null,
    'photo_captured_at': null,
    'photo_upload_status': null,
    'photo_storage_bucket': null,
    'photo_storage_path': null,
  };
}
