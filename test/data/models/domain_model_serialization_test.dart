import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/tag_models.dart';

void main() {
  group('CreateEventInput', () {
    test('serializes event wall time as a UTC instant for its timezone', () {
      final input = CreateEventInput(
        title: 'Friday Night Mahjong',
        timezone: 'America/Los_Angeles',
        startsAt: DateTime(2026, 4, 29, 22),
        coverChargeCents: 2000,
      );

      expect(
        input.toInsertJson(ownerUserId: 'usr_01')['starts_at'],
        '2026-04-30T05:00:00.000Z',
      );
    });
  });

  group('EventRecord', () {
    test('round-trips lifecycle status from JSON', () {
      final record = EventRecord.fromJson(const {
        'id': 'evt_01',
        'owner_user_id': 'usr_01',
        'title': 'Friday Night Mahjong',
        'timezone': 'America/Los_Angeles',
        'starts_at': '2026-04-24T19:00:00-07:00',
        'lifecycle_status': 'draft',
        'checkin_open': false,
        'scoring_open': false,
        'cover_charge_cents': 2000,
        'default_ruleset_id': 'HK_STANDARD_V1',
        'prevailing_wind': 'east',
      });

      expect(record.lifecycleStatus, EventLifecycleStatus.draft);
      expect(record.toJson()['lifecycle_status'], 'draft');
    });
  });

  group('EventGuestRecord', () {
    test('parses Instagram handles from nested guest profiles', () {
      final guest = EventGuestRecord.fromJson(const {
        'id': 'gst_01',
        'event_id': 'evt_01',
        'display_name': 'Legacy Name',
        'normalized_name': 'legacy name',
        'attendance_status': 'expected',
        'cover_status': 'unpaid',
        'cover_amount_cents': 0,
        'is_comped': false,
        'has_scored_play': false,
        'guest_profile': {
          'id': 'prf_01',
          'owner_user_id': 'usr_01',
          'display_name': 'Brian Le',
          'normalized_name': 'brian le',
          'instagram_handle': 'brian.le',
        },
      });

      expect(guest.displayName, 'Brian Le');
      expect(guest.instagramHandle, 'brian.le');
      expect(guest.toJson()['instagram_handle'], 'brian.le');
    });

    test('allows player tag assignment only for paid or comped guests', () {
      final paidGuest = EventGuestRecord.fromJson(const {
        'id': 'gst_paid',
        'event_id': 'evt_01',
        'display_name': 'Alice',
        'normalized_name': 'alice',
        'attendance_status': 'checked_in',
        'cover_status': 'paid',
        'cover_amount_cents': 2000,
        'is_comped': false,
        'has_scored_play': false,
      });
      final compedGuest = EventGuestRecord.fromJson(const {
        'id': 'gst_comp',
        'event_id': 'evt_01',
        'display_name': 'Bob',
        'normalized_name': 'bob',
        'attendance_status': 'checked_in',
        'cover_status': 'comped',
        'cover_amount_cents': 0,
        'is_comped': true,
        'has_scored_play': false,
      });
      final unpaidGuest = EventGuestRecord.fromJson(const {
        'id': 'gst_unpaid',
        'event_id': 'evt_01',
        'display_name': 'Carol',
        'normalized_name': 'carol',
        'attendance_status': 'expected',
        'cover_status': 'unpaid',
        'cover_amount_cents': 0,
        'is_comped': false,
        'has_scored_play': false,
      });

      expect(paidGuest.isEligibleForPlayerTagAssignment, isTrue);
      expect(compedGuest.isEligibleForPlayerTagAssignment, isTrue);
      expect(unpaidGuest.isEligibleForPlayerTagAssignment, isFalse);
    });

    test('exposes checked-in state from attendance status', () {
      final checkedInGuest = EventGuestRecord.fromJson(const {
        'id': 'gst_checked_in',
        'event_id': 'evt_01',
        'display_name': 'Dana',
        'normalized_name': 'dana',
        'attendance_status': 'checked_in',
        'cover_status': 'paid',
        'cover_amount_cents': 2000,
        'is_comped': false,
        'has_scored_play': false,
      });
      final expectedGuest = EventGuestRecord.fromJson(const {
        'id': 'gst_expected',
        'event_id': 'evt_01',
        'display_name': 'Eli',
        'normalized_name': 'eli',
        'attendance_status': 'expected',
        'cover_status': 'paid',
        'cover_amount_cents': 2000,
        'is_comped': false,
        'has_scored_play': false,
      });

      expect(checkedInGuest.isCheckedIn, isTrue);
      expect(expectedGuest.isCheckedIn, isFalse);
    });
  });

  group('GuestTagAssignmentSummary', () {
    test('parses an active assignment with nested player tag', () {
      final summary = GuestTagAssignmentSummary.fromJson(const {
        'assignment_id': 'asg_01',
        'event_id': 'evt_01',
        'event_guest_id': 'gst_01',
        'status': 'assigned',
        'assigned_at': '2026-04-24T19:15:00-07:00',
        'nfc_tag': {
          'id': 'tag_01',
          'uid_hex': '04AABBCCDD',
          'uid_fingerprint': '04AABBCCDD',
          'default_tag_type': 'player',
          'status': 'active',
          'display_label': 'Player 7',
        },
      });

      expect(summary.isActive, isTrue);
      expect(summary.tag.uidHex, '04AABBCCDD');
      expect(summary.tag.defaultTagType, NfcTagType.player);
    });
  });

  group('TableSessionRecord', () {
    test('stores ruleset and rotation policy explicitly', () {
      final record = TableSessionRecord.fromJson(const {
        'id': 'ses_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_01',
        'session_number_for_table': 1,
        'ruleset_id': 'HK_STANDARD_V1',
        'ruleset_version': 1,
        'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'rotation_policy_config_json': {},
        'status': 'active',
        'initial_east_seat_index': 0,
        'current_dealer_seat_index': 0,
        'dealer_pass_count': 0,
        'completed_games_count': 0,
        'hand_count': 0,
        'started_at': '2026-04-24T19:00:00-07:00',
        'started_by_user_id': 'usr_01',
      });

      expect(record.rulesetId, 'HK_STANDARD_V1');
      expect(
        record.rotationPolicyType,
        RotationPolicyType.dealerCycleReturnToInitialEast,
      );
    });

    test('parses ordered session seats and preserves explicit ruleset shape',
        () {
      final startedSession = StartedTableSessionRecord.fromJson(
        sessionJson: const {
          'id': 'ses_01',
          'event_id': 'evt_01',
          'event_table_id': 'tbl_01',
          'session_number_for_table': 1,
          'ruleset_id': 'HK_STANDARD_V1',
          'ruleset_version': 1,
          'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
          'rotation_policy_config_json': {},
          'status': 'active',
          'initial_east_seat_index': 0,
          'current_dealer_seat_index': 0,
          'dealer_pass_count': 0,
          'completed_games_count': 0,
          'hand_count': 0,
          'started_at': '2026-04-24T19:00:00-07:00',
          'started_by_user_id': 'usr_01',
        },
        seatsJson: const [
          {
            'id': 'seat_01',
            'table_session_id': 'ses_01',
            'seat_index': 0,
            'initial_wind': 'east',
            'event_guest_id': 'gst_east',
          },
          {
            'id': 'seat_02',
            'table_session_id': 'ses_01',
            'seat_index': 1,
            'initial_wind': 'south',
            'event_guest_id': 'gst_south',
          },
          {
            'id': 'seat_03',
            'table_session_id': 'ses_01',
            'seat_index': 2,
            'initial_wind': 'west',
            'event_guest_id': 'gst_west',
          },
          {
            'id': 'seat_04',
            'table_session_id': 'ses_01',
            'seat_index': 3,
            'initial_wind': 'north',
            'event_guest_id': 'gst_north',
          },
        ],
      );

      expect(startedSession.session.rulesetId, 'HK_STANDARD_V1');
      expect(
        startedSession.session.rotationPolicyType,
        RotationPolicyType.dealerCycleReturnToInitialEast,
      );
      expect(startedSession.seats, hasLength(4));
      expect(startedSession.seats.first.initialWind, SeatWind.east);
      expect(startedSession.seats.last.initialWind, SeatWind.north);
    });
  });

  group('EventTableRecord', () {
    test('parses table defaults and optional bound tag id', () {
      final table = EventTableRecord.fromJson(const {
        'id': 'tbl_01',
        'event_id': 'evt_01',
        'label': 'Table 1',
        'mode': 'points',
        'display_order': 1,
        'nfc_tag_id': 'tag_table_01',
        'default_ruleset_id': 'HK_STANDARD_V1',
        'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'default_rotation_policy_config_json': {},
        'status': 'active',
      });

      expect(table.mode, EventTableMode.points);
      expect(table.defaultRulesetId, 'HK_STANDARD_V1');
      expect(
        table.defaultRotationPolicyType,
        RotationPolicyType.dealerCycleReturnToInitialEast,
      );
      expect(table.nfcTagId, 'tag_table_01');
    });
  });

  group('seatWindForIndex', () {
    test('maps seat order to east south west north', () {
      expect(seatWindForIndex(0), SeatWind.east);
      expect(seatWindForIndex(1), SeatWind.south);
      expect(seatWindForIndex(2), SeatWind.west);
      expect(seatWindForIndex(3), SeatWind.north);
    });
  });

  group('HandResultRecord', () {
    test('parses derived scoring fields from JSON', () {
      final hand = HandResultRecord.fromJson(const {
        'id': 'hand_01',
        'table_session_id': 'ses_01',
        'hand_number': 3,
        'result_type': 'win',
        'winner_seat_index': 2,
        'win_type': 'discard',
        'discarder_seat_index': 0,
        'fan_count': 7,
        'base_points': 32,
        'east_seat_index_before_hand': 0,
        'east_seat_index_after_hand': 1,
        'dealer_rotated': true,
        'session_completed_after_hand': false,
        'status': 'recorded',
        'entered_by_user_id': 'usr_01',
        'entered_at': '2026-04-24T20:00:00-07:00',
      });

      expect(hand.basePoints, 32);
      expect(hand.eastSeatIndexBeforeHand, 0);
      expect(hand.eastSeatIndexAfterHand, 1);
      expect(hand.dealerRotated, isTrue);
      expect(hand.sessionCompletedAfterHand, isFalse);
    });
  });

  group('HandSettlementRecord', () {
    test('parses a payer-to-winner points transfer', () {
      final settlement = HandSettlementRecord.fromJson(const {
        'id': 'hst_01',
        'hand_result_id': 'hand_01',
        'payer_event_guest_id': 'gst_east',
        'payee_event_guest_id': 'gst_west',
        'amount_points': 16,
        'multiplier_flags_json': ['discard', 'east_loses'],
      });

      expect(settlement.amountPoints, 16);
      expect(settlement.multiplierFlags, ['discard', 'east_loses']);
    });
  });

  group('LeaderboardEntry', () {
    test('parses a leaderboard row from the server response', () {
      final entry = LeaderboardEntry.fromJson(const {
        'event_guest_id': 'gst_01',
        'display_name': 'Alice Wong',
        'total_points': 48,
        'hands_won': 3,
        'self_draw_wins': 1,
        'discard_wins': 2,
        'rank': 1,
      });

      expect(entry.displayName, 'Alice Wong');
      expect(entry.totalPoints, 48);
      expect(entry.handsWon, 3);
      expect(entry.selfDrawWins, 1);
      expect(entry.rank, 1);
    });
  });

  group('PrizePlanRecord', () {
    test('parses a fixed prize plan row', () {
      final record = PrizePlanRecord.fromJson(const {
        'id': 'pp_01',
        'event_id': 'evt_01',
        'mode': 'fixed',
        'status': 'draft',
        'reserve_fixed_cents': 0,
        'reserve_percentage_bps': 0,
      });

      expect(record.mode, PrizePlanMode.fixed);
      expect(record.status, PrizePlanStatus.draft);
    });
  });

  group('PrizeTierRecord', () {
    test('parses a fixed prize tier row', () {
      final tier = PrizeTierRecord.fromJson(const {
        'id': 'tier_01',
        'prize_plan_id': 'pp_01',
        'place': 1,
        'label': '1st Place',
        'fixed_amount_cents': 15000,
        'percentage_bps': null,
      });

      expect(tier.place, 1);
      expect(tier.label, '1st Place');
      expect(tier.fixedAmountCents, 15000);
      expect(tier.percentageBps, isNull);
    });
  });

  group('PrizeTierDraftInput', () {
    test('omits unused prize amount fields from fixed tier JSON', () {
      final tier = PrizeTierDraftInput(
        place: 1,
        label: '1st',
        fixedAmountCents: 15000,
      ).toJson();

      expect(tier['fixed_amount_cents'], 15000);
      expect(tier.containsKey('percentage_bps'), isFalse);
    });
  });

  group('PrizeAwardRecord', () {
    test('parses a locked prize result row without payment status', () {
      final award = PrizeAwardRecord.fromJson(const {
        'id': 'award_01',
        'event_id': 'evt_01',
        'event_guest_id': 'gst_01',
        'display_name': 'Alice Wong',
        'rank_start': 1,
        'rank_end': 1,
        'display_rank': '1',
        'award_amount_cents': 15000,
      });

      expect(award.rankStart, 1);
      expect(award.displayRank, '1');
      expect(award.displayName, 'Alice Wong');
      expect(award.awardAmountCents, 15000);
      expect(award.toJson()['display_name'], 'Alice Wong');
      expect(award.toJson().containsKey('status'), isFalse);
      expect(award.toJson().containsKey('paid_method'), isFalse);
    });
  });

  group('PrizeAwardPreviewRow', () {
    test('parses a derived preview award row with shared rank data', () {
      final preview = PrizeAwardPreviewRow.fromJson(const {
        'event_guest_id': 'gst_02',
        'display_name': 'Bob Lee',
        'rank_start': 2,
        'rank_end': 3,
        'display_rank': 'T-2',
        'award_amount_cents': 7500,
      });

      expect(preview.displayName, 'Bob Lee');
      expect(preview.rankStart, 2);
      expect(preview.rankEnd, 3);
      expect(preview.displayRank, 'T-2');
      expect(preview.awardAmountCents, 7500);
    });
  });
}
