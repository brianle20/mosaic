import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef GuestByIdLoader = Future<Map<String, dynamic>> Function(String guestId);
typedef ActiveAssignmentLoader = Future<Map<String, dynamic>?> Function(
  String guestId,
);
typedef RpcSingleRunner = Future<Map<String, dynamic>> Function(
  String functionName,
  Map<String, dynamic> params,
);

class SupabaseGuestRepository implements GuestRepository {
  SupabaseGuestRepository({
    required this.client,
    required this.cache,
    GuestByIdLoader? guestByIdLoader,
    ActiveAssignmentLoader? activeAssignmentLoader,
    RpcSingleRunner? rpcSingleRunner,
  })  : _guestByIdLoader = guestByIdLoader,
        _activeAssignmentLoader = activeAssignmentLoader,
        _rpcSingleRunner = rpcSingleRunner;

  final SupabaseClient client;
  final LocalCache cache;
  final GuestByIdLoader? _guestByIdLoader;
  final ActiveAssignmentLoader? _activeAssignmentLoader;
  final RpcSingleRunner? _rpcSingleRunner;

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) async {
    final guestRow = await _loadGuestById(guestId);
    if (guestRow == null) {
      return null;
    }

    final guest = EventGuestRecord.fromJson(guestRow);
    final assignmentRow = await _loadActiveAssignment(guestId);
    final assignment = assignmentRow == null
        ? null
        : GuestTagAssignmentSummary.fromJson(assignmentRow);
    await _saveMergedGuestList(guest.eventId, guest);
    return GuestDetailRecord(
      guest: guest,
      activeTagAssignment: assignment,
    );
  }

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
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async {
    final rows = await client
        .from('event_guest_tag_assignments')
        .select('''
          id,
          event_id,
          event_guest_id,
          status,
          assigned_at,
          nfc_tag:nfc_tags (
            id,
            uid_hex,
            uid_fingerprint,
            default_tag_type,
            status,
            display_label,
            note
          )
        ''')
        .eq('event_id', eventId)
        .eq('status', 'assigned');

    final summaries = rows
        .map((row) => GuestTagAssignmentSummary.fromJson({
              'assignment_id': row['id'],
              'event_id': row['event_id'],
              'event_guest_id': row['event_guest_id'],
              'status': row['status'],
              'assigned_at': row['assigned_at'],
              'nfc_tag': row['nfc_tag'],
            }))
        .toList(growable: false);

    return {
      for (final summary in summaries) summary.eventGuestId: summary,
    };
  }

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async {
    return cache.readGuests(eventId);
  }

  @override
  Future<GuestDetailRecord> checkInGuest(String guestId) async {
    late Map<String, dynamic> row;
    try {
      row = await _runRpcSingle(
        'check_in_guest',
        {
          'target_event_guest_id': guestId,
        },
      );
    } catch (exception) {
      if (!_shouldUseFallback(exception, 'check_in_guest')) {
        rethrow;
      }

      row = await client
          .from('event_guests')
          .update({
            'attendance_status': 'checked_in',
            'checked_in_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', guestId)
          .select()
          .single();
    }
    final guest = EventGuestRecord.fromJson(row);
    await _saveMergedGuestList(guest.eventId, guest);
    final assignmentRow = await _loadActiveAssignment(guestId);
    return GuestDetailRecord(
      guest: guest,
      activeTagAssignment: assignmentRow == null
          ? null
          : GuestTagAssignmentSummary.fromJson(assignmentRow),
    );
  }

  @override
  Future<GuestDetailRecord> assignGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) async {
    try {
      await _runRpcSingle(
        'assign_guest_tag',
        {
          'target_event_guest_id': guestId,
          'scanned_uid': scannedUid,
          'scanned_display_label': displayLabel,
        },
      );
    } catch (exception) {
      if (!_shouldUseFallback(exception, 'assign_guest_tag')) {
        rethrow;
      }

      await _assignGuestTagFallback(
        guestId: guestId,
        scannedUid: scannedUid,
        displayLabel: displayLabel,
      );
    }
    final detail = await getGuestDetail(guestId);
    if (detail == null) {
      throw StateError('Assigned guest could not be reloaded.');
    }

    return detail;
  }

  @override
  Future<GuestDetailRecord> replaceGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) async {
    try {
      await _runRpcSingle(
        'replace_guest_tag',
        {
          'target_event_guest_id': guestId,
          'scanned_uid': scannedUid,
          'scanned_display_label': displayLabel,
        },
      );
    } catch (exception) {
      if (!_shouldUseFallback(exception, 'replace_guest_tag')) {
        rethrow;
      }

      await _replaceGuestTagFallback(
        guestId: guestId,
        scannedUid: scannedUid,
        displayLabel: displayLabel,
      );
    }
    final detail = await getGuestDetail(guestId);
    if (detail == null) {
      throw StateError('Replaced guest could not be reloaded.');
    }

    return detail;
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

  Future<Map<String, dynamic>?> _loadGuestById(String guestId) async {
    final guestByIdLoader = _guestByIdLoader;
    if (guestByIdLoader != null) {
      return guestByIdLoader(guestId);
    }

    final row = await client
        .from('event_guests')
        .select()
        .eq('id', guestId)
        .maybeSingle();
    return _castRow(row);
  }

  Future<Map<String, dynamic>?> _loadActiveAssignment(String guestId) async {
    final activeAssignmentLoader = _activeAssignmentLoader;
    if (activeAssignmentLoader != null) {
      return activeAssignmentLoader(guestId);
    }

    try {
      final result = await client.rpc(
        'get_guest_tag_assignment_summary',
        params: {
          'target_event_guest_id': guestId,
        },
      );
      return _castMaybeSingleRpcRow(result);
    } catch (exception) {
      if (!_shouldUseFallback(exception, 'get_guest_tag_assignment_summary')) {
        rethrow;
      }

      final rows = await client
          .from('event_guest_tag_assignments')
          .select('''
            id,
            event_id,
            event_guest_id,
            status,
            assigned_at,
            nfc_tag:nfc_tags (
              id,
              uid_hex,
              uid_fingerprint,
              default_tag_type,
              status,
              display_label,
              note
            )
          ''')
          .eq('event_guest_id', guestId)
          .eq('status', 'assigned')
          .limit(1);
      if (rows.isEmpty) {
        return null;
      }

      final row = rows.first;
      return {
        'assignment_id': row['id'],
        'event_id': row['event_id'],
        'event_guest_id': row['event_guest_id'],
        'status': row['status'],
        'assigned_at': row['assigned_at'],
        'nfc_tag': row['nfc_tag'],
      };
    }
  }

  Future<Map<String, dynamic>> _runRpcSingle(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final rpcSingleRunner = _rpcSingleRunner;
    if (rpcSingleRunner != null) {
      return rpcSingleRunner(functionName, params);
    }

    final result = await client.rpc(functionName, params: params);
    final row = _castMaybeSingleRpcRow(result);
    if (row == null) {
      throw StateError('RPC $functionName did not return a row.');
    }

    return row;
  }

  Map<String, dynamic>? _castMaybeSingleRpcRow(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is List) {
      if (value.isEmpty) {
        return null;
      }

      return _castRow(value.first);
    }

    return _castRow(value);
  }

  Map<String, dynamic>? _castRow(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.cast<String, dynamic>();
    }

    throw StateError('Expected a map row result but received ${value.runtimeType}.');
  }

  bool _shouldUseFallback(Object exception, String functionName) {
    final message = exception.toString().toLowerCase();
    final normalizedFunctionName = functionName.toLowerCase();
    return message.contains(normalizedFunctionName) &&
        (message.contains('could not find') ||
            message.contains('schema cache') ||
            message.contains('404'));
  }

  Future<void> _assignGuestTagFallback({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) async {
    final detail = await getGuestDetail(guestId);
    if (detail == null) {
      throw StateError('Guest not found.');
    }
    if (!detail.guest.isEligibleForPlayerTagAssignment) {
      throw StateError(
        'Guest must be paid or comped before receiving a player tag.',
      );
    }
    if (!detail.guest.isCheckedIn) {
      throw StateError(
        'Guest must be checked in before receiving a player tag.',
      );
    }
    if (detail.activeTagAssignment != null) {
      throw StateError('This guest already has an active player tag.');
    }

    final hostId = client.auth.currentUser?.id;
    if (hostId == null || hostId.isEmpty) {
      throw StateError('A signed-in host is required to assign a player tag.');
    }

    final normalizedUid = scannedUid
        .replaceAll(RegExp(r'[^0-9A-Za-z]+'), '')
        .toUpperCase();
    if (normalizedUid.isEmpty) {
      throw StateError('Tag UID is required.');
    }

    final existingTag = await client
        .from('nfc_tags')
        .select()
        .eq('uid_hex', normalizedUid)
        .maybeSingle();

    late final Map<String, dynamic> tagRow;
    if (existingTag == null) {
      tagRow = await client
          .from('nfc_tags')
          .insert({
            'uid_hex': normalizedUid,
            'uid_fingerprint': normalizedUid,
            'default_tag_type': 'player',
            'display_label': displayLabel,
            'status': 'active',
            'first_seen_at': DateTime.now().toUtc().toIso8601String(),
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
    } else {
      final castExistingTag = _castRow(existingTag)!;
      if (castExistingTag['default_tag_type'] == 'table') {
        throw StateError('Only player tags can be assigned to guests.');
      }
      tagRow = await client
          .from('nfc_tags')
          .update({
            'default_tag_type': 'player',
            'display_label': displayLabel ?? castExistingTag['display_label'],
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', castExistingTag['id'])
          .select()
          .single();
    }

    final conflictingAssignment = await client
        .from('event_guest_tag_assignments')
        .select('id')
        .eq('event_id', detail.guest.eventId)
        .eq('nfc_tag_id', tagRow['id'])
        .eq('status', 'assigned')
        .maybeSingle();
    if (conflictingAssignment != null) {
      throw StateError('This tag is already assigned to another guest in this event.');
    }

    await client.from('event_guest_tag_assignments').insert({
      'event_id': detail.guest.eventId,
      'event_guest_id': detail.guest.id,
      'nfc_tag_id': tagRow['id'],
      'status': 'assigned',
      'assigned_at': DateTime.now().toUtc().toIso8601String(),
      'assigned_by_user_id': hostId,
    });
  }

  Future<void> _replaceGuestTagFallback({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) async {
    final detail = await getGuestDetail(guestId);
    final currentAssignment = detail?.activeTagAssignment;
    if (detail == null) {
      throw StateError('Guest not found.');
    }
    if (currentAssignment == null) {
      throw StateError('Guest does not have an active tag to replace.');
    }

    await client
        .from('event_guest_tag_assignments')
        .update({
          'status': 'replaced',
          'released_at': DateTime.now().toUtc().toIso8601String(),
          'release_reason': 'replacement',
        })
        .eq('id', currentAssignment.assignmentId);

    await _assignGuestTagFallback(
      guestId: guestId,
      scannedUid: scannedUid,
      displayLabel: displayLabel,
    );
  }
}
