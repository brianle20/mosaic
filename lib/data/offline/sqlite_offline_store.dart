import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mosaic/data/offline/offline_models.dart';
import 'package:mosaic/data/offline/offline_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class SqliteOfflineStore implements OfflineStore {
  SqliteOfflineStore._(this._backend);

  final _OfflineStoreBackend _backend;

  static const _table = 'offline_mutations';

  static Future<SqliteOfflineStore> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final databasePath = p.join(directory.path, 'mosaic_offline.db');
    final database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: _createSchema,
    );
    return SqliteOfflineStore._(_SqfliteOfflineStoreBackend(database));
  }

  static Future<SqliteOfflineStore> inMemory() async {
    try {
      final database = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: _createSchema,
      );
      return SqliteOfflineStore._(_SqfliteOfflineStoreBackend(database));
    } on MissingPluginException {
      return SqliteOfflineStore._(_MemoryOfflineStoreBackend());
    } on StateError catch (error) {
      if (!error.message.contains('databaseFactory not initialized')) {
        rethrow;
      }
      return SqliteOfflineStore._(_MemoryOfflineStoreBackend());
    }
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      create table $_table (
        id text primary key,
        kind text not null,
        event_id text not null,
        session_id text not null,
        payload_json text not null,
        base_recorded_hand_count integer not null,
        base_last_recorded_hand_id text,
        local_hand_number integer not null,
        created_at text not null,
        updated_at text not null,
        status text not null,
        attempt_count integer not null default 0,
        last_error text,
        last_attempted_at text
      )
    ''');
    await db.execute(
      'create index offline_mutations_pending_idx '
      'on $_table (status, created_at)',
    );
    await db.execute(
      'create index offline_mutations_session_idx '
      'on $_table (session_id, created_at)',
    );
  }

  @override
  Future<void> insertMutation(OfflineMutationRecord mutation) {
    return _backend.insert(_toRow(mutation));
  }

  @override
  Future<OfflineMutationRecord?> readMutation(String id) async {
    final rows = await _backend.query(
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  @override
  Future<List<OfflineMutationRecord>> readPendingMutations() async {
    final rows = await _backend.query(
      where: 'status in (?, ?)',
      whereArgs: [
        offlineMutationStatusToJson(OfflineMutationStatus.pending),
        offlineMutationStatusToJson(OfflineMutationStatus.failed),
      ],
      orderBy: 'created_at asc',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<List<OfflineMutationRecord>> readMutationsForSession(
    String sessionId,
  ) async {
    final rows = await _backend.query(
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at asc',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> markSyncing(String id, {required DateTime attemptedAt}) async {
    final existing = await readMutation(id);
    await _backend.update(
      {
        'status': offlineMutationStatusToJson(OfflineMutationStatus.syncing),
        'attempt_count': (existing?.attemptCount ?? 0) + 1,
        'last_attempted_at': attemptedAt.toUtc().toIso8601String(),
        'updated_at': attemptedAt.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markSynced(String id) async {
    await _backend.update(
      {
        'status': offlineMutationStatusToJson(OfflineMutationStatus.synced),
        'last_error': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markFailed(String id, String error) async {
    await _backend.update(
      {
        'status': offlineMutationStatusToJson(OfflineMutationStatus.failed),
        'last_error': error,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markSessionBlocked(String sessionId, String error) async {
    await _backend.update(
      {
        'status': offlineMutationStatusToJson(OfflineMutationStatus.blocked),
        'last_error': error,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'session_id = ? and status in (?, ?, ?)',
      whereArgs: [
        sessionId,
        offlineMutationStatusToJson(OfflineMutationStatus.pending),
        offlineMutationStatusToJson(OfflineMutationStatus.failed),
        offlineMutationStatusToJson(OfflineMutationStatus.syncing),
      ],
    );
  }

  @override
  Future<void> resetSyncingToPending() async {
    await _backend.update(
      {
        'status': offlineMutationStatusToJson(OfflineMutationStatus.pending),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'status = ?',
      whereArgs: [offlineMutationStatusToJson(OfflineMutationStatus.syncing)],
    );
  }

  @override
  Future<void> close() => _backend.close();

  Map<String, Object?> _toRow(OfflineMutationRecord mutation) {
    return {
      'id': mutation.id,
      'kind': offlineMutationKindToJson(mutation.kind),
      'event_id': mutation.eventId,
      'session_id': mutation.sessionId,
      'payload_json': jsonEncode(mutation.payload),
      'base_recorded_hand_count': mutation.baseRecordedHandCount,
      'base_last_recorded_hand_id': mutation.baseLastRecordedHandId,
      'local_hand_number': mutation.localHandNumber,
      'created_at': mutation.createdAt.toUtc().toIso8601String(),
      'updated_at': mutation.updatedAt.toUtc().toIso8601String(),
      'status': offlineMutationStatusToJson(mutation.status),
      'attempt_count': mutation.attemptCount,
      'last_error': mutation.lastError,
      'last_attempted_at': mutation.lastAttemptedAt?.toUtc().toIso8601String(),
    };
  }

  OfflineMutationRecord _fromRow(Map<String, Object?> row) {
    return OfflineMutationRecord(
      id: row['id']! as String,
      kind: offlineMutationKindFromJson(row['kind']! as String),
      eventId: row['event_id']! as String,
      sessionId: row['session_id']! as String,
      payload: (jsonDecode(row['payload_json']! as String) as Map)
          .cast<String, dynamic>(),
      baseRecordedHandCount: row['base_recorded_hand_count']! as int,
      baseLastRecordedHandId: row['base_last_recorded_hand_id'] as String?,
      localHandNumber: row['local_hand_number']! as int,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      status: offlineMutationStatusFromJson(row['status']! as String),
      attemptCount: row['attempt_count']! as int,
      lastError: row['last_error'] as String?,
      lastAttemptedAt: row['last_attempted_at'] == null
          ? null
          : DateTime.parse(row['last_attempted_at']! as String),
    );
  }
}

abstract interface class _OfflineStoreBackend {
  Future<void> insert(Map<String, Object?> row);

  Future<List<Map<String, Object?>>> query({
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  });

  Future<void> update(
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  });

  Future<void> close();
}

class _SqfliteOfflineStoreBackend implements _OfflineStoreBackend {
  const _SqfliteOfflineStoreBackend(this._database);

  final Database _database;

  @override
  Future<void> insert(Map<String, Object?> row) {
    return _database.insert(
      SqliteOfflineStore._table,
      row,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<List<Map<String, Object?>>> query({
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) {
    return _database.query(
      SqliteOfflineStore._table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  @override
  Future<void> update(
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    await _database.update(
      SqliteOfflineStore._table,
      values,
      where: where,
      whereArgs: whereArgs,
    );
  }

  @override
  Future<void> close() => _database.close();
}

class _MemoryOfflineStoreBackend implements _OfflineStoreBackend {
  final Map<String, Map<String, Object?>> _rows = {};
  var _isClosed = false;

  @override
  Future<void> insert(Map<String, Object?> row) async {
    _checkOpen();
    final id = row['id']! as String;
    if (_rows.containsKey(id)) {
      throw StateError('Mutation already exists: $id');
    }
    _rows[id] = Map<String, Object?>.from(row);
  }

  @override
  Future<List<Map<String, Object?>>> query({
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    _checkOpen();
    var rows = _rows.values
        .where((row) => _matches(row, where, whereArgs ?? const []))
        .map(Map<String, Object?>.from)
        .toList();
    if (orderBy == 'created_at asc') {
      rows.sort(
        (left, right) => (left['created_at']! as String)
            .compareTo(right['created_at']! as String),
      );
    }
    if (limit != null && rows.length > limit) {
      rows = rows.take(limit).toList();
    }
    return rows;
  }

  @override
  Future<void> update(
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    _checkOpen();
    for (final row in _rows.values) {
      if (_matches(row, where, whereArgs ?? const [])) {
        row.addAll(values);
      }
    }
  }

  @override
  Future<void> close() async {
    _isClosed = true;
    _rows.clear();
  }

  void _checkOpen() {
    if (_isClosed) {
      throw StateError('Offline store is closed.');
    }
  }

  bool _matches(
    Map<String, Object?> row,
    String? where,
    List<Object?> whereArgs,
  ) {
    return switch (where) {
      null => true,
      'id = ?' => row['id'] == whereArgs[0],
      'session_id = ?' => row['session_id'] == whereArgs[0],
      'status in (?, ?)' =>
        row['status'] == whereArgs[0] || row['status'] == whereArgs[1],
      'status = ?' => row['status'] == whereArgs[0],
      'session_id = ? and status in (?, ?, ?)' =>
        row['session_id'] == whereArgs[0] &&
            (row['status'] == whereArgs[1] ||
                row['status'] == whereArgs[2] ||
                row['status'] == whereArgs[3]),
      _ => throw UnsupportedError('Unsupported memory where clause: $where'),
    };
  }
}
