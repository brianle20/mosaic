import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';

void main() {
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
        'prize_budget_cents': 50000,
        'default_ruleset_id': 'HK_STANDARD_V1',
        'prevailing_wind': 'east',
      });

      expect(record.lifecycleStatus, EventLifecycleStatus.draft);
      expect(record.toJson()['lifecycle_status'], 'draft');
    });
  });

  group('EventGuestRecord', () {
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
  });

  group('PrizePlanRecord', () {
    test('computes distributable budget with reserve clamp', () {
      final record = PrizePlanRecord.fromJson(const {
        'id': 'pp_01',
        'event_id': 'evt_01',
        'mode': 'fixed',
        'status': 'draft',
        'reserve_fixed_cents': 7000,
        'reserve_percentage_bps': 2500,
      }, prizeBudgetCents: 20000);

      expect(record.distributableBudgetCents, 8000);
    });
  });
}
