import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/finals_state_models.dart';
import 'package:mosaic/data/offline/network_reachability.dart';
import 'package:mosaic/data/repositories/supabase_finals_repository.dart';
import 'package:supabase/supabase.dart';

void main() {
  group('SupabaseFinalsRepository RPC contract', () {
    test('calls preview and load RPCs with exact parameters', () async {
      final runner = _RecordingRpcRunner();
      final repository = SupabaseFinalsRepository.withRpcRunner(
        rpcRunner: runner.call,
        reachability: _FakeReachability(),
      );

      await repository.previewFinals('evt_01');
      await repository.loadFinalsState('evt_01');

      expect(runner.calls, [
        const _RpcCall('preview_event_finals', {
          'target_event_id': 'evt_01',
        }),
        const _RpcCall('get_event_finals_state', {
          'target_event_id': 'evt_01',
        }),
      ]);
    });

    test('calls begin_event_finals with exact nullable protocol parameters',
        () async {
      final runner = _RecordingRpcRunner();
      final reachability = _FakeReachability();
      final repository = SupabaseFinalsRepository.withRpcRunner(
        rpcRunner: runner.call,
        reachability: reachability,
      );

      await repository.beginFinals(const BeginFinalsInput(
        eventId: 'evt_01',
        championsTableId: 'table_champions',
        redemptionTableId: 'table_redemption',
        expectedStateVersion: 4,
        expectedPreviewToken: 'preview-token-01',
      ));

      expect(reachability.checkCount, 1);
      expect(
          runner.calls.single,
          const _RpcCall('begin_event_finals', {
            'target_event_id': 'evt_01',
            'selected_champions_table_id': 'table_champions',
            'selected_redemption_table_id': 'table_redemption',
            'expected_state_version': 4,
            'expected_preview_token': 'preview-token-01',
          }));
    });

    test('calls start_finals_contest with exact parameters', () async {
      final runner = _RecordingRpcRunner();
      final repository = SupabaseFinalsRepository.withRpcRunner(
        rpcRunner: runner.call,
        reachability: _FakeReachability(),
      );

      await repository.startContest(const StartFinalsContestInput(
        contestId: 'contest_01',
        tableId: 'table_01',
        expectedStateVersion: 9,
      ));

      expect(
          runner.calls.single,
          const _RpcCall('start_finals_contest', {
            'target_contest_id': 'contest_01',
            'selected_table_id': 'table_01',
            'expected_state_version': 9,
          }));
    });

    test('calls resume_event_finals_start with exact parameters', () async {
      final runner = _RecordingRpcRunner();
      final repository = SupabaseFinalsRepository.withRpcRunner(
        rpcRunner: runner.call,
        reachability: _FakeReachability(),
      );

      await repository.resumeFinalsStart(const ResumeFinalsStartInput(
        eventId: 'evt_01',
        recoveryToken: 'recovery_01',
      ));

      expect(
        runner.calls.single,
        const _RpcCall('resume_event_finals_start', {
          'target_event_id': 'evt_01',
          'expected_recovery_token': 'recovery_01',
        }),
      );
    });
  });

  group('SupabaseFinalsRepository network boundary', () {
    for (final mutation in <String,
        Future<void> Function(
      SupabaseFinalsRepository repository,
    )>{
      'beginFinals': (repository) async {
        await repository.beginFinals(const BeginFinalsInput(
          eventId: 'evt_01',
          championsTableId: 'table_01',
          expectedPreviewToken: 'preview-token-01',
        ));
      },
      'startContest': (repository) async {
        await repository.startContest(const StartFinalsContestInput(
          contestId: 'contest_01',
          expectedStateVersion: 1,
        ));
      },
      'resumeFinalsStart': (repository) async {
        await repository.resumeFinalsStart(const ResumeFinalsStartInput(
          eventId: 'evt_01',
          recoveryToken: 'token',
        ));
      },
    }.entries) {
      test('${mutation.key} checks reachability and never calls RPC offline',
          () async {
        final runner = _RecordingRpcRunner();
        final reachability = _FakeReachability(reachable: false);
        final repository = SupabaseFinalsRepository.withRpcRunner(
          rpcRunner: runner.call,
          reachability: reachability,
        );

        await expectLater(
          mutation.value(repository),
          throwsA(isA<NetworkUnavailableException>().having(
            (error) => error.message,
            'message',
            'Finals actions require a connection. Reconnect and try again.',
          )),
        );
        expect(reachability.checkCount, 1);
        expect(runner.calls, isEmpty);
      });
    }

    test('read RPCs do not use mutation reachability preflight', () async {
      final runner = _RecordingRpcRunner();
      final reachability = _FakeReachability(reachable: false);
      final repository = SupabaseFinalsRepository.withRpcRunner(
        rpcRunner: runner.call,
        reachability: reachability,
      );

      await repository.loadFinalsState('evt_01');

      expect(reachability.checkCount, 0);
      expect(runner.calls.single.functionName, 'get_event_finals_state');
    });

    test('maps an RPC network failure after a successful preflight', () async {
      final reachability = _FakeReachability(
        networkException: (error) => error is TimeoutException,
      );
      final repository = SupabaseFinalsRepository.withRpcRunner(
        rpcRunner: (_, __) =>
            throw TimeoutException('Finals request timed out'),
        reachability: reachability,
      );

      await expectLater(
        repository.startContest(const StartFinalsContestInput(
          contestId: 'contest_01',
          expectedStateVersion: 1,
        )),
        throwsA(isA<NetworkUnavailableException>().having(
          (error) => error.message,
          'message',
          'Finals actions require a connection. Reconnect and try again.',
        )),
      );
      expect(reachability.checkCount, 1);
    });
  });

  group('SupabaseFinalsRepository error boundary', () {
    for (final message in _approvedHostSafeMessages) {
      test('preserves approved P0001 message: $message', () async {
        final repository = SupabaseFinalsRepository.withRpcRunner(
          rpcRunner: (_, __) => throw PostgrestException(
            message: message,
            code: 'P0001',
            details: 'rpc=begin_event_finals event_id=private-id',
          ),
          reachability: _FakeReachability(),
        );

        await expectLater(
          repository.beginFinals(const BeginFinalsInput(
            eventId: 'evt_01',
            championsTableId: 'table_01',
            expectedPreviewToken: 'preview-token-01',
          )),
          throwsA(isA<FinalsCommandException>().having(
            (error) => error.message,
            'message',
            message,
          )),
        );
      });
    }

    test('hides unknown PostgREST message, details, code, and RPC name',
        () async {
      const backendError = PostgrestException(
        message: 'duplicate key exposes event_finals_contests private-id',
        code: '23505',
        details: 'rpc=start_finals_contest table=secret-table-id',
        hint: 'inspect private_constraint_name',
      );
      FinalsRpcDiagnostic? diagnostic;
      final repository = SupabaseFinalsRepository.withRpcRunner(
        rpcRunner: (_, __) => throw backendError,
        reachability: _FakeReachability(),
        diagnosticReporter: (value) => diagnostic = value,
      );

      await expectLater(
        repository.startContest(const StartFinalsContestInput(
          contestId: 'contest_01',
          expectedStateVersion: 1,
        )),
        throwsA(isA<FinalsCommandException>().having(
          (error) => error.message,
          'message',
          SupabaseFinalsRepository.genericCommandErrorMessage,
        )),
      );
      expect(diagnostic?.functionName, 'start_finals_contest');
      expect(diagnostic?.params, {
        'target_contest_id': 'contest_01',
        'selected_table_id': null,
        'expected_state_version': 1,
      });
      expect(diagnostic?.exception, same(backendError));
      expect(diagnostic?.stackTrace, isNotNull);
    });
  });
}

