import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseGuestRepository implements GuestRepository {
  SupabaseGuestRepository({
    required this.client,
    required this.cache,
  });

  final SupabaseClient client;
  final LocalCache cache;

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) async {
    final inserted = await client
        .from('event_guests')
        .insert(input.toInsertJson())
        .select()
        .single();

    final guest = EventGuestRecord.fromJson(inserted);
    await _saveMergedGuestList(input.eventId, guest);
    return guest;
  }

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async {
    final rows = await client
        .from('event_guests')
        .select()
        .eq('event_id', eventId)
        .order('display_name', ascending: true);

    final guests = rows
        .map((row) => EventGuestRecord.fromJson(row))
        .toList(growable: false);
    await cache.saveGuests(eventId, guests);
    return guests;
  }

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async {
    return cache.readGuests(eventId);
  }

  @override
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) async {
    final updated = await client
        .from('event_guests')
        .update(input.toUpdateJson())
        .eq('id', input.id)
        .select()
        .single();

    final guest = EventGuestRecord.fromJson(updated);
    await _saveMergedGuestList(input.eventId, guest);
    return guest;
  }

  Future<void> _saveMergedGuestList(
    String eventId,
    EventGuestRecord guest,
  ) async {
    final currentGuests = await readCachedGuests(eventId);
    final mergedGuests = [
      ...currentGuests.where((currentGuest) => currentGuest.id != guest.id),
      guest,
    ]..sort((left, right) => left.displayName.compareTo(right.displayName));
    await cache.saveGuests(eventId, mergedGuests);
  }
}
