import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_scan_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef TableRpcSingleRunner = Future<Map<String, dynamic>> Function(
  String functionName,
  Map<String, dynamic> params,
);

typedef TableTagByUidLoader = Future<Map<String, dynamic>?> Function(
  String normalizedUid,
);

typedef TableByTagLoader = Future<Map<String, dynamic>?> Function(
  String eventId,
  String tagId,
);

class SupabaseTableRepository implements TableRepository {
  SupabaseTableRepository({
    required this.client,
    required this.cache,
    TableRpcSingleRunner? rpcSingleRunner,
    TableTagByUidLoader? tagByUidLoader,
    TableByTagLoader? tableByTagLoader,
  })  : _rpcSingleRunner = rpcSingleRunner,
        _tagByUidLoader = tagByUidLoader,
        _tableByTagLoader = tableByTagLoader;

  final SupabaseClient client;
  final LocalCache cache;
  final TableRpcSingleRunner? _rpcSingleRunner;
  final TableTagByUidLoader? _tagByUidLoader;
  final TableByTagLoader? _tableByTagLoader;

  @override
  Future<EventTableRecord> bindTableTag({
    required String tableId,
    required String scannedUid,
    String? displayLabel,
  }) async {
    final row = await _runRpcSingle(
      'bind_table_tag',
      {
        'target_event_table_id': tableId,
        'scanned_uid': scannedUid,
        'scanned_display_label': displayLabel,
      },
    );

    final table = EventTableRecord.fromJson(row);
    await _saveMergedTables(table.eventId, table);
    return table;
  }

  @override
  Future<EventTableRecord> createTable(CreateEventTableInput input) async {
    final row = await _runRpcSingle(
      'create_event_table',
      {
        'target_event_id': input.eventId,
        'table_label': input.label,
        'table_display_order': input.displayOrder,
        'target_default_ruleset_id': input.defaultRulesetId,
        'target_default_rotation_policy_type':
            _rotationPolicyToJson(input.defaultRotationPolicyType),
        'target_default_rotation_policy_config_json':
            input.defaultRotationPolicyConfig,
      },
    );

    final table = EventTableRecord.fromJson(row);
    await _saveMergedTables(table.eventId, table);
    return table;
  }

  @override
  Future<List<EventTableRecord>> listTables(String eventId) async {
    final rows = await client
        .from('event_tables')
        .select()
        .eq('event_id', eventId)
        .order('display_order', ascending: true)
        .order('label', ascending: true);

    final tables = rows
        .map((row) => EventTableRecord.fromJson(row))
        .toList(growable: false);
    await cache.saveTables(eventId, tables);
    return tables;
  }

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async {
    return cache.readTables(eventId);
  }

  @override
  Future<EventTableRecord> resolveTableByTag({
    required String eventId,
    required String scannedUid,
  }) async {
    final normalizedUid = _normalizeTagUid(scannedUid);
    final tagRow = await _loadTagByUid(normalizedUid);
    if (tagRow == null) {
      throw const TableTagResolutionException(
        TableTagResolutionFailure.unknownTag,
      );
    }

    if (tagRow['default_tag_type'] != 'table') {
      throw const TableTagResolutionException(
        TableTagResolutionFailure.nonTableTag,
      );
    }

    final tagId = tagRow['id'] as String?;
    if (tagId == null || tagId.isEmpty) {
      throw const TableTagResolutionException(
        TableTagResolutionFailure.unknownTag,
      );
    }

    final tableRow = await _loadTableByTag(eventId, tagId);
    if (tableRow == null) {
      throw const TableTagResolutionException(
        TableTagResolutionFailure.wrongEventOrUnbound,
      );
    }

    final table = EventTableRecord.fromJson(tableRow);
    await _saveMergedTables(eventId, table);
    return table;
  }

  @override
  Future<EventTableRecord> updateTable(UpdateEventTableInput input) async {
    final row = await _runRpcSingle(
      'update_event_table',
      {
        'target_event_table_id': input.id,
        'table_label': input.label,
        'table_display_order': input.displayOrder,
      },
    );

    final table = EventTableRecord.fromJson(row);
    await _saveMergedTables(table.eventId, table);
    return table;
  }

  Future<Map<String, dynamic>?> _loadTagByUid(String normalizedUid) async {
    final loader = _tagByUidLoader;
    if (loader != null) {
      return loader(normalizedUid);
    }

    final row = await client
        .from('nfc_tags')
        .select('id, default_tag_type')
        .eq('uid_hex', normalizedUid)
        .maybeSingle();
    return row?.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>?> _loadTableByTag(
    String eventId,
    String tagId,
  ) async {
    final loader = _tableByTagLoader;
    if (loader != null) {
      return loader(eventId, tagId);
    }

    final row = await client
        .from('event_tables')
        .select()
        .eq('event_id', eventId)
        .eq('nfc_tag_id', tagId)
        .maybeSingle();
    return row?.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> _runRpcSingle(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final runner = _rpcSingleRunner;
    if (runner != null) {
      return runner(functionName, params);
    }

    final response = await client.rpc(functionName, params: params);
    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return response.cast<String, dynamic>();
    }

    throw StateError(
      'Expected a single row map from $functionName but received ${response.runtimeType}.',
    );
  }

  Future<void> _saveMergedTables(String eventId, EventTableRecord table) async {
    final currentTables = await readCachedTables(eventId);
    final mergedTables = [
      ...currentTables.where((currentTable) => currentTable.id != table.id),
      table,
    ]..sort((left, right) {
        final orderComparison = left.displayOrder.compareTo(right.displayOrder);
        if (orderComparison != 0) {
          return orderComparison;
        }
        return left.label.compareTo(right.label);
      });
    await cache.saveTables(eventId, mergedTables);
  }
}

String _normalizeTagUid(String value) {
  return value.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '').toUpperCase();
}

String _rotationPolicyToJson(RotationPolicyType value) {
  return switch (value) {
    RotationPolicyType.dealerCycleReturnToInitialEast =>
      'dealer_cycle_return_to_initial_east',
  };
}