class _RecordingRpcRunner {
  final calls = <_RpcCall>[];

  Future<dynamic> call(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    calls.add(_RpcCall(functionName, params));
    if (functionName == 'preview_event_finals') {
      return const {
        'eligible_player_count': 4,
        'preview_token': 'preview-token-01',
        'format': 'champions_only',
        'direct_slots': 4,
        'redemption_players': [],
        'cutoff_tie_players': [],
        'requires_champions_table': true,
        'requires_redemption_table': false,
        'available_table_ids': ['table_01'],
        'order_copy': [],
      };
    }
    return _stateJson;
  }
}

class _RpcCall {
  const _RpcCall(this.functionName, this.params);

  final String functionName;
  final Map<String, dynamic> params;

  @override
  bool operator ==(Object other) =>
      other is _RpcCall &&
      other.functionName == functionName &&
      _mapsEqual(other.params, params);

  @override
  int get hashCode => Object.hash(functionName, Object.hashAll(params.entries));
}

bool _mapsEqual(Map<String, dynamic> left, Map<String, dynamic> right) {
  if (left.length != right.length) return false;
  return left.entries.every((entry) => right[entry.key] == entry.value);
}

class _FakeReachability implements NetworkReachability {
  _FakeReachability({
    this.reachable = true,
    this.networkException,
  });

  final bool reachable;
  final bool Function(Object error)? networkException;
  int checkCount = 0;

  @override
  Future<bool> isReachable() async {
    checkCount++;
    return reachable;
  }

  @override
  Stream<void> get onReachable => const Stream.empty();

  @override
  bool isNetworkException(Object error) =>
      error is NetworkUnavailableException ||
      (networkException?.call(error) ?? false);
}

const _stateJson = <String, dynamic>{
  'flow_version': null,
  'state_version': 0,
  'format': null,
  'overall_status': 'not_started',
  'eligible_player_count': null,
  'champions_slots': [],
  'contests': [],
  'allowed_actions': [],
  'blocking_reason': null,
  'champion': null,
  'redemption_winner': null,
};

const _approvedHostSafeMessages = <String>{
  'At least 2 prize-eligible players are required for Finals.',
  'End active or paused tournament sessions before beginning Finals.',
  'Event must be active and open for bonus scoring.',
  'Event must be active and open for scoring before Finals begin.',
  'Active Finals already exist for this event. Use the Finals recovery action.',
  'Completed legacy Finals already exist for this event.',
  'Finals already began with different table selections. Refresh and try again.',
  'Finals changed since this screen loaded. Refresh and try again.',
  'Finals changed since this screen was loaded. Refresh and try again.',
  'Finals could not be safely recovered. Review the table assignments.',
  'Finals seating is incomplete.',
  'Finals tables must be different.',
  'One of these Finals tables is already active.',
  'Selected Finals table is not available for this event.',
  'Selected Finals tables must not have active or paused sessions.',
  'Selected Finals tables are currently being scored. Refresh and try again.',
  'Selected Finals table is currently being scored. Refresh and try again.',
  'Finals tables are currently being scored. Refresh and try again.',
  'Table of Champions must be a ready event table.',
  'Table of Redemption is not used for this Finals format.',
  'Table of Redemption must be a ready event table.',
  'The Finals cutoff tie has more than four players and requires manual resolution.',
  'The selected Finals table already has an active session.',
  'This Finals contest is assigned to a different table. Refresh and try again.',
  'This Finals contest is no longer available to start.',
  'This Finals contest is not ready to start.',
  'A Finals player is already playing at another table.',
  'All Finals players must be checked in before starting.',
  'A second ready table is required for Table of Redemption.',
};
