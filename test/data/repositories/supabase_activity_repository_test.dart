import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/activity_models.dart';
import 'package:mosaic/data/repositories/supabase_activity_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseActivityRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads newest-first activity entries from the RPC', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseActivityRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        activityLoader: (eventId, category) async {
          expect(eventId, 'evt_01');
          expect(category, EventActivityCategory.all);
          return [
            {
              'id': 'act_02',
              'event_id': eventId,
              'entity_type': 'guest_cover_entry',
              'entity_id': 'cov_01',
              'action': 'record',
              'category': 'payments',
              'summary_text': 'Recorded cover entry: cash 2000',
              'metadata_json': {'amount_cents': 2000},
              'reason': null,
              'created_at': '2026-04-24T19:10:00-07:00',
            },
            {
              'id': 'act_01',
              'event_id': eventId,
              'entity_type': 'event',
              'entity_id': eventId,
              'action': 'start',
              'category': 'event',
              'summary_text': 'Started event',
              'metadata_json': {},
              'reason': null,
              'created_at': '2026-04-24T19:00:00-07:00',
            },
          ];
        },
      );

      final entries = await repository.loadActivity(
        'evt_01',
        EventActivityCategory.all,
      );

      expect(entries, hasLength(2));
      expect(entries.first.summaryText, 'Recorded cover entry: cash 2000');
      expect(entries.first.category, EventActivityCategory.payments);
      expect(entries.last.action, 'start');
    });

    test('refreshes category-scoped cache after fetch', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseActivityRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        activityLoader: (eventId, category) async {
          expect(category, EventActivityCategory.payments);
          return [
            {
              'id': 'act_03',
              'event_id': eventId,
              'entity_type': 'guest_cover_entry',
              'entity_id': 'cov_02',
              'action': 'record',
              'category': 'payments',
              'summary_text': 'Recorded cover entry: refund -500',
              'metadata_json': {'amount_cents': -500},
              'reason': 'Duplicate payment',
              'created_at': '2026-04-24T19:20:00-07:00',
            },
          ];
        },
      );

      await repository.loadActivity('evt_01', EventActivityCategory.payments);
      final cachedEntries = await repository.readCachedActivity(
        'evt_01',
        EventActivityCategory.payments,
      );

      expect(cachedEntries, hasLength(1));
      expect(cachedEntries.single.reason, 'Duplicate payment');
      expect(cachedEntries.single.category, EventActivityCategory.payments);
    });
  });
}
