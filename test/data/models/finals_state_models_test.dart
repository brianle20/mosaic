import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/finals_state_models.dart';

void main() {
  group('FinalsSetupPreview', () {
    test('parses every format and preview protocol field', () {
      const formats = {
        'champions_only': FinalsFormat.championsOnly,
        'automatic_redemption': FinalsFormat.automaticRedemption,
        'redemption_advancement': FinalsFormat.redemptionAdvancement,
        'parallel_finals': FinalsFormat.parallelFinals,
      };

      for (final entry in formats.entries) {
        final preview = FinalsSetupPreview.fromJson({
          'eligible_player_count': 8,
          'preview_token': 'preview-token-01',
          'format': entry.key,
          'direct_slots': 4,
          'redemption_players': [
            {
              'event_guest_id': 'guest_05',
              'display_name': 'Ava',
              'seed_rank': 5,
              'total_points': 120,
            },
          ],
          'cutoff_tie_players': const [],
          'requires_champions_table': true,
          'requires_redemption_table': true,
          'available_table_ids': const ['table_02', 'table_01'],
          'order_copy': const ['Champions and Redemption start together.'],
        });

        expect(preview.format, entry.value);
        expect(preview.eligiblePlayerCount, 8);
        expect(preview.previewToken, 'preview-token-01');
        expect(preview.directSlots, 4);
        expect(preview.redemptionPlayers.single.displayName, 'Ava');
        expect(preview.redemptionPlayers.single.totalPoints, 120);
        expect(preview.cutoffTiePlayers, isEmpty);
        expect(preview.requiresChampionsTable, isTrue);
        expect(preview.requiresRedemptionTable, isTrue);
        expect(preview.availableTableIds, const ['table_02', 'table_01']);
        expect(
          () => preview.availableTableIds.add('table_03'),
          throwsUnsupportedError,
        );
        expect(preview.orderCopy, hasLength(1));
      }
    });

    test('accepts a missing format when the eligible count is unsupported', () {
      final preview = FinalsSetupPreview.fromJson(const {
        'eligible_player_count': 1,
        'preview_token': 'preview-token-unsupported',
        'format': null,
        'direct_slots': 0,
        'redemption_players': [],
        'cutoff_tie_players': [],
        'requires_champions_table': false,
        'requires_redemption_table': false,
        'available_table_ids': [],
        'order_copy': [],
      });

      expect(preview.format, isNull);
    });

    test('rejects malformed preview arrays', () {
      expect(
        () => FinalsSetupPreview.fromJson(const {
          'eligible_player_count': 8,
          'preview_token': 'preview-token-malformed',
          'format': 'parallel_finals',
          'direct_slots': 4,
          'redemption_players': 'guest_05',
          'cutoff_tie_players': [],
          'requires_champions_table': true,
          'requires_redemption_table': true,
          'available_table_ids': [],
          'order_copy': [],
        }),
        throwsFormatException,
      );
      expect(
        () => FinalsSetupPreview.fromJson(const {
          'eligible_player_count': 8,
          'preview_token': 'preview-token-malformed-tables',
          'format': 'parallel_finals',
          'direct_slots': 4,
          'redemption_players': [],
          'cutoff_tie_players': [],
          'requires_champions_table': true,
          'requires_redemption_table': true,
          'available_table_ids': ['table_01', 7],
          'order_copy': [],
        }),
        throwsFormatException,
      );
    });
  });

  group('FinalsState', () {
    test('parses the complete server protocol and every enum value', () {
      const contestTypes = {
        'direct_qualification_tiebreak':
            FinalsContestType.directQualificationTiebreak,
        'table_of_redemption': FinalsContestType.tableOfRedemption,
        'redemption_advancement_tiebreak':
            FinalsContestType.redemptionAdvancementTiebreak,
        'redemption_winner_tiebreak':
            FinalsContestType.redemptionWinnerTiebreak,
        'table_of_champions': FinalsContestType.tableOfChampions,
        'champions_sudden_death': FinalsContestType.championsSuddenDeath,
      };
      const contestStatuses = {
        'pending': FinalsContestStatus.pending,
        'ready': FinalsContestStatus.ready,
        'active': FinalsContestStatus.active,
        'complete': FinalsContestStatus.complete,
        'cancelled': FinalsContestStatus.cancelled,
      };
      const outcomes = {
        'pending': FinalsParticipantOutcome.pending,
        'advanced': FinalsParticipantOutcome.advanced,
        'winner': FinalsParticipantOutcome.winner,
        'runner_up': FinalsParticipantOutcome.runnerUp,
        'eliminated': FinalsParticipantOutcome.eliminated,
      };

      final contests = <Map<String, dynamic>>[];
      var index = 0;
      for (final type in contestTypes.entries) {
        final status = contestStatuses.entries.elementAt(
          index % contestStatuses.length,
        );
        final outcome = outcomes.entries.elementAt(index % outcomes.length);
        contests.add({
          'id': 'contest_$index',
          'contest_type': type.key,
          'title': 'Contest $index',
          'status': status.key,
          'table_label': 'Table ${index + 1}',
          'table_session_id': switch (index) {
            2 => 'session_active',
            3 => 'session_complete',
            _ => null,
          },
          'slots_to_fill': 1,
          'slot_start_index':
              type.value == FinalsContestType.tableOfChampions ? null : 1,
          'sequence_number': index + 1,
          'started_at': '2026-07-11T18:00:00Z',
          'completed_at': null,
          'participants': [
            {
              'event_guest_id': 'guest_$index',
              'display_name': 'Player $index',
              'entry_seed': index + 1,
              'seat_index': index % 4,
              'outcome': outcome.key,
              'advanced_champions_slot': 1,
              'outcome_order': 1,
            },
          ],
        });
        index++;
      }

      final state = FinalsState.fromJson({
        'flow_version': 'orchestrated',
        'state_version': 7,
        'format': 'parallel_finals',
        'overall_status': 'active',
        'eligible_player_count': 8,
        'champions_slots': const [
          {
            'slot_index': 1,
            'event_guest_id': 'guest_01',
            'display_name': 'Bo',
            'qualification_method': 'direct_seed',
            'source_contest_id': null,
            'source_finish_order': null,
          },
          {
            'slot_index': 2,
            'event_guest_id': 'guest_02',
            'display_name': 'Cy',
            'qualification_method': 'redemption_finish',
            'source_contest_id': 'contest_1',
            'source_finish_order': 1,
          },
          {
            'slot_index': 3,
            'event_guest_id': 'guest_03',
            'display_name': 'Dee',
            'qualification_method': 'tiebreak_win',
            'source_contest_id': 'contest_2',
            'source_finish_order': null,
          },
          {
            'slot_index': 4,
            'event_guest_id': null,
            'display_name': null,
            'qualification_method': null,
            'source_contest_id': null,
            'source_finish_order': null,
          },
        ],
        'contests': contests,
        'allowed_actions': const [
          {
            'action': 'start_contest',
            'label': 'Start Table of Champions',
            'contest_id': 'contest_4',
            'table_id': 'table_01',
            'available_table_ids': ['table_02', 'table_01'],
            'session_id': null,
            'expected_state_version': 7,
            'recovery_token': null,
          },
          {
            'action': 'start_finals_tables',
            'label': 'Start Finals Tables',
            'recovery_token': 'recovery_01',
          },
          {
            'action': 'resume_finals_start',
            'label': 'Resume Finals Start',
            'recovery_token': 'recovery_01',
          },
        ],
        'blocking_reason': null,
        'recovery_token': 'recovery_01',
        'champion': const {
          'event_guest_id': 'guest_01',
          'display_name': 'Bo',
        },
        'redemption_winner': const {
          'event_guest_id': 'guest_05',
          'display_name': 'Eli',
          'resolution_method': 'table_score',
        },
        'sessions': const [
          {
            'id': 'legacy_session',
            'bonus_table_role': 'table_of_redemption',
            'table_label': 'Table 2',
            'status': 'paused',
            'started_at': '2026-07-11T17:00:00Z',
          },
        ],
      });

      expect(state.flowVersion, FinalsFlowVersion.orchestrated);
      expect(state.stateVersion, 7);
      expect(state.format, FinalsFormat.parallelFinals);
      expect(state.overallStatus, FinalsOverallStatus.active);
      expect(state.eligiblePlayerCount, 8);
      expect(
        state.contests.map((contest) => contest.type),
        contestTypes.values,
      );
      expect(
        state.contests.map((contest) => contest.status),
        contestStatuses.values.followedBy(const [FinalsContestStatus.pending]),
      );
      expect(
        state.contests.map((contest) => contest.participants.single.outcome),
        outcomes.values.followedBy(const [FinalsParticipantOutcome.pending]),
      );
      expect(
        state.championsSlots.map((slot) => slot.qualificationMethod),
        const [
          FinalsQualificationMethod.directSeed,
          FinalsQualificationMethod.redemptionFinish,
          FinalsQualificationMethod.tiebreakWin,
          null,
        ],
      );
      expect(state.primaryAction?.kind, FinalsActionKind.startContest);
      expect(state.primaryAction?.expectedStateVersion, 7);
      expect(
        state.primaryAction?.availableTableIds,
        const ['table_02', 'table_01'],
      );
      expect(
        () => state.primaryAction!.availableTableIds.add('table_03'),
        throwsUnsupportedError,
      );
      expect(
        state.allowedActions.map((action) => action.kind),
        const [
          FinalsActionKind.startContest,
          FinalsActionKind.startFinalsTables,
          FinalsActionKind.resumeFinalsStart,
        ],
      );
      expect(state.recoveryToken, 'recovery_01');
      expect(state.allowedActions[1].recoveryToken, state.recoveryToken);
      expect(state.allowedActions[2].recoveryToken, state.recoveryToken);
      expect(state.champion?.displayName, 'Bo');
      expect(state.redemptionWinner?.resolutionMethod, 'table_score');
      expect(
        state.redemptionWinners.map((winner) => winner.displayName),
        const ['Eli'],
      );
      expect(state.activeSessionIds, {'session_active', 'legacy_session'});
    });

    test('derives multiple Redemption winners from contest outcomes', () {
      final state = FinalsState.fromJson({
        ..._minimalState(
          overallStatus: 'complete',
          contests: const [
            {
              'id': 'redemption',
              'contest_type': 'table_of_redemption',
              'title': 'Table of Redemption',
              'status': 'complete',
              'table_label': 'Table 2',
              'table_session_id': 'session_redemption',
              'slots_to_fill': 0,
              'slot_start_index': null,
              'sequence_number': 1,
              'started_at': '2026-07-23T18:00:00Z',
              'completed_at': '2026-07-23T19:00:00Z',
              'participants': [
                {
                  'event_guest_id': 'guest_01',
                  'display_name': 'Ava',
                  'entry_seed': 5,
                  'seat_index': 0,
                  'outcome': 'winner',
                  'advanced_champions_slot': null,
                  'outcome_order': 1,
                },
                {
                  'event_guest_id': 'guest_02',
                  'display_name': 'Ben',
                  'entry_seed': 6,
                  'seat_index': 1,
                  'outcome': 'winner',
                  'advanced_champions_slot': null,
                  'outcome_order': 1,
                },
              ],
            },
          ],
        ),
        'redemption_winner': null,
      });

      expect(state.redemptionWinner, isNull);
      expect(
        state.redemptionWinners.map((winner) => winner.displayName),
        const ['Ava', 'Ben'],
      );
      expect(
        state.redemptionWinners.map((winner) => winner.resolutionMethod),
        everyElement('table_score_tie'),
      );
    });

    test('parses every flow and overall status', () {
      const flowVersions = {
        'legacy': FinalsFlowVersion.legacy,
        'orchestrated': FinalsFlowVersion.orchestrated,
      };
      const statuses = {
        'not_started': FinalsOverallStatus.notStarted,
        'active': FinalsOverallStatus.active,
        'complete': FinalsOverallStatus.complete,
        'cancelled': FinalsOverallStatus.cancelled,
        'recoverable_missing_sessions':
            FinalsOverallStatus.recoverableMissingSessions,
        'blocked_legacy_state': FinalsOverallStatus.blockedLegacyState,
      };

      for (final flow in flowVersions.entries) {
        for (final status in statuses.entries) {
          final state = FinalsState.fromJson(_minimalState(
            flowVersion: flow.key,
            overallStatus: status.key,
          ));
          expect(state.flowVersion, flow.value);
          expect(state.overallStatus, status.value);
        }
      }
    });

    test('accepts missing optional fields for not-started state', () {
      final state = FinalsState.fromJson(const {
        'flow_version': null,
        'state_version': 0,
        'format': null,
        'overall_status': 'not_started',
        'eligible_player_count': null,
        'champions_slots': [],
        'contests': [],
        'allowed_actions': [],
      });

      expect(state.flowVersion, isNull);
      expect(state.format, isNull);
      expect(state.blockingReason, isNull);
      expect(state.recoveryToken, isNull);
      expect(state.champion, isNull);
      expect(state.redemptionWinner, isNull);
      expect(state.primaryAction, isNull);
      expect(state.activeSessionIds, isEmpty);
    });

    test('requires state versions to be integer protocol values', () {
      expect(
        () => FinalsState.fromJson(
          _minimalState(stateVersion: 4.0),
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed state arrays and array entries', () {
      expect(
        () => FinalsState.fromJson(_minimalState(contests: const {})),
        throwsFormatException,
      );
      expect(
        () => FinalsState.fromJson(_minimalState(actions: const ['start'])),
        throwsFormatException,
      );
      expect(
        () => FinalsState.fromJson(_minimalState(actions: const [
          {
            'action': 'start_contest',
            'label': 'Start Table of Champions',
            'available_table_ids': ['table_01', 7],
          },
        ])),
        throwsFormatException,
      );
    });

    test('rejects unknown protocol enum values instead of inferring', () {
      expect(
        () => FinalsState.fromJson(
          _minimalState(overallStatus: 'waiting_for_host'),
        ),
        throwsFormatException,
      );
      expect(
        () => FinalsState.fromJson(_minimalState(actions: const [
          {'action': 'retry_everything', 'label': 'Retry'},
        ])),
        throwsFormatException,
      );
    });
  });
}

Map<String, dynamic> _minimalState({
  Object? flowVersion = 'legacy',
  Object? stateVersion = 1,
  Object? overallStatus = 'active',
  Object? contests = const [],
  Object? actions = const [],
}) {
  return {
    'flow_version': flowVersion,
    'state_version': stateVersion,
    'format': 'champions_only',
    'overall_status': overallStatus,
    'eligible_player_count': 4,
    'champions_slots': const [],
    'contests': contests,
    'allowed_actions': actions,
    'blocking_reason': null,
    'champion': null,
    'redemption_winner': null,
  };
}
