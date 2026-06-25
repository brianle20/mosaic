import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
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
        'default_ruleset_id': 'HK_STANDARD',
        'prevailing_wind': 'east',
      });

      expect(record.lifecycleStatus, EventLifecycleStatus.draft);
      expect(record.toJson()['lifecycle_status'], 'draft');
    });

    test('round-trips seating mode from JSON', () {
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
        'default_ruleset_id': 'HK_STANDARD',
        'prevailing_wind': 'east',
        'seating_mode': 'manual',
      });

      expect(record.seatingMode, EventSeatingMode.manual);
      expect(record.toJson()['seating_mode'], 'manual');
    });

    test('defaults missing cached seating mode to random', () {
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
        'default_ruleset_id': 'HK_STANDARD',
        'prevailing_wind': 'east',
      });

      expect(record.seatingMode, EventSeatingMode.random);
      expect(record.toJson()['seating_mode'], 'random');
    });

    test('round-trips archived timestamp from JSON', () {
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
        'default_ruleset_id': 'HK_STANDARD',
        'prevailing_wind': 'east',
        'archived_at': '2026-05-30T19:00:00Z',
      });

      expect(record.archivedAt, DateTime.parse('2026-05-30T19:00:00Z'));
      expect(record.isArchived, isTrue);
      expect(record.toJson()['archived_at'], '2026-05-30T19:00:00.000Z');
    });
  });

  group('SeatingAssignmentRecord', () {
    test('parses RPC rows and serializes for cache', () {
      final record = SeatingAssignmentRecord.fromJson(const {
        'id': 'asg_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_01',
        'table_label': 'Table 1',
        'event_guest_id': 'gst_01',
        'guest_display_name': 'Alice Wong',
        'seat_index': 2,
        'assignment_round': 1,
        'status': 'active',
        'tournament_round_id': 'rnd_01',
      });

      expect(record.id, 'asg_01');
      expect(record.tableLabel, 'Table 1');
      expect(record.displayName, 'Alice Wong');
      expect(record.seatIndex, 2);
      expect(record.assignmentRound, 1);
      expect(record.status, 'active');
      expect(record.tournamentRoundId, 'rnd_01');
      expect(record.toJson(), {
        'id': 'asg_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_01',
        'table_label': 'Table 1',
        'event_guest_id': 'gst_01',
        'display_name': 'Alice Wong',
        'seat_index': 2,
        'assignment_round': 1,
        'status': 'active',
        'assignment_type': 'random',
        'tournament_round_id': 'rnd_01',
        'bonus_round_id': null,
        'bonus_table_role': null,
        'seed_rank': null,
      });
    });

    test('round-trips sudden death table role from JSON', () {
      final record = SeatingAssignmentRecord.fromJson(const {
        'id': 'asg_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_sudden_death',
        'table_label': 'Sudden Death',
        'event_guest_id': 'gst_01',
        'guest_display_name': 'Alice Wong',
        'seat_index': 0,
        'assignment_round': 4,
        'status': 'active',
        'assignment_type': 'bonus',
        'bonus_round_id': 'bonus_01',
        'bonus_table_role': 'table_of_champions_sudden_death',
        'seed_rank': 1,
      });

      expect(
        record.bonusTableRole,
        BonusTableRole.tableOfChampionsSuddenDeath,
      );
      expect(
        record.toJson()['bonus_table_role'],
        'table_of_champions_sudden_death',
      );
    });

    test('round-trips table of champions play-in role from JSON', () {
      final record = SeatingAssignmentRecord.fromJson(const {
        'id': 'asg_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_play_in',
        'table_label': 'Play-In',
        'event_guest_id': 'gst_01',
        'guest_display_name': 'Alice Wong',
        'seat_index': 0,
        'assignment_round': 4,
        'status': 'active',
        'assignment_type': 'bonus',
        'bonus_round_id': 'bonus_01',
        'bonus_table_role': 'table_of_champions_play_in',
        'seed_rank': 1,
      });

      expect(
        record.bonusTableRole,
        BonusTableRole.tableOfChampionsPlayIn,
      );
      expect(
        record.toJson()['bonus_table_role'],
        'table_of_champions_play_in',
      );
    });
  });

  group('BonusRoundState', () {
    test('parses sudden death RPC state with tied players', () {
      final state = BonusRoundState.fromJson(const {
        'bonus_round_id': 'bonus_01',
        'event_id': 'evt_01',
        'status': 'active',
        'champions_table_id': 'tbl_champions',
        'redemption_table_id': 'tbl_redemption',
        'sudden_death_status': 'required',
        'champion_resolution_method': 'sudden_death',
        'sudden_death_table_id': 'tbl_sudden_death',
        'sudden_death_session_id': 'ses_sudden_death',
        'tied_top_players': [
          {
            'event_guest_id': 'gst_01',
            'display_name': 'Alice Wong',
            'bonus_score_points': 120,
            'seed_rank': 1,
          },
          {
            'event_guest_id': 'gst_02',
            'display_name': 'Bob Lee',
            'bonus_score_points': 120.0,
            'seed_rank': 2.0,
          },
        ],
        'champion_event_guest_id': 'gst_01',
        'champion_bonus_score_points': 180,
        'champion_award_points': 200,
        'champion_top_up_points': 20,
      });

      expect(state.bonusRoundId, 'bonus_01');
      expect(state.eventId, 'evt_01');
      expect(state.status, 'active');
      expect(state.championsTableId, 'tbl_champions');
      expect(state.redemptionTableId, 'tbl_redemption');
      expect(state.suddenDeathStatus, 'required');
      expect(state.championResolutionMethod, 'sudden_death');
      expect(state.suddenDeathTableId, 'tbl_sudden_death');
      expect(state.suddenDeathSessionId, 'ses_sudden_death');
      expect(state.tiedTopPlayers, hasLength(2));
      expect(state.tiedTopPlayers.first.displayName, 'Alice Wong');
      expect(state.tiedTopPlayers.last.bonusScorePoints, 120);
      expect(state.tiedTopPlayers.last.seedRank, 2);
      expect(state.championEventGuestId, 'gst_01');
      expect(state.championBonusScorePoints, 180);
      expect(state.championAwardPoints, 200);
      expect(state.championTopUpPoints, 20);
      expect(state.toJson()['tied_top_players'], [
        {
          'event_guest_id': 'gst_01',
          'display_name': 'Alice Wong',
          'bonus_score_points': 120,
          'seed_rank': 1,
        },
        {
          'event_guest_id': 'gst_02',
          'display_name': 'Bob Lee',
          'bonus_score_points': 120,
          'seed_rank': 2,
        },
      ]);
    });

    test('tolerates missing nullable fields from RPC state', () {
      final state = BonusRoundState.fromJson(const {
        'bonus_round_id': 'bonus_01',
        'event_id': 'evt_01',
        'status': 'active',
      });

      expect(state.bonusRoundId, 'bonus_01');
      expect(state.tiedTopPlayers, isEmpty);
      expect(state.suddenDeathStatus, isNull);
      expect(state.championAwardPoints, isNull);
    });

    test('parses play-in RPC state with play-in players', () {
      final state = BonusRoundState.fromJson(const {
        'bonus_round_id': 'bonus_01',
        'event_id': 'evt_01',
        'status': 'active',
        'champions_table_id': 'tbl_champions',
        'play_in_status': 'required',
        'play_in_table_id': 'tbl_play_in',
        'play_in_session_id': 'ses_play_in',
        'play_in_winner_event_guest_id': 'gst_02',
        'play_in_winner_seed_rank': 2,
        'play_in_players': [
          {
            'event_guest_id': 'gst_01',
            'display_name': 'Alice Wong',
            'bonus_score_points': 120,
            'seed_rank': 1,
          },
          {
            'event_guest_id': 'gst_02',
            'display_name': 'Bob Lee',
            'total_points': 118.0,
            'seed_rank': 2.0,
          },
        ],
      });

      expect(state.playInStatus, 'required');
      expect(state.playInTableId, 'tbl_play_in');
      expect(state.playInSessionId, 'ses_play_in');
      expect(state.playInWinnerEventGuestId, 'gst_02');
      expect(state.playInWinnerSeedRank, 2);
      expect(state.playInPlayers, hasLength(2));
      expect(state.playInPlayers.first.bonusScorePoints, 120);
      expect(state.playInPlayers.last.totalPoints, 118);
      expect(state.playInPlayers.last.seedRank, 2);
      expect(state.toJson()['play_in_players'], [
        {
          'event_guest_id': 'gst_01',
          'display_name': 'Alice Wong',
          'bonus_score_points': 120,
          'total_points': null,
          'seed_rank': 1,
        },
        {
          'event_guest_id': 'gst_02',
          'display_name': 'Bob Lee',
          'bonus_score_points': null,
          'total_points': 118,
          'seed_rank': 2,
        },
      ]);
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
    test('parses false win penalty records from JSON', () {
      final penalty = FalseWinPenaltyRecord.fromJson(const {
        'id': 'penalty-1',
        'table_session_id': 'session-1',
        'hand_result_id': 'hand-1',
        'penalty_seat_index': 2,
        'fan_count': 6,
        'entered_by_user_id': 'host-1',
        'entered_at': '2026-06-24T12:00:00Z',
        'status': 'attached',
        'correction_note': 'called too early',
      });

      expect(penalty.id, 'penalty-1');
      expect(penalty.tableSessionId, 'session-1');
      expect(penalty.handResultId, 'hand-1');
      expect(penalty.penaltySeatIndex, 2);
      expect(penalty.fanCount, 6);
      expect(penalty.status, FalseWinPenaltyStatus.attached);
      expect(penalty.correctionNote, 'called too early');
      expect(penalty.toJson()['status'], 'attached');
    });

    test('serializes false win penalty input for current RPC signature', () {
      const input = RecordFalseWinPenaltyInput(
        tableSessionId: 'session-1',
        penaltySeatIndex: 2,
        correctionNote: 'called too early',
        clientMutationId: 'mutation-1',
        expectedRecordedHandCount: 4,
        expectedLastRecordedHandId: 'hand-4',
      );

      expect(input.toRpcParams(), {
        'target_table_session_id': 'session-1',
        'target_penalty_seat_index': 2,
        'target_correction_note': 'called too early',
        'target_client_mutation_id': 'mutation-1',
        'target_expected_recorded_hand_count': 4,
        'target_expected_last_recorded_hand_id': 'hand-4',
      });
    });

    test('stores ruleset and rotation policy explicitly', () {
      final record = TableSessionRecord.fromJson(const {
        'id': 'ses_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_01',
        'session_number_for_table': 1,
        'ruleset_id': 'HK_STANDARD',
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

      expect(record.rulesetId, 'HK_STANDARD');
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
          'ruleset_id': 'HK_STANDARD',
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

      expect(startedSession.session.rulesetId, 'HK_STANDARD');
      expect(
        startedSession.session.rotationPolicyType,
        RotationPolicyType.dealerCycleReturnToInitialEast,
      );
      expect(startedSession.seats, hasLength(4));
      expect(startedSession.seats.first.initialWind, SeatWind.east);
      expect(startedSession.seats.last.initialWind, SeatWind.north);
    });

    test('session detail preserves table label context', () {
      final detail = SessionDetailRecord.fromJson(const {
        'table_label': 'Table 1',
        'session': {
          'id': 'ses_01',
          'event_id': 'evt_01',
          'event_table_id': 'tbl_01',
          'session_number_for_table': 1,
          'ruleset_id': 'HK_STANDARD',
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
        'seats': [],
        'hands': [],
        'settlements': [],
      });

      expect(detail.tableLabel, 'Table 1');
      expect(detail.toJson()['table_label'], 'Table 1');
    });

    test('session detail allows missing table label context', () {
      final detail = SessionDetailRecord.fromJson(const {
        'session': {
          'id': 'ses_01',
          'event_id': 'evt_01',
          'event_table_id': 'tbl_01',
          'session_number_for_table': 1,
          'ruleset_id': 'HK_STANDARD',
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
        'seats': [],
        'hands': [],
        'settlements': [],
      });

      expect(detail.tableLabel, isNull);
    });

    test('session detail parses pending and attached false win penalties', () {
      final detail = SessionDetailRecord.fromJson({
        'table_label': 'Table 1',
        'session': _sessionJson(),
        'seats': _seatRows(),
        'hands': [_handJson()],
        'settlements': const [],
        'false_win_penalties': const [
          {
            'id': 'penalty-1',
            'table_session_id': 'session-1',
            'hand_result_id': null,
            'penalty_seat_index': 1,
            'fan_count': 6,
            'entered_by_user_id': 'host-1',
            'entered_at': '2026-06-24T12:00:00Z',
            'status': 'pending',
            'correction_note': null,
          },
          {
            'id': 'penalty-2',
            'table_session_id': 'session-1',
            'hand_result_id': 'hand-1',
            'penalty_seat_index': 2,
            'fan_count': 6,
            'entered_by_user_id': 'host-1',
            'entered_at': '2026-06-24T12:01:00Z',
            'status': 'attached',
            'correction_note': null,
          },
        ],
      });

      expect(detail.pendingFalseWinPenaltySeatIndexes, [1]);
      expect(
        detail.falseWinPenaltiesForHand('hand-1').single.penaltySeatIndex,
        2,
      );
    });
  });

  group('EventTableRecord', () {
    test('parses table defaults without host-facing mode or status', () {
      final table = EventTableRecord.fromJson(const {
        'id': 'tbl_01',
        'event_id': 'evt_01',
        'label': 'Table 1',
        'display_order': 1,
        'nfc_tag_id': 'tag_table_01',
        'default_ruleset_id': 'HK_STANDARD',
        'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'default_rotation_policy_config_json': {},
      });

      expect(table.defaultRulesetId, 'HK_STANDARD');
      expect(
        table.defaultRotationPolicyType,
        RotationPolicyType.dealerCycleReturnToInitialEast,
      );
      expect(table.nfcTagId, 'tag_table_01');
      expect(table.toJson().containsKey('mode'), isFalse);
      expect(table.toJson().containsKey('status'), isFalse);
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

  group('TableSessionRecord', () {
    test('parses round timer pause accounting', () {
      final session = TableSessionRecord.fromJson(const {
        'id': 'ses_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_01',
        'session_number_for_table': 1,
        'ruleset_id': 'HK_STANDARD',
        'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'rotation_policy_config_json': {},
        'status': 'paused',
        'scoring_phase': 'tournament',
        'initial_east_seat_index': 0,
        'current_dealer_seat_index': 1,
        'dealer_pass_count': 0,
        'completed_games_count': 0,
        'hand_count': 2,
        'started_at': '2026-05-24T19:00:00Z',
        'started_by_user_id': 'usr_01',
        'round_timer_paused_at': '2026-05-24T19:37:15Z',
        'round_timer_paused_seconds': 180,
      });

      expect(
        session.roundTimerPausedAt,
        DateTime.parse('2026-05-24T19:37:15Z'),
      );
      expect(session.roundTimerPausedSeconds, 180);
      expect(
        session.toJson()['round_timer_paused_at'],
        '2026-05-24T19:37:15.000Z',
      );
      expect(session.toJson()['round_timer_paused_seconds'], 180);
    });

    test('round-trips bonus table role for sudden death sessions', () {
      final session = TableSessionRecord.fromJson(const {
        'id': 'ses_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_01',
        'session_number_for_table': 1,
        'ruleset_id': 'HK_STANDARD',
        'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'rotation_policy_config_json': {},
        'status': 'active',
        'scoring_phase': 'bonus',
        'bonus_table_role': 'table_of_champions_sudden_death',
        'initial_east_seat_index': 0,
        'current_dealer_seat_index': 1,
        'dealer_pass_count': 0,
        'completed_games_count': 0,
        'hand_count': 2,
        'started_at': '2026-05-24T19:00:00Z',
        'started_by_user_id': 'usr_01',
      });

      expect(
        session.bonusTableRole,
        BonusTableRole.tableOfChampionsSuddenDeath,
      );
      expect(
        session.toJson()['bonus_table_role'],
        'table_of_champions_sudden_death',
      );
    });

    test('round-trips bonus table role for play-in sessions', () {
      final session = TableSessionRecord.fromJson(const {
        'id': 'ses_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_01',
        'session_number_for_table': 1,
        'ruleset_id': 'HK_STANDARD',
        'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'rotation_policy_config_json': {},
        'status': 'active',
        'scoring_phase': 'bonus',
        'bonus_table_role': 'table_of_champions_play_in',
        'initial_east_seat_index': 0,
        'current_dealer_seat_index': 1,
        'dealer_pass_count': 0,
        'completed_games_count': 0,
        'hand_count': 2,
        'started_at': '2026-05-24T19:00:00Z',
        'started_by_user_id': 'usr_01',
      });

      expect(session.bonusTableRole, BonusTableRole.tableOfChampionsPlayIn);
      expect(
        session.toJson()['bonus_table_role'],
        'table_of_champions_play_in',
      );
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

    test('parses false win penalty fields from JSON', () {
      final hand = HandResultRecord.fromJson(const {
        'id': 'hand_02',
        'table_session_id': 'ses_01',
        'hand_number': 4,
        'result_type': 'false_win_penalty',
        'winner_seat_index': null,
        'win_type': null,
        'discarder_seat_index': null,
        'penalty_seat_index': 1,
        'fan_count': 6,
        'base_points': 32,
        'east_seat_index_before_hand': 0,
        'east_seat_index_after_hand': 0,
        'dealer_rotated': false,
        'session_completed_after_hand': false,
        'status': 'recorded',
        'entered_by_user_id': 'usr_01',
        'entered_at': '2026-04-24T20:00:00-07:00',
      });

      expect(hand.resultType, HandResultType.falseWinPenalty);
      expect(hand.penaltySeatIndex, 1);
      expect(hand.fanCount, 6);
      expect(hand.toJson()['result_type'], 'false_win_penalty');
      expect(hand.toJson()['penalty_seat_index'], 1);
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

    test('parses pending false win settlement without a hand result', () {
      final settlement = HandSettlementRecord.fromJson(const {
        'id': 'hst_false_win_01',
        'hand_result_id': null,
        'hand_false_win_penalty_id': 'penalty-1',
        'payer_event_guest_id': 'gst_false_caller',
        'payee_event_guest_id': 'gst_east',
        'amount_points': 32,
        'multiplier_flags_json': ['false_win_penalty'],
      });

      expect(settlement.handResultId, isNull);
      expect(settlement.handFalseWinPenaltyId, 'penalty-1');
      expect(settlement.toJson()['hand_result_id'], isNull);
      expect(settlement.toJson()['hand_false_win_penalty_id'], 'penalty-1');
    });
  });

  group('LeaderboardEntry', () {
    test('parses a leaderboard row from the server response', () {
      final entry = LeaderboardEntry.fromJson(const {
        'event_guest_id': 'gst_01',
        'display_name': 'Alice Wong',
        'total_points': 48,
        'hands_played': 7,
        'hands_won': 3,
        'self_draw_wins': 1,
        'discard_wins': 2,
        'discard_losses': 4,
        'rank': 1,
      });

      expect(entry.displayName, 'Alice Wong');
      expect(entry.totalPoints, 48);
      expect(entry.handsPlayed, 7);
      expect(entry.handsWon, 3);
      expect(entry.selfDrawWins, 1);
      expect(entry.discardWins, 2);
      expect(entry.discardLosses, 4);
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

Map<String, dynamic> _sessionJson() {
  return {
    'id': 'session-1',
    'event_id': 'event-1',
    'event_table_id': 'table-1',
    'session_number_for_table': 1,
    'ruleset_id': 'HK_STANDARD',
    'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
    'rotation_policy_config_json': <String, dynamic>{},
    'status': 'active',
    'initial_east_seat_index': 0,
    'current_dealer_seat_index': 0,
    'dealer_pass_count': 0,
    'completed_games_count': 1,
    'hand_count': 1,
    'started_at': '2026-06-24T11:00:00Z',
    'started_by_user_id': 'host-1',
  };
}

List<Map<String, dynamic>> _seatRows() {
  return [
    {
      'id': 'seat-1',
      'table_session_id': 'session-1',
      'seat_index': 0,
      'initial_wind': 'east',
      'event_guest_id': 'guest-1',
    },
    {
      'id': 'seat-2',
      'table_session_id': 'session-1',
      'seat_index': 1,
      'initial_wind': 'south',
      'event_guest_id': 'guest-2',
    },
    {
      'id': 'seat-3',
      'table_session_id': 'session-1',
      'seat_index': 2,
      'initial_wind': 'west',
      'event_guest_id': 'guest-3',
    },
  ];
}

Map<String, dynamic> _handJson() {
  return {
    'id': 'hand-1',
    'table_session_id': 'session-1',
    'hand_number': 1,
    'result_type': 'win',
    'winner_seat_index': 0,
    'win_type': 'self_draw',
    'discarder_seat_index': null,
    'fan_count': 3,
    'base_points': 8,
    'east_seat_index_before_hand': 0,
    'east_seat_index_after_hand': 0,
    'dealer_rotated': false,
    'session_completed_after_hand': false,
    'status': 'recorded',
    'entered_by_user_id': 'host-1',
    'entered_at': '2026-06-24T11:10:00Z',
  };
}
