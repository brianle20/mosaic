import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/supabase_guest_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseGuestRepository cover ledger', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getGuestDetail returns ordered cover entries', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        guestByIdLoader: (_) async => {
          'id': 'gst_01',
          'event_id': 'evt_01',
          'display_name': 'Alice',
          'normalized_name': 'alice',
          'attendance_status': 'checked_in',
          'cover_status': 'paid',
          'cover_amount_cents': 2000,
          'is_comped': false,
          'has_scored_play': false,
        },
        activeAssignmentLoader: (_) async => null,
        coverEntriesLoader: (_) async => [
          {
            'id': 'cov_02',
            'event_id': 'evt_01',
            'event_guest_id': 'gst_01',
            'amount_cents': -500,
            'method': 'refund',
            'recorded_by_user_id': 'usr_01',
            'recorded_at': '2026-04-24T19:10:00-07:00',
            'note': 'Refunded duplicate charge',
            'created_at': '2026-04-24T19:10:00-07:00',
          },
          {
            'id': 'cov_01',
            'event_id': 'evt_01',
            'event_guest_id': 'gst_01',
            'amount_cents': 2000,
            'method': 'cash',
            'recorded_by_user_id': 'usr_01',
            'recorded_at': '2026-04-24T19:00:00-07:00',
            'note': 'Paid at door',
            'created_at': '2026-04-24T19:00:00-07:00',
          },
        ],
      );

      final detail = await repository.getGuestDetail('gst_01');

      expect(detail, isNotNull);
      expect(detail!.coverEntries, hasLength(2));
      expect(detail.coverEntries.first.method, CoverEntryMethod.refund);
      expect(detail.coverEntries.first.amountCents, -500);
      expect(detail.coverEntries.last.method, CoverEntryMethod.cash);
    });

    test('recordCoverEntry calls RPC and refreshes cached ledger rows',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'record_cover_entry');
          expect(params['target_event_guest_id'], 'gst_02');
          expect(params['target_amount_cents'], 2000);
          expect(params['target_method'], 'venmo');
          expect(params['target_note'], 'Paid after seating');
          return {
            'id': 'cov_03',
            'event_id': 'evt_01',
            'event_guest_id': 'gst_02',
            'amount_cents': 2000,
            'method': 'venmo',
            'recorded_by_user_id': 'usr_01',
            'recorded_at': '2026-04-24T19:20:00-07:00',
            'note': 'Paid after seating',
            'created_at': '2026-04-24T19:20:00-07:00',
          };
        },
        guestByIdLoader: (_) async => {
          'id': 'gst_02',
          'event_id': 'evt_01',
          'display_name': 'Bob',
          'normalized_name': 'bob',
          'attendance_status': 'expected',
          'cover_status': 'partial',
          'cover_amount_cents': 1000,
          'is_comped': false,
          'has_scored_play': false,
        },
        activeAssignmentLoader: (_) async => null,
        coverEntriesLoader: (_) async => [
          {
            'id': 'cov_03',
            'event_id': 'evt_01',
            'event_guest_id': 'gst_02',
            'amount_cents': 2000,
            'method': 'venmo',
            'recorded_by_user_id': 'usr_01',
            'recorded_at': '2026-04-24T19:20:00-07:00',
            'note': 'Paid after seating',
            'created_at': '2026-04-24T19:20:00-07:00',
          },
          {
            'id': 'cov_02',
            'event_id': 'evt_01',
            'event_guest_id': 'gst_02',
            'amount_cents': 1000,
            'method': 'cash',
            'recorded_by_user_id': 'usr_01',
            'recorded_at': '2026-04-24T19:00:00-07:00',
            'note': 'Deposit',
            'created_at': '2026-04-24T19:00:00-07:00',
          },
        ],
      );

      final detail = await repository.recordCoverEntry(
        guestId: 'gst_02',
        amountCents: 2000,
        method: CoverEntryMethod.venmo,
        note: 'Paid after seating',
      );

      expect(detail.coverEntries, hasLength(2));
      expect(detail.coverEntries.first.method, CoverEntryMethod.venmo);

      final cachedEntries = await repository.readCachedGuestCoverEntries(
        'gst_02',
      );
      expect(cachedEntries, hasLength(2));
      expect(cachedEntries.first.note, 'Paid after seating');
    });
  });
}
