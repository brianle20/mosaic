import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef PrizePlanLoader = Future<Map<String, dynamic>?> Function(
    String eventId);
typedef PrizePreviewLoader = Future<List<Map<String, dynamic>>> Function(
  String eventId,
);
typedef PrizeAwardsLoader = Future<List<Map<String, dynamic>>> Function(
  String eventId,
);
typedef PrizeMutationRunner = Future<Map<String, dynamic>> Function(
  String functionName,
  Map<String, dynamic> params,
);

class SupabasePrizeRepository implements PrizeRepository {
  SupabasePrizeRepository({
    required this.client,
    required this.cache,
    PrizePlanLoader? prizePlanLoader,
    PrizePreviewLoader? prizePreviewLoader,
    PrizeAwardsLoader? prizeAwardsLoader,
    PrizeMutationRunner? prizeMutationRunner,
  })  : _prizePlanLoader = prizePlanLoader,
        _prizePreviewLoader = prizePreviewLoader,
        _prizeAwardsLoader = prizeAwardsLoader,
        _prizeMutationRunner = prizeMutationRunner;

  final SupabaseClient client;
  final LocalCache cache;
  final PrizePlanLoader? _prizePlanLoader;
  final PrizePreviewLoader? _prizePreviewLoader;
  final PrizeAwardsLoader? _prizeAwardsLoader;
  final PrizeMutationRunner? _prizeMutationRunner;

  @override
  Future<PrizePlanDetail?> readCachedPrizePlan(String eventId) async {
    return cache.readPrizePlan(eventId);
  }

  @override
  Future<PrizePlanDetail?> loadPrizePlan({
    required String eventId,
    required int prizeBudgetCents,
  }) async {
    final loader = _prizePlanLoader;
    final payload = loader != null
        ? await loader(eventId)
        : await _loadPrizePlanPayload(eventId);

    if (payload == null) {
      return null;
    }

    final detail = PrizePlanDetail.fromJson(
      payload,
      prizeBudgetCents: prizeBudgetCents,
    );
    await cache.savePrizePlan(eventId, detail);
    return detail;
  }

  @override
  Future<PrizePlanDetail> upsertPrizePlan(UpsertPrizePlanInput input) async {
    final response =
        await _runMutation('upsert_prize_plan', input.toRpcParams());
    final payload = response.containsKey('plan')
        ? response
        : {
            'plan': response,
            'tiers': await client
                .from('prize_tiers')
                .select()
                .eq('prize_plan_id', response['id'] as String)
                .order('place', ascending: true),
          };
    final detail = PrizePlanDetail.fromJson(
      payload,
      prizeBudgetCents: input.prizeBudgetCents,
    );
    await cache.savePrizePlan(input.eventId, detail);
    return detail;
  }

  @override
  Future<List<PrizeAwardPreviewRow>> readCachedPrizePreview(
      String eventId) async {
    return cache.readPrizePreview(eventId);
  }

  @override
  Future<List<PrizeAwardPreviewRow>> loadPrizePreview(String eventId) async {
    final loader = _prizePreviewLoader;
    final rows = loader != null
        ? await loader(eventId)
        : await _loadPreviewRows(eventId);
    final preview = rows
        .map((row) => PrizeAwardPreviewRow.fromJson(row))
        .toList(growable: false);
    await cache.savePrizePreview(eventId, preview);
    return preview;
  }

  @override
  Future<List<PrizeAwardRecord>> readCachedPrizeAwards(String eventId) async {
    return cache.readPrizeAwards(eventId);
  }

  @override
  Future<List<PrizeAwardRecord>> loadPrizeAwards(String eventId) async {
    final loader = _prizeAwardsLoader;
    final rows =
        loader != null ? await loader(eventId) : await _loadAwardRows(eventId);
    final awards = rows
        .map((row) => PrizeAwardRecord.fromJson(row))
        .toList(growable: false);
    await cache.savePrizeAwards(eventId, awards);
    return awards;
  }

  @override
  Future<List<PrizeAwardRecord>> lockPrizeAwards(String eventId) async {
    final response = await _runMutation(
      'lock_prize_awards',
      {'target_event_id': eventId},
    );
    final rows = (response['rows'] as List<dynamic>? ?? const <dynamic>[])
        .map((row) => (row as Map).cast<String, dynamic>())
        .toList(growable: false);
    final awards = rows
        .map((row) => PrizeAwardRecord.fromJson(row))
        .toList(growable: false);
    await cache.savePrizeAwards(eventId, awards);
    return awards;
  }

  @override
  Future<PrizeAwardRecord> markPrizeAwardPaid({
    required String awardId,
    String? paidMethod,
    String? paidNote,
  }) async {
    final response = await _runMutation(
      'mark_prize_award_paid',
      {
        'target_prize_award_id': awardId,
        'target_paid_method': paidMethod,
        'target_paid_note': paidNote,
      },
    );
    return PrizeAwardRecord.fromJson(response);
  }

  @override
  Future<PrizeAwardRecord> voidPrizeAward({
    required String awardId,
    String? paidNote,
  }) async {
    final response = await _runMutation(
      'void_prize_award',
      {
        'target_prize_award_id': awardId,
        'target_paid_note': paidNote,
      },
    );
    return PrizeAwardRecord.fromJson(response);
  }

  Future<Map<String, dynamic>?> _loadPrizePlanPayload(String eventId) async {
    final planRow = await client
        .from('prize_plans')
        .select()
        .eq('event_id', eventId)
        .maybeSingle();
    if (planRow == null) {
      return null;
    }

    final tiersRows = await client
        .from('prize_tiers')
        .select()
        .eq('prize_plan_id', planRow['id'] as String)
        .order('place', ascending: true);

    return {
      'plan': planRow,
      'tiers': tiersRows,
    };
  }

  Future<List<Map<String, dynamic>>> _loadPreviewRows(String eventId) async {
    final response = await client.rpc(
      'preview_prize_awards',
      params: {'target_event_id': eventId},
    );
    if (response is List) {
      return response
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList(growable: false);
    }

    throw StateError(
      'Expected a row list from preview_prize_awards but received ${response.runtimeType}.',
    );
  }

  Future<List<Map<String, dynamic>>> _loadAwardRows(String eventId) async {
    final rows = await client
        .from('prize_awards')
        .select()
        .eq('event_id', eventId)
        .order('rank_start', ascending: true);
    return rows
        .map((row) => row.cast<String, dynamic>())
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _runMutation(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final runner = _prizeMutationRunner;
    if (runner != null) {
      return runner(functionName, params);
    }

    final response = await client.rpc(functionName, params: params);
    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is List) {
      return {
        'rows': response
            .map((row) => (row as Map).cast<String, dynamic>())
            .toList(growable: false),
      };
    }

    if (response is Map) {
      return response.cast<String, dynamic>();
    }

    throw StateError(
      'Expected a map or list response from $functionName but received ${response.runtimeType}.',
    );
  }
}
