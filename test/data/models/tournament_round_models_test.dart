import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';

void main() {
  group('TournamentRoundSummary', () {
    test('parses current round summary from RPC JSON', () {
      final summary = TournamentRoundSummary.fromJson({
        'round': {
          'id': 'rnd_01',
          'event_id': 'evt_01',
          'round_number': 2,
          'scoring_phase': 'tournament',
          'status': 'active',
          'assignment_round': 4,
          'started_at': '2026-05-24T19:00:00-07:00',
          'completed_at': '2026-05-24T20:00:00-07:00',
        },
        'assigned_table_count': 5,
        'complete_table_count': 1,
        'active_table_count': 1,
        'paused_table_count': 1,
        'not_started_table_count': 2,
        'current_round_tables': [
          {
            'event_table_id': 'tbl_active',
            'table_label': 'Table 1',
            'table_display_order': 1,
            'status': 'active',
            'assigned_players': [
              {
                'event_guest_id': 'gst_01',
                'display_name': 'Alice Wong',
                'seat_index': 0,
              },
            ],
            'active_session_id': 'ses_active',
            'latest_ended_session_id': null,
          },
          {
            'event_table_id': 'tbl_paused',
            'table_label': 'Table 2',
            'table_display_order': 2,
            'status': 'paused',
            'assigned_players': const [],
            'active_session_id': 'ses_paused',
            'latest_ended_session_id': null,
          },
          {
            'event_table_id': 'tbl_complete',
            'table_label': 'Table 3',
            'table_display_order': 3,
            'status': 'complete',
            'assigned_players': const [],
            'active_session_id': null,
            'latest_ended_session_id': 'ses_complete',
          },
          {
            'event_table_id': 'tbl_not_started',
            'table_label': 'Table 4',
            'table_display_order': 4,
            'status': 'not_started',
            'assigned_players': const [],
            'active_session_id': null,
            'latest_ended_session_id': null,
          },
        ],
        'other_tables': [
          {
            'event_table_id': 'tbl_other',
            'table_label': 'Table 5',
            'table_display_order': 5,
            'status': 'other',
            'assigned_players': const [],
            'active_session_id': null,
            'latest_ended_session_id': null,
          },
        ],
      });

      expect(summary.hasCurrentRound, isTrue);
      expect(summary.isComplete, isFalse);
      expect(summary.round, isNotNull);
      expect(summary.round!.id, 'rnd_01');
      expect(summary.round!.eventId, 'evt_01');
      expect(summary.round!.roundNumber, 2);
      expect(summary.round!.scoringPhase, EventScoringPhase.tournament);
      expect(summary.round!.status, TournamentRoundStatus.active);
      expect(summary.round!.assignmentRound, 4);
      expect(
        summary.round!.startedAt,
        DateTime.parse('2026-05-24T19:00:00-07:00'),
      );
      expect(
        summary.round!.completedAt,
        DateTime.parse('2026-05-24T20:00:00-07:00'),
      );

      expect(summary.assignedTableCount, 5);
      expect(summary.completeTableCount, 1);
      expect(summary.activeTableCount, 1);
      expect(summary.pausedTableCount, 1);
      expect(summary.notStartedTableCount, 2);

      expect(summary.currentRoundTables, hasLength(4));
      expect(
        summary.currentRoundTables.map((table) => table.status),
        [
          TournamentRoundTableStatus.active,
          TournamentRoundTableStatus.paused,
          TournamentRoundTableStatus.complete,
          TournamentRoundTableStatus.notStarted,
        ],
      );
      expect(summary.currentRoundTables.first.eventTableId, 'tbl_active');
      expect(summary.currentRoundTables.first.tableLabel, 'Table 1');
      expect(summary.currentRoundTables.first.tableDisplayOrder, 1);
      expect(summary.currentRoundTables.first.activeSessionId, 'ses_active');
      expect(summary.currentRoundTables.first.latestEndedSessionId, isNull);
      expect(
          summary.currentRoundTables.first.assignedPlayers.single.eventGuestId,
          'gst_01');
      expect(
          summary.currentRoundTables.first.assignedPlayers.single.displayName,
          'Alice Wong');
      expect(
          summary.currentRoundTables.first.assignedPlayers.single.seatIndex, 0);

      expect(summary.otherTables, hasLength(1));
      expect(
          summary.otherTables.single.status, TournamentRoundTableStatus.other);
      expect(summary.otherTables.single.eventTableId, 'tbl_other');
    });

    test('round-trips empty summary without losing table data', () {
      final empty = TournamentRoundSummary.fromJson({
        'round': null,
        'assigned_table_count': 0,
        'complete_table_count': 0,
        'active_table_count': 0,
        'paused_table_count': 0,
        'not_started_table_count': 0,
        'current_round_tables': const [],
        'other_tables': [
          {
            'event_table_id': 'tbl_waiting',
            'table_label': 'Waiting Table',
            'table_display_order': 9,
            'status': 'other',
            'assigned_players': const [],
            'active_session_id': null,
            'latest_ended_session_id': null,
          },
        ],
      });

      final roundTripped = TournamentRoundSummary.fromJson(empty.toJson());

      expect(roundTripped.hasCurrentRound, isFalse);
      expect(roundTripped.isComplete, isFalse);
      expect(roundTripped.otherTables.single.tableLabel, 'Waiting Table');
    });
  });
}
