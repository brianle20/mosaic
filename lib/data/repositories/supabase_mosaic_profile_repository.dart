import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef MosaicProfileRpcRunner = Future<dynamic> Function(
  String functionName,
  Map<String, dynamic> params,
);

class SupabaseMosaicProfileRepository implements MosaicProfileRepository {
  SupabaseMosaicProfileRepository({required SupabaseClient client})
      : _rpcRunner = ((functionName, params) {
          return client.rpc(functionName, params: params);
        });

  SupabaseMosaicProfileRepository.withRpcRunner({
    required MosaicProfileRpcRunner rpcRunner,
  }) : _rpcRunner = rpcRunner;

  final MosaicProfileRpcRunner _rpcRunner;

  @override
  Future<List<HandPhotoRecord>> listHandEvidenceReview(String eventId) async {
    final response = await _rpcRunner(
      'list_hand_evidence_review',
      {'target_event_id': eventId},
    );
    if (response is List) {
      return response
          .map((row) => HandPhotoRecord.fromJson(_rowMap(row)))
          .toList(growable: false);
    }

    throw StateError(
      'Expected a row list from list_hand_evidence_review but received '
      '${response.runtimeType}.',
    );
  }

  @override
  Future<HandTileEntryRecord> upsertHandTileEntry({
    required String handResultId,
    required Map<String, dynamic> tilesJson,
    required int? calculatedFanCount,
    required String calculationVersion,
  }) async {
    final response = await _rpcRunner(
      'upsert_hand_tile_entry',
      {
        'target_hand_result_id': handResultId,
        'target_tiles_json': tilesJson,
        'target_calculated_fan_count': calculatedFanCount,
        'target_calculation_version': calculationVersion,
      },
    );
    return HandTileEntryRecord.fromJson(
      _singleRowMap('upsert_hand_tile_entry', response),
    );
  }
}

Map<String, dynamic> _rowMap(Object? row) {
  if (row is Map<String, dynamic>) {
    return row;
  }
  if (row is Map) {
    return row.cast<String, dynamic>();
  }
  throw StateError('Expected a row map but received ${row.runtimeType}.');
}

Map<String, dynamic> _singleRowMap(String functionName, Object? response) {
  if (response is List) {
    if (response.isEmpty) {
      throw StateError('Expected a row from $functionName but received none.');
    }
    return _rowMap(response.first);
  }
  return _rowMap(response);
}
