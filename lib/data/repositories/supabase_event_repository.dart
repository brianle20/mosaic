import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef EventMutationRunner = Future<Map<String, dynamic>> Function(
  String functionName,
  Map<String, dynamic> params,
);
typedef EventCancellationRunner = Future<Map<String, dynamic>> Function(
  String eventId,
);
typedef EventRevertRunner = Future<Map<String, dynamic>> Function(
  String eventId,
);
typedef EventDeletionRunner = Future<void> Function(String eventId);

class SupabaseEventRepository implements EventRepository {
  SupabaseEventRepository({
    required this.client,
    required this.cache,
    EventMutationRunner? eventMutationRunner,
    EventCancellationRunner? eventCancellationRunner,
    EventRevertRunner? eventRevertRunner,
    EventDeletionRunner? eventDeletionRunner,
  })  : _eventMutationRunner = eventMutationRunner,
        _eventCancellationRunner = eventCancellationRunner,
        _eventRevertRunner = eventRevertRunner,
        _eventDeletionRunner = eventDeletionRunner;

  final SupabaseClient client;
  final LocalCache cache;
  final EventMutationRunner? _eventMutationRunner;
  final EventCancellationRunner? _eventCancellationRunner;
  final EventRevertRunner? _eventRevertRunner;
  final EventDeletionRunner? _eventDeletionRunner;

  @override
  Future<EventRecord> createEvent(CreateEventInput input) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('A signed-in host is required to create an event.');
    }

    final inserted = await client
        .from('events')
        .insert(input.toInsertJson(ownerUserId: userId))
        .select()
        .single();

    final record = EventRecord.fromJson(inserted);
    await _saveEventRecord(record);
    return record;
  }

  @override
  Future<EventRecord> startEvent(String eventId) async {
    final response = await _runMutation(
      'start_event',
      {'target_event_id': eventId},
    );
    final record = EventRecord.fromJson(response);
    await _saveEventRecord(record);
    return record;
  }

  @override
  Future<EventRecord> setOperationalFlags({
    required String eventId,
    required bool checkinOpen,
    required bool scoringOpen,
  }) async {
    final response = await _runMutation(
      'set_event_operational_flags',
      {
        'target_event_id': eventId,
        'target_checkin_open': checkinOpen,
        'target_scoring_open': scoringOpen,
      },
    );
    final record = EventRecord.fromJson(response);
    await _saveEventRecord(record);
    return record;
  }

  @override
  Future<EventRecord> completeEvent(String eventId) async {
    final response = await _runMutation(
      'complete_event',
      {'target_event_id': eventId},
    );
    final record = EventRecord.fromJson(response);
    await _saveEventRecord(record);
    return record;
  }

  @override
  Future<EventRecord> finalizeEvent(String eventId) async {
    final response = await _runMutation(
      'finalize_event',
      {'target_event_id': eventId},
    );
    final record = EventRecord.fromJson(response);
    await _saveEventRecord(record);
    return record;
  }

  @override
  Future<EventRecord> cancelEvent(String eventId) async {
    final runner = _eventCancellationRunner;
    final response = runner != null
        ? await runner(eventId)
        : await client
            .from('events')
            .update({
              'lifecycle_status': 'cancelled',
              'checkin_open': false,
              'scoring_open': false,
            })
            .eq('id', eventId)
            .select()
            .single();

    final record = EventRecord.fromJson(response);
    await _saveEventRecord(record);
    return record;
  }

  @override
  Future<EventRecord> revertEventToDraft(String eventId) async {
    final runner = _eventRevertRunner;
    final response = runner != null
        ? await runner(eventId)
        : await _revertEventToDraft(eventId);

    final record = EventRecord.fromJson(response);
    await _saveEventRecord(record);
    return record;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    final runner = _eventDeletionRunner;
    if (runner != null) {
      await runner(eventId);
    } else {
      await client.from('events').delete().eq('id', eventId);
    }

    await cache.removeEvent(eventId);
  }

  @override
  Future<EventRecord?> getEvent(String eventId) async {
    final row =
        await client.from('events').select().eq('id', eventId).maybeSingle();
    if (row == null) {
      return null;
    }

    final record = EventRecord.fromJson(row);
    await cache.saveEvent(record);
    return record;
  }

  @override
  Future<List<EventRecord>> listEvents() async {
    final rows = await client
        .from('events')
        .select()
        .order('created_at', ascending: false);

    final records =
        rows.map((row) => EventRecord.fromJson(row)).toList(growable: false);
    await cache.saveEvents(records);
    for (final record in records) {
      await cache.saveEvent(record);
    }
    return records;
  }

  @override
  Future<List<EventRecord>> readCachedEvents() async {
    return cache.readEvents();
  }

  Future<void> _saveEventRecord(EventRecord record) async {
    final currentEvents = await readCachedEvents();
    final mergedEvents = [
      ...currentEvents.where((event) => event.id != record.id),
      record,
    ]..sort((left, right) => right.createdAt.compareTo(left.createdAt));

    await cache.saveEvent(record);
    await cache.saveEvents(mergedEvents);
  }

  Future<Map<String, dynamic>> _revertEventToDraft(String eventId) async {
    final eventRow =
        await client.from('events').select().eq('id', eventId).single();
    final event = EventRecord.fromJson(eventRow);
    if (event.lifecycleStatus != EventLifecycleStatus.active) {
      throw StateError('Only active events can be reverted to draft.');
    }

    final guestRows = _rowsFromResponse(
      await client
          .from('event_guests')
          .select('id, attendance_status, checked_in_at')
          .eq('event_id', eventId),
    );
    final hasCheckedInGuest = guestRows.any(_guestHasLiveAttendance);
    if (hasCheckedInGuest) {
      throw StateError(
        'Events with checked-in guests cannot be reverted to draft.',
      );
    }

    final sessionRows = _rowsFromResponse(
      await client
          .from('table_sessions')
          .select('id')
          .eq('event_id', eventId)
          .limit(1),
    );
    if (sessionRows.isNotEmpty) {
      throw StateError(
          'Events with table sessions cannot be reverted to draft.');
    }

    final scoreRows = _rowsFromResponse(
      await client
          .from('event_score_totals')
          .select('id')
          .eq('event_id', eventId)
          .limit(1),
    );
    if (scoreRows.isNotEmpty) {
      throw StateError('Events with scores cannot be reverted to draft.');
    }

    return client
        .from('events')
        .update({
          'lifecycle_status': 'draft',
          'checkin_open': false,
          'scoring_open': false,
        })
        .eq('id', eventId)
        .select()
        .single();
  }

  bool _guestHasLiveAttendance(Map<String, dynamic> row) {
    return row['checked_in_at'] != null ||
        row['attendance_status'] == 'checked_in' ||
        row['attendance_status'] == 'checked_out';
  }

  List<Map<String, dynamic>> _rowsFromResponse(Object response) {
    if (response is List) {
      return response
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList(growable: false);
    }

    throw StateError(
      'Expected a list response but received ${response.runtimeType}.',
    );
  }

  Future<Map<String, dynamic>> _runMutation(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final runner = _eventMutationRunner;
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
      'Expected a map response from $functionName but received ${response.runtimeType}.',
    );
  }
}
