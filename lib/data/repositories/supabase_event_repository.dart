import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef EventMutationRunner = Future<Map<String, dynamic>> Function(
  String functionName,
  Map<String, dynamic> params,
);

class SupabaseEventRepository implements EventRepository {
  SupabaseEventRepository({
    required this.client,
    required this.cache,
    EventMutationRunner? eventMutationRunner,
  }) : _eventMutationRunner = eventMutationRunner;

  final SupabaseClient client;
  final LocalCache cache;
  final EventMutationRunner? _eventMutationRunner;

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
        .order('starts_at', ascending: true);

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
    ]..sort((left, right) => left.startsAt.compareTo(right.startsAt));

    await cache.saveEvent(record);
    await cache.saveEvents(mergedEvents);
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
