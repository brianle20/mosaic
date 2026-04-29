import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/supabase_event_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseEventRepository lifecycle', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('completeEvent returns a completed event and refreshes cache',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseEventRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        eventMutationRunner: (functionName, params) async {
          expect(functionName, 'complete_event');
          expect(params['target_event_id'], 'evt_01');
          return {
            'id': 'evt_01',
            'owner_user_id': 'usr_01',
            'title': 'Friday Night Mahjong',
            'timezone': 'America/Los_Angeles',
            'starts_at': '2026-04-24T19:00:00-07:00',
            'lifecycle_status': 'completed',
            'checkin_open': true,
            'scoring_open': false,
            'cover_charge_cents': 2000,
            'prize_budget_cents': 50000,
            'default_ruleset_id': 'HK_STANDARD_V1',
            'prevailing_wind': 'east',
            'row_version': 2,
          };
        },
      );

      final event = await repository.completeEvent('evt_01');

      expect(event.lifecycleStatus, EventLifecycleStatus.completed);

      final cachedEvent = cache.readEvent('evt_01');
      expect(cachedEvent, isNotNull);
      expect(cachedEvent!.lifecycleStatus, EventLifecycleStatus.completed);

      final cachedEvents = cache.readEvents();
      expect(
          cachedEvents.single.lifecycleStatus, EventLifecycleStatus.completed);
    });

    test('finalizeEvent returns a finalized event and refreshes cache',
        () async {
      final cache = await LocalCache.create();
      await cache.saveEvents([
        EventRecord.fromJson(const {
          'id': 'evt_01',
          'owner_user_id': 'usr_01',
          'title': 'Friday Night Mahjong',
          'timezone': 'America/Los_Angeles',
          'starts_at': '2026-04-24T19:00:00-07:00',
          'lifecycle_status': 'completed',
          'checkin_open': true,
          'scoring_open': false,
          'cover_charge_cents': 2000,
          'prize_budget_cents': 50000,
          'default_ruleset_id': 'HK_STANDARD_V1',
          'prevailing_wind': 'east',
          'row_version': 2,
        }),
      ]);
      final repository = SupabaseEventRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        eventMutationRunner: (functionName, params) async {
          expect(functionName, 'finalize_event');
          expect(params['target_event_id'], 'evt_01');
          return {
            'id': 'evt_01',
            'owner_user_id': 'usr_01',
            'title': 'Friday Night Mahjong',
            'timezone': 'America/Los_Angeles',
            'starts_at': '2026-04-24T19:00:00-07:00',
            'lifecycle_status': 'finalized',
            'checkin_open': false,
            'scoring_open': false,
            'cover_charge_cents': 2000,
            'prize_budget_cents': 50000,
            'default_ruleset_id': 'HK_STANDARD_V1',
            'prevailing_wind': 'east',
            'row_version': 3,
          };
        },
      );

      final event = await repository.finalizeEvent('evt_01');

      expect(event.lifecycleStatus, EventLifecycleStatus.finalized);

      final cachedEvent = cache.readEvent('evt_01');
      expect(cachedEvent, isNotNull);
      expect(cachedEvent!.lifecycleStatus, EventLifecycleStatus.finalized);

      final cachedEvents = cache.readEvents();
      expect(
          cachedEvents.single.lifecycleStatus, EventLifecycleStatus.finalized);
    });

    test('cancelEvent returns a cancelled event and refreshes cache', () async {
      final cache = await LocalCache.create();
      await cache.saveEvents([
        EventRecord.fromJson(const {
          'id': 'evt_01',
          'owner_user_id': 'usr_01',
          'title': 'Friday Night Mahjong',
          'timezone': 'America/Los_Angeles',
          'starts_at': '2026-04-24T19:00:00-07:00',
          'lifecycle_status': 'active',
          'checkin_open': true,
          'scoring_open': true,
          'cover_charge_cents': 2000,
          'prize_budget_cents': 50000,
          'default_ruleset_id': 'HK_STANDARD_V1',
          'prevailing_wind': 'east',
          'row_version': 2,
        }),
      ]);
      final repository = SupabaseEventRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        eventCancellationRunner: (eventId) async {
          expect(eventId, 'evt_01');
          return {
            'id': 'evt_01',
            'owner_user_id': 'usr_01',
            'title': 'Friday Night Mahjong',
            'timezone': 'America/Los_Angeles',
            'starts_at': '2026-04-24T19:00:00-07:00',
            'lifecycle_status': 'cancelled',
            'checkin_open': false,
            'scoring_open': false,
            'cover_charge_cents': 2000,
            'prize_budget_cents': 50000,
            'default_ruleset_id': 'HK_STANDARD_V1',
            'prevailing_wind': 'east',
            'row_version': 3,
          };
        },
      );

      final event = await repository.cancelEvent('evt_01');

      expect(event.lifecycleStatus, EventLifecycleStatus.cancelled);
      expect(event.checkinOpen, isFalse);
      expect(event.scoringOpen, isFalse);

      final cachedEvent = cache.readEvent('evt_01');
      expect(cachedEvent, isNotNull);
      expect(cachedEvent!.lifecycleStatus, EventLifecycleStatus.cancelled);

      final cachedEvents = cache.readEvents();
      expect(
          cachedEvents.single.lifecycleStatus, EventLifecycleStatus.cancelled);
    });

    test('deleteEvent removes event from cache', () async {
      final cache = await LocalCache.create();
      await cache.saveEvents([
        EventRecord.fromJson(const {
          'id': 'evt_00',
          'owner_user_id': 'usr_01',
          'title': 'Draft Friday Night Mahjong',
          'timezone': 'America/Los_Angeles',
          'starts_at': '2026-04-24T19:00:00-07:00',
          'lifecycle_status': 'draft',
          'checkin_open': false,
          'scoring_open': false,
          'cover_charge_cents': 2000,
          'prize_budget_cents': 50000,
          'default_ruleset_id': 'HK_STANDARD_V1',
          'prevailing_wind': 'east',
        }),
      ]);
      await cache.saveEvent(
        EventRecord.fromJson(const {
          'id': 'evt_00',
          'owner_user_id': 'usr_01',
          'title': 'Draft Friday Night Mahjong',
          'timezone': 'America/Los_Angeles',
          'starts_at': '2026-04-24T19:00:00-07:00',
          'lifecycle_status': 'draft',
          'checkin_open': false,
          'scoring_open': false,
          'cover_charge_cents': 2000,
          'prize_budget_cents': 50000,
          'default_ruleset_id': 'HK_STANDARD_V1',
          'prevailing_wind': 'east',
        }),
      );
      var deletedEventId = '';
      final repository = SupabaseEventRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        eventDeletionRunner: (eventId) async {
          deletedEventId = eventId;
        },
      );

      await repository.deleteEvent('evt_00');

      expect(deletedEventId, 'evt_00');
      expect(cache.readEvent('evt_00'), isNull);
      expect(cache.readEvents(), isEmpty);
    });
  });
}
