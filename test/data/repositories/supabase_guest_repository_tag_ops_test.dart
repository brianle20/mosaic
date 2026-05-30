import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/supabase_guest_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseGuestRepository tag operations', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('maps check-in RPC result into guest detail without active tag',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'check_in_guest');
          expect(params['target_event_guest_id'], 'gst_01');
          return {
            'id': 'gst_01',
            'event_id': 'evt_01',
            'display_name': 'Alice',
            'normalized_name': 'alice',
            'attendance_status': 'checked_in',
            'cover_status': 'paid',
            'cover_amount_cents': 2000,
            'is_comped': false,
            'has_scored_play': false,
          };
        },
        activeAssignmentLoader: (_) async => null,
        coverEntriesLoader: (_) async => const [],
      );

      final detail = await repository.checkInGuest('gst_01');

      expect(detail.guest.isCheckedIn, isTrue);
      expect(detail.activeTagAssignment, isNull);
    });

    test('maps assign tag flow into guest detail with active assignment',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'assign_guest_tag');
          expect(params['target_event_guest_id'], 'gst_02');
          expect(params['scanned_uid'], '04aa bb');
          return {
            'assignment_id': 'asg_01',
            'event_id': 'evt_01',
            'event_guest_id': 'gst_02',
            'status': 'assigned',
            'assigned_at': '2026-04-24T19:15:00-07:00',
            'nfc_tag': {
              'id': 'tag_01',
              'uid_hex': '04AABB',
              'uid_fingerprint': '04AABB',
              'default_tag_type': 'player',
              'status': 'active',
            },
          };
        },
        guestByIdLoader: (_) async => {
          'id': 'gst_02',
          'event_id': 'evt_01',
          'display_name': 'Bob',
          'normalized_name': 'bob',
          'attendance_status': 'checked_in',
          'cover_status': 'paid',
          'cover_amount_cents': 2000,
          'is_comped': false,
          'has_scored_play': false,
        },
        activeAssignmentLoader: (_) async => {
          'assignment_id': 'asg_01',
          'event_id': 'evt_01',
          'event_guest_id': 'gst_02',
          'status': 'assigned',
          'assigned_at': '2026-04-24T19:15:00-07:00',
          'nfc_tag': {
            'id': 'tag_01',
            'uid_hex': '04AABB',
            'uid_fingerprint': '04AABB',
            'default_tag_type': 'player',
            'status': 'active',
          },
        },
        coverEntriesLoader: (_) async => const [],
      );

      final detail = await repository.assignGuestTag(
        guestId: 'gst_02',
        scannedUid: '04aa bb',
      );

      expect(detail.guest.displayName, 'Bob');
      expect(detail.activeTagAssignment, isA<GuestTagAssignmentSummary>());
      expect(detail.activeTagAssignment?.tag.defaultTagType, NfcTagType.player);
    });

    test('resolveGuestByActiveTag maps a guest and active assignment',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcListRunner: (functionName, params) async {
          expect(functionName, 'resolve_guest_by_active_tag');
          expect(params, {
            'target_event_id': 'evt_01',
            'scanned_uid': '0a0b0c',
          });

          return [
            {
              'guest': _guestJson('gst_03', 'Caren Ly'),
              'assignment': _assignmentJson('asg_03', 'gst_03'),
            },
          ];
        },
      );

      final result = await repository.resolveGuestByActiveTag(
        eventId: 'evt_01',
        scannedUid: '0a0b0c',
      );

      expect(result, isNotNull);
      expect(result!.guest.id, 'gst_03');
      expect(result.guest.displayName, 'Caren Ly');
      expect(result.assignment.eventGuestId, 'gst_03');
      expect(result.assignment.tag.uidHex, '0A0B0C');
      expect(result.assignment.tag.displayLabel, 'UID 1F');
      expect(cache.readGuests('evt_01').single.id, 'gst_03');
    });

    test('resolveGuestByActiveTag returns null when the tag is not assigned',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcListRunner: (functionName, params) async => const [],
      );

      final result = await repository.resolveGuestByActiveTag(
        eventId: 'evt_01',
        scannedUid: 'missing',
      );

      expect(result, isNull);
    });

    test('resolveGuestByActiveTag rejects duplicate active assignments',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcListRunner: (functionName, params) async => [
          {
            'guest': _guestJson('gst_04', 'Caren Ly'),
            'assignment': _assignmentJson('asg_04', 'gst_04'),
          },
          {
            'guest': _guestJson('gst_05', 'Ada Fu'),
            'assignment': _assignmentJson('asg_05', 'gst_05'),
          },
        ],
      );

      expect(
        () => repository.resolveGuestByActiveTag(
          eventId: 'evt_01',
          scannedUid: '0A0B0C',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

Map<String, Object?> _guestJson(String eventGuestId, String displayName) {
  return {
    'id': eventGuestId,
    'event_id': 'evt_01',
    'display_name': displayName,
    'normalized_name': displayName.toLowerCase(),
    'attendance_status': 'checked_in',
    'cover_status': 'paid',
    'cover_amount_cents': 2000,
    'is_comped': false,
    'has_scored_play': false,
  };
}

Map<String, Object?> _assignmentJson(
  String assignmentId,
  String eventGuestId,
) {
  return {
    'assignment_id': assignmentId,
    'event_id': 'evt_01',
    'event_guest_id': eventGuestId,
    'status': 'assigned',
    'assigned_at': '2026-05-30T00:00:00Z',
    'nfc_tag': {
      'id': 'tag_01',
      'uid_hex': '0A0B0C',
      'uid_fingerprint': '0A0B0C',
      'default_tag_type': 'player',
      'status': 'active',
      'display_label': 'UID 1F',
    },
  };
}
