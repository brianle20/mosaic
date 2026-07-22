import 'dart:developer' as developer;

import 'package:mosaic/data/models/finals_state_models.dart';
import 'package:mosaic/data/offline/network_reachability.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase/supabase.dart';

typedef FinalsRpcRunner = Future<dynamic> Function(
  String functionName,
  Map<String, dynamic> params,
);

typedef FinalsDiagnosticReporter = void Function(
    FinalsRpcDiagnostic diagnostic);

class FinalsRpcDiagnostic {
  FinalsRpcDiagnostic({
    required this.functionName,
    required Map<String, dynamic> params,
    required this.exception,
    required this.stackTrace,
  }) : params = Map.unmodifiable(params);

  final String functionName;
  final Map<String, dynamic> params;
  final PostgrestException exception;
  final StackTrace stackTrace;
}

class FinalsCommandException implements Exception {
  const FinalsCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupabaseFinalsRepository implements FinalsRepository {
  SupabaseFinalsRepository({
    required SupabaseClient client,
    required NetworkReachability reachability,
    FinalsDiagnosticReporter? diagnosticReporter,
  })  : _rpcRunner = ((functionName, params) {
          return client.rpc(functionName, params: params);
        }),
        _reachability = reachability,
        _diagnosticReporter = diagnosticReporter ?? _reportFinalsDiagnostic;

  SupabaseFinalsRepository.withRpcRunner({
    required FinalsRpcRunner rpcRunner,
    required NetworkReachability reachability,
    FinalsDiagnosticReporter? diagnosticReporter,
  })  : _rpcRunner = rpcRunner,
        _reachability = reachability,
        _diagnosticReporter = diagnosticReporter ?? _reportFinalsDiagnostic;

  static const genericCommandErrorMessage =
      'Unable to complete that Finals action right now. Refresh and try again.';

  static const _offlineMessage =
      'Finals actions require a connection. Reconnect and try again.';

  final FinalsRpcRunner _rpcRunner;
  final NetworkReachability _reachability;
  final FinalsDiagnosticReporter _diagnosticReporter;

  @override
  Future<FinalsSetupPreview> previewFinals(String eventId) async {
    final response = await _runRpc(
      'preview_event_finals',
      {'target_event_id': eventId},
    );
    return FinalsSetupPreview.fromJson(_jsonObject(response));
  }

  @override
  Future<FinalsState> loadFinalsState(String eventId) async {
    final response = await _runRpc(
      'get_event_finals_state',
      {'target_event_id': eventId},
    );
    return FinalsState.fromJson(_jsonObject(response));
  }

  @override
  Future<FinalsState> beginFinals(BeginFinalsInput input) async {
    await _requireConnection();
    final response = await _runRpc(
      'begin_event_finals',
      {
        'target_event_id': input.eventId,
        'selected_champions_table_id': input.championsTableId,
        'selected_redemption_table_id': input.redemptionTableId,
        'expected_state_version': input.expectedStateVersion,
        'expected_preview_token': input.expectedPreviewToken,
      },
      mapNetworkFailure: true,
    );
    return FinalsState.fromJson(_jsonObject(response));
  }

  @override
  Future<FinalsState> startContest(StartFinalsContestInput input) async {
    await _requireConnection();
    final response = await _runRpc(
      'start_finals_contest',
      {
        'target_contest_id': input.contestId,
        'selected_table_id': input.tableId,
        'expected_state_version': input.expectedStateVersion,
      },
      mapNetworkFailure: true,
    );
    return FinalsState.fromJson(_jsonObject(response));
  }

  @override
  Future<FinalsState> resumeFinalsStart(ResumeFinalsStartInput input) async {
    await _requireConnection();
    final response = await _runRpc(
      'resume_event_finals_start',
      {
        'target_event_id': input.eventId,
        'expected_recovery_token': input.recoveryToken,
      },
      mapNetworkFailure: true,
    );
    return FinalsState.fromJson(_jsonObject(response));
  }

  Future<void> _requireConnection() async {
    if (!await _reachability.isReachable()) {
      throw const NetworkUnavailableException(_offlineMessage);
    }
  }

  Future<dynamic> _runRpc(
    String functionName,
    Map<String, dynamic> params, {
    bool mapNetworkFailure = false,
  }) async {
    try {
      return await _rpcRunner(functionName, params);
    } on PostgrestException catch (exception, stackTrace) {
      final message = exception.message;
      if (exception.code == 'P0001' && _hostSafeMessages.contains(message)) {
        throw FinalsCommandException(message);
      }
      _recordDiagnostic(
        FinalsRpcDiagnostic(
          functionName: functionName,
          params: params,
          exception: exception,
          stackTrace: stackTrace,
        ),
      );
      throw const FinalsCommandException(genericCommandErrorMessage);
    } catch (exception) {
      if (mapNetworkFailure && _reachability.isNetworkException(exception)) {
        throw const NetworkUnavailableException(_offlineMessage);
      }
      rethrow;
    }
  }

  void _recordDiagnostic(FinalsRpcDiagnostic diagnostic) {
    try {
      _diagnosticReporter(diagnostic);
    } catch (_) {
      // Diagnostics must never replace the host-safe command failure.
    }
  }
}

void _reportFinalsDiagnostic(FinalsRpcDiagnostic diagnostic) {
  developer.log(
    'Finals RPC ${diagnostic.functionName} failed with '
    'params ${diagnostic.params}.',
    name: 'mosaic.finals',
    error: diagnostic.exception,
    stackTrace: diagnostic.stackTrace,
  );
}

Map<String, dynamic> _jsonObject(Object? response) {
  if (response is Map<String, dynamic>) return response;
  if (response is Map) return response.cast<String, dynamic>();
  throw const FormatException('Expected a Finals protocol object.');
}

const _hostSafeMessages = <String>{
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
