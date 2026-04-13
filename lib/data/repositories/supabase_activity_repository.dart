import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/activity_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef ActivityLoader = Future<List<Map<String, dynamic>>> Function(
  String eventId,
  EventActivityCategory category,
);

class SupabaseActivityRepository implements ActivityRepository {
  SupabaseActivityRepository({
    required this.client,
    required this.cache,
    ActivityLoader? activityLoader,
  }) : _activityLoader = activityLoader;

  final SupabaseClient client;
  final LocalCache cache;
  final ActivityLoader? _activityLoader;

  @override
  Future<List<EventActivityEntry>> readCachedActivity(
    String eventId,
    EventActivityCategory category,
  ) async {
    return cache.readActivity(eventId, category);
  }

  @override
  Future<List<EventActivityEntry>> loadActivity(
    String eventId,
    EventActivityCategory category,
  ) async {
    final loader = _activityLoader;
    final rows = loader != null
        ? await loader(eventId, category)
        : (await client.rpc(
            'list_event_activity',
            params: {
              'target_event_id': eventId,
              'target_category': category.name,
            },
          ) as List)
            .map((row) => (row as Map).cast<String, dynamic>())
            .toList(growable: false);

    final entries =
        rows.map(EventActivityEntry.fromJson).toList(growable: false);
    await cache.saveActivity(eventId, category, entries);
    return entries;
  }
}
