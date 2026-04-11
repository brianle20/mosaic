import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseEventRepository implements EventRepository {
  SupabaseEventRepository({
    required this.client,
    required this.cache,
  });

  final SupabaseClient client;
  final LocalCache cache;

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
    final currentEvents = await readCachedEvents();
    final mergedEvents = [
      ...currentEvents.where((event) => event.id != record.id),
      record
    ]..sort((left, right) => left.startsAt.compareTo(right.startsAt));

    await cache.saveEvent(record);
    await cache.saveEvents(mergedEvents);
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
}
