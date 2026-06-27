import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:mosaic/data/offline/offline_models.dart';
import 'package:mosaic/data/offline/offline_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class SqliteOfflineStore implements OfflineStore {
  SqliteOfflineStore._(this._backend);

  final _OfflineStoreBackend _backend;

  static const _schemaVersion = 2;
  static const _mutationsTable = 'offline_mutations';
  static const _photoUploadsTable = 'offline_photo_uploads';

  static Future<SqliteOfflineStore> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final databasePath = p.join(directory.path, 'mosaic_offline.db');
    final database = await openDatabase(
      databasePath,
      version: _schemaVersion,
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    return SqliteOfflineStore._(_SqfliteOfflineStoreBackend(database));
  }

  @visibleForTesting
  static Future<SqliteOfflineStore> openForTesting({
    required String databasePath,
    required DatabaseFactory databaseFactory,
  }) async {
    final database = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
    return SqliteOfflineStore._(_SqfliteOfflineStoreBackend(database));
  }

  static Future<SqliteOfflineStore> inMemory() async {
    try {
      final database = await openDatabase(
        inMemoryDatabasePath,
        version: _schemaVersion,
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
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
    await _createMutationSchema(db);
    await _createPhotoUploadSchema(db);
  }

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createPhotoUploadSchema(db);
    }
  }

  static Future<void> _createMutationSchema(Database db) async {
    await db.execute('''
      create table $_mutationsTable (
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
      'on $_mutationsTable (status, created_at)',
    );
    await db.execute(
      'create index offline_mutations_session_idx '
      'on $_mutationsTable (session_id, created_at)',
    );
  }

  static Future<void> _createPhotoUploadSchema(Database db) async {
    await db.execute('''
      create table if not exists $_photoUploadsTable (
        id text primary key,
        mutation_id text not null,
        event_id text not null,
        session_id text not null,
        client_photo_id text not null,
        local_path text not null,
        captured_at text not null,
        status text not null,
        remote_hand_result_id text,
        storage_path text,
        attempt_count integer not null default 0,
        last_error text,
        last_attempted_at text,
        created_at text not null,
        updated_at text not null
      )
    ''');
    await db.execute(
      'create index if not exists offline_photo_uploads_pending_idx '
      'on $_photoUploadsTable (status, created_at)',
    );
    await db.execute(
      'create index if not exists offline_photo_uploads_session_idx '
      'on $_photoUploadsTable (session_id, created_at)',
    );
    await db.execute(
      'create index if not exists offline_photo_uploads_mutation_idx '
      'on $_photoUploadsTable (mutation_id)',
    );
  }

  @override
  Future<void> insertMutation(OfflineMutationRecord mutation) {
    return _backend.insert(_mutationsTable, _toRow(mutation));
  }

  @override
  Future<void> insertPhotoUpload(OfflinePhotoUploadRecord upload) {
    return _backend.insert(_photoUploadsTable, _photoUploadToRow(upload));
  }

  @override
  Future<void> insertMutationWithPhotoUpload(
    OfflineMutationRecord mutation,
    OfflinePhotoUploadRecord upload,
  ) {
    return _backend.insertAll([
      _OfflineStoreInsert(_mutationsTable, _toRow(mutation)),
      _OfflineStoreInsert(_photoUploadsTable, _photoUploadToRow(upload)),
    ]);
  }

  @override
  Future<OfflineMutationRecord?> readMutation(String id) async {
    final rows = await _backend.query(
      _mutationsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  @override
  Future<List<OfflineMutationRecord>> readPendingMutations() async {
    final rows = await _backend.query(
      _mutationsTable,
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
      _mutationsTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at asc',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<List<OfflinePhotoUploadRecord>> readPendingPhotoUploads() async {
    final rows = await _backend.query(
      _photoUploadsTable,
      where: 'status in (?, ?)',
      whereArgs: [
        offlinePhotoUploadStatusToJson(OfflinePhotoUploadStatus.pending),
        offlinePhotoUploadStatusToJson(OfflinePhotoUploadStatus.failed),
      ],
      orderBy: 'created_at asc',
    );
    return rows.map(_photoUploadFromRow).toList(growable: false);
  }

  @override
  Future<List<OfflinePhotoUploadRecord>> readPhotoUploadsForSession(
    String sessionId,
  ) async {
    final rows = await _backend.query(
      _photoUploadsTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at asc',
    );
    return rows.map(_photoUploadFromRow).toList(growable: false);
  }

  @override
  Future<void> markSyncing(String id, {required DateTime attemptedAt}) async {
    final existing = await readMutation(id);
    await _backend.update(
      _mutationsTable,
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
      _mutationsTable,
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
      _mutationsTable,
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
      _mutationsTable,
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
  Future<void> markPhotoUploadUploading(
    String id, {
    required DateTime attemptedAt,
  }) async {
    final rows = await _backend.query(
      _photoUploadsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final existing = rows.isEmpty ? null : _photoUploadFromRow(rows.single);
    await _backend.update(
      _photoUploadsTable,
      {
        'status':
            offlinePhotoUploadStatusToJson(OfflinePhotoUploadStatus.uploading),
        'attempt_count': (existing?.attemptCount ?? 0) + 1,
        'last_attempted_at': attemptedAt.toUtc().toIso8601String(),
        'updated_at': attemptedAt.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markPhotoUploadUploaded(
    String id, {
    required String storagePath,
  }) async {
    await _backend.update(
      _photoUploadsTable,
      {
        'status':
            offlinePhotoUploadStatusToJson(OfflinePhotoUploadStatus.uploaded),
        'storage_path': storagePath,
        'last_error': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markPhotoUploadFailed(String id, String error) async {
    await _backend.update(
      _photoUploadsTable,
      {
        'status':
            offlinePhotoUploadStatusToJson(OfflinePhotoUploadStatus.failed),
        'last_error': error,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markPhotoUploadBlocked(String id, String error) async {
    await _backend.update(
      _photoUploadsTable,
      {
        'status':
            offlinePhotoUploadStatusToJson(OfflinePhotoUploadStatus.blocked),
        'last_error': error,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> attachRemoteHandResultToPhotoUpload(
    String mutationId,
    String remoteHandResultId,
  ) async {
    await _backend.update(
      _photoUploadsTable,
      {
        'remote_hand_result_id': remoteHandResultId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'mutation_id = ?',
      whereArgs: [mutationId],
    );
  }

  @override
  Future<void> resetPhotoUploadsUploadingToPending() async {
    await _backend.update(
      _photoUploadsTable,
      {
        'status':
            offlinePhotoUploadStatusToJson(OfflinePhotoUploadStatus.pending),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'status = ?',
      whereArgs: [
        offlinePhotoUploadStatusToJson(OfflinePhotoUploadStatus.uploading),
      ],
    );
  }

  @override
  Future<void> resetSyncingToPending() async {
    await _backend.update(
      _mutationsTable,
      {
        'status': offlineMutationStatusToJson(OfflineMutationStatus.pending),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'status = ?',
      whereArgs: [offlineMutationStatusToJson(OfflineMutationStatus.syncing)],
    );
  }

  @override
  Future<void> resetBlockedMutationsToPending({
    required String lastErrorContains,
  }) async {
    await _backend.update(
      _mutationsTable,
      {
        'status': offlineMutationStatusToJson(OfflineMutationStatus.pending),
        'last_error': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'status = ? and last_error like ?',
      whereArgs: [
        offlineMutationStatusToJson(OfflineMutationStatus.blocked),
        '%$lastErrorContains%',
      ],
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

  Map<String, Object?> _photoUploadToRow(OfflinePhotoUploadRecord upload) {
    return {
      'id': upload.id,
      'mutation_id': upload.mutationId,
      'event_id': upload.eventId,
      'session_id': upload.sessionId,
      'client_photo_id': upload.clientPhotoId,
      'local_path': upload.localPath,
      'captured_at': upload.capturedAt.toUtc().toIso8601String(),
      'status': offlinePhotoUploadStatusToJson(upload.status),
      'remote_hand_result_id': upload.remoteHandResultId,
      'storage_path': upload.storagePath,
      'attempt_count': upload.attemptCount,
      'last_error': upload.lastError,
      'last_attempted_at': upload.lastAttemptedAt?.toUtc().toIso8601String(),
      'created_at': upload.createdAt.toUtc().toIso8601String(),
      'updated_at': upload.updatedAt.toUtc().toIso8601String(),
    };
  }

  OfflinePhotoUploadRecord _photoUploadFromRow(Map<String, Object?> row) {
    return OfflinePhotoUploadRecord(
      id: row['id']! as String,
      mutationId: row['mutation_id']! as String,
      eventId: row['event_id']! as String,
      sessionId: row['session_id']! as String,
      clientPhotoId: row['client_photo_id']! as String,
      localPath: row['local_path']! as String,
      capturedAt: DateTime.parse(row['captured_at']! as String),
      status: offlinePhotoUploadStatusFromJson(row['status']! as String),
      remoteHandResultId: row['remote_hand_result_id'] as String?,
      storagePath: row['storage_path'] as String?,
      attemptCount: row['attempt_count']! as int,
      lastError: row['last_error'] as String?,
      lastAttemptedAt: row['last_attempted_at'] == null
          ? null
          : DateTime.parse(row['last_attempted_at']! as String),
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}

abstract interface class _OfflineStoreBackend {
  Future<void> insert(String table, Map<String, Object?> row);

  Future<void> insertAll(List<_OfflineStoreInsert> inserts);

  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  });

  Future<void> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  });

  Future<void> close();
}

class _OfflineStoreInsert {
  const _OfflineStoreInsert(this.table, this.row);

  final String table;
  final Map<String, Object?> row;
}

class _SqfliteOfflineStoreBackend implements _OfflineStoreBackend {
  const _SqfliteOfflineStoreBackend(this._database);

  final Database _database;

  @override
  Future<void> insert(String table, Map<String, Object?> row) {
    return _database.insert(
      table,
      row,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> insertAll(List<_OfflineStoreInsert> inserts) async {
    await _database.transaction((transaction) async {
      for (final insert in inserts) {
        await transaction.insert(
          insert.table,
          insert.row,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) {
    return _database.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  @override
  Future<void> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    await _database.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
    );
  }

  @override
  Future<void> close() => _database.close();
}

class _MemoryOfflineStoreBackend implements _OfflineStoreBackend {
  final Map<String, Map<String, Map<String, Object?>>> _tables = {};
  var _isClosed = false;

  @override
  Future<void> insert(String table, Map<String, Object?> row) async {
    _checkOpen();
    final rows = _rowsFor(table);
    final id = row['id']! as String;
    if (rows.containsKey(id)) {
      throw StateError('Offline row already exists in $table: $id');
    }
    rows[id] = Map<String, Object?>.from(row);
  }

  @override
  Future<void> insertAll(List<_OfflineStoreInsert> inserts) async {
    _checkOpen();
    final snapshot = _copyTables();
    try {
      for (final insert in inserts) {
        await this.insert(insert.table, insert.row);
      }
    } catch (_) {
      _tables
        ..clear()
        ..addAll(snapshot);
      rethrow;
    }
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    _checkOpen();
    var rows = _rowsFor(table)
        .values
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
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    _checkOpen();
    for (final row in _rowsFor(table).values) {
      if (_matches(row, where, whereArgs ?? const [])) {
        row.addAll(values);
      }
    }
  }

  @override
  Future<void> close() async {
    _isClosed = true;
    _tables.clear();
  }

  void _checkOpen() {
    if (_isClosed) {
      throw StateError('Offline store is closed.');
    }
  }

  Map<String, Map<String, Object?>> _rowsFor(String table) {
    return _tables.putIfAbsent(table, () => {});
  }

  bool _matches(
    Map<String, Object?> row,
    String? where,
    List<Object?> whereArgs,
  ) {
    return switch (where) {
      null => true,
      'id = ?' => row['id'] == whereArgs[0],
      'mutation_id = ?' => row['mutation_id'] == whereArgs[0],
      'session_id = ?' => row['session_id'] == whereArgs[0],
      'status in (?, ?)' =>
        row['status'] == whereArgs[0] || row['status'] == whereArgs[1],
      'status = ?' => row['status'] == whereArgs[0],
      'status = ? and last_error like ?' =>
        row['status'] == whereArgs[0] &&
            _like(row['last_error'] as String?, whereArgs[1]! as String),
      'session_id = ? and status in (?, ?, ?)' =>
        row['session_id'] == whereArgs[0] &&
            (row['status'] == whereArgs[1] ||
                row['status'] == whereArgs[2] ||
                row['status'] == whereArgs[3]),
      _ => throw UnsupportedError('Unsupported memory where clause: $where'),
    };
  }

  bool _like(String? value, String pattern) {
    if (value == null) {
      return false;
    }
    if (pattern.startsWith('%') && pattern.endsWith('%')) {
      return value.contains(pattern.substring(1, pattern.length - 1));
    }
    return value == pattern;
  }

  Map<String, Map<String, Map<String, Object?>>> _copyTables() {
    return {
      for (final tableEntry in _tables.entries)
        tableEntry.key: {
          for (final rowEntry in tableEntry.value.entries)
            rowEntry.key: Map<String, Object?>.from(rowEntry.value),
        },
    };
  }
}
