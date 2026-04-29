import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef GuestByIdLoader = Future<Map<String, dynamic>> Function(String guestId);
typedef ActiveAssignmentLoader = Future<Map<String, dynamic>?> Function(
  String guestId,
);
typedef CoverEntriesLoader = Future<List<Map<String, dynamic>>> Function(
  String guestId,
);
typedef RpcSingleRunner = Future<Map<String, dynamic>> Function(
  String functionName,
  Map<String, dynamic> params,
);

const _eventGuestSelect = '*, guest_profile:guest_profiles(*)';

class SupabaseGuestRepository implements GuestRepository {
  SupabaseGuestRepository({
    required this.client,
    required this.cache,
    GuestByIdLoader? guestByIdLoader,
    ActiveAssignmentLoader? activeAssignmentLoader,
    CoverEntriesLoader? coverEntriesLoader,
    RpcSingleRunner? rpcSingleRunner,
  })  : _guestByIdLoader = guestByIdLoader,
        _activeAssignmentLoader = activeAssignmentLoader,
        _coverEntriesLoader = coverEntriesLoader,
        _rpcSingleRunner = rpcSingleRunner;

  final SupabaseClient client;
  final LocalCache cache;
  final GuestByIdLoader? _guestByIdLoader;
  final ActiveAssignmentLoader? _activeAssignmentLoader;
  final CoverEntriesLoader? _coverEntriesLoader;
  final RpcSingleRunner? _rpcSingleRunner;

  String? _currentUserId() {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    return userId;
  }

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
    final coverEntries = await loadGuestCoverEntries(guestId);
    await _saveMergedGuestList(guest.eventId, guest);
    return GuestDetailRecord(
      guest: guest,
      coverEntries: coverEntries,
      activeTagAssignment: assignment,
    );
  }

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) async {
    final profile = await _resolveProfileForCreate(input);
    await _ensureProfileIsNotOnEvent(
      eventId: input.eventId,
      guestProfileId: profile.id,
    );
    final inserted = await client
        .from('event_guests')
        .insert(input.toInsertJson(guestProfileId: profile.id))
        .select(_eventGuestSelect)
        .single();

    final guest = EventGuestRecord.fromJson(inserted);
    await _saveMergedGuestList(input.eventId, guest);
    return guest;
  }

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async {
    final rows = await client
        .from('event_guests')
        .select(_eventGuestSelect)
        .eq('event_id', eventId)
        .order('display_name', ascending: true);

    final guests = rows
        .map((row) => EventGuestRecord.fromJson(row))
        .toList(growable: false);
    await cache.saveGuests(eventId, guests);
    return guests;
  }

  @override
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(
    String guestId,
  ) async {
    final rows = await _loadCoverEntries(guestId);
    final entries = rows
        .map(GuestCoverEntryRecord.fromJson)
        .toList(growable: false)
      ..sort((left, right) => right.recordedAt.compareTo(left.recordedAt));
    await cache.saveGuestCoverEntries(guestId, entries);
    return entries;
  }

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async {
    final rows = await client.from('event_guest_tag_assignments').select('''
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
        ''').eq('event_id', eventId).eq('status', 'assigned');

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
  Future<List<GuestProfileMatch>> findGuestProfileMatches(
    GuestProfileLookupInput input,
  ) async {
    final userId = _currentUserId();
    if (userId == null) {
      return const [];
    }

    final matches = <GuestProfileMatch>[];
    final seenProfileIds = <String>{};

    Future<void> addMatch(
      GuestProfileRecord? profile,
      GuestProfileMatchType matchType,
    ) async {
      if (profile == null || !seenProfileIds.add(profile.id)) {
        return;
      }
      matches.add(GuestProfileMatch(profile: profile, matchType: matchType));
    }

    if (input.phoneE164 case final phoneE164?) {
      await addMatch(
        await _findProfileByPhone(userId: userId, phoneE164: phoneE164),
        GuestProfileMatchType.phone,
      );
    }

    if (input.emailLower case final emailLower?) {
      await addMatch(
        await _findProfileByEmail(userId: userId, emailLower: emailLower),
        GuestProfileMatchType.email,
      );
    }

    if (input.normalizedName.isNotEmpty) {
      final nameRows = await client
          .from('guest_profiles')
          .select()
          .eq('owner_user_id', userId)
          .eq('normalized_name', input.normalizedName)
          .limit(3);
      for (final row in nameRows) {
        await addMatch(
          GuestProfileRecord.fromJson(row),
          GuestProfileMatchType.name,
        );
      }
    }

    return matches;
  }

  @override
  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  ) async {
    return cache.readGuestCoverEntries(guestId);
  }

  @override
  Future<GuestDetailRecord> recordCoverEntry({
    required String guestId,
    required int amountCents,
    required CoverEntryMethod method,
    String? note,
  }) async {
    await _runRpcSingle(
      'record_cover_entry',
      {
        'target_event_guest_id': guestId,
        'target_amount_cents': amountCents,
        'target_method': _coverEntryMethodName(method),
        'target_note': note,
      },
    );

    final detail = await getGuestDetail(guestId);
    if (detail == null) {
      throw StateError('Updated guest could not be reloaded.');
    }

    return detail;
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
    final existingGuest = await _loadGuestById(input.id);
    if (existingGuest == null) {
      throw StateError('Guest could not be found.');
    }
    final currentGuest = EventGuestRecord.fromJson(existingGuest);
    await _updateProfileForGuest(
      guestProfileId: currentGuest.guestProfileId,
      displayName: input.displayName,
      normalizedName: input.normalizedName,
      phoneE164: input.phoneE164,
      emailLower: input.emailLower,
    );
    final updated = await client
        .from('event_guests')
        .update(input.toUpdateJson())
        .eq('id', input.id)
        .select(_eventGuestSelect)
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

  Future<GuestProfileRecord> _resolveProfileForCreate(
    CreateGuestInput input,
  ) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw StateError('A signed-in host is required to add a guest.');
    }

    final phoneProfile = input.phoneE164 == null
        ? null
        : await _findProfileByPhone(
            userId: userId,
            phoneE164: input.phoneE164!,
          );
    final emailProfile = input.emailLower == null
        ? null
        : await _findProfileByEmail(
            userId: userId,
            emailLower: input.emailLower!,
          );

    if (phoneProfile != null &&
        emailProfile != null &&
        phoneProfile.id != emailProfile.id) {
      throw StateError(
        'Phone and email match different guest profiles. Review the guest details before saving.',
      );
    }

    final matchedProfile = phoneProfile ?? emailProfile;
    if (matchedProfile != null) {
      return _fillBlankProfileFields(
        profile: matchedProfile,
        phoneE164: input.phoneE164,
        emailLower: input.emailLower,
      );
    }

    final inserted = await client
        .from('guest_profiles')
        .insert({
          'owner_user_id': userId,
          'display_name': input.displayName,
          'normalized_name': input.normalizedName,
          'phone_e164': input.phoneE164,
          'email_lower': input.emailLower,
        })
        .select()
        .single();

    return GuestProfileRecord.fromJson(inserted);
  }

  Future<void> _ensureProfileIsNotOnEvent({
    required String eventId,
    required String guestProfileId,
  }) async {
    final existing = await client
        .from('event_guests')
        .select('id, display_name')
        .eq('event_id', eventId)
        .eq('guest_profile_id', guestProfileId)
        .maybeSingle();
    if (existing != null) {
      throw StateError('This guest is already on this event.');
    }
  }

  Future<GuestProfileRecord?> _findProfileByPhone({
    required String userId,
    required String phoneE164,
  }) async {
    final row = await client
        .from('guest_profiles')
        .select()
        .eq('owner_user_id', userId)
        .eq('phone_e164', phoneE164)
        .maybeSingle();
    final castRow = _castRow(row);
    return castRow == null ? null : GuestProfileRecord.fromJson(castRow);
  }

  Future<GuestProfileRecord?> _findProfileByEmail({
    required String userId,
    required String emailLower,
  }) async {
    final row = await client
        .from('guest_profiles')
        .select()
        .eq('owner_user_id', userId)
        .eq('email_lower', emailLower)
        .maybeSingle();
    final castRow = _castRow(row);
    return castRow == null ? null : GuestProfileRecord.fromJson(castRow);
  }

  Future<GuestProfileRecord> _fillBlankProfileFields({
    required GuestProfileRecord profile,
    required String? phoneE164,
    required String? emailLower,
  }) async {
    final updates = <String, dynamic>{};
    if (profile.phoneE164 == null && phoneE164 != null) {
      updates['phone_e164'] = phoneE164;
    }
    if (profile.emailLower == null && emailLower != null) {
      updates['email_lower'] = emailLower;
    }

    if (updates.isEmpty) {
      return profile;
    }

    final updated = await client
        .from('guest_profiles')
        .update(updates)
        .eq('id', profile.id)
        .select()
        .single();
    return GuestProfileRecord.fromJson(updated);
  }

  Future<void> _updateProfileForGuest({
    required String guestProfileId,
    required String displayName,
    required String normalizedName,
    required String? phoneE164,
    required String? emailLower,
  }) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw StateError('A signed-in host is required to edit a guest.');
    }

    final phoneProfile = phoneE164 == null
        ? null
        : await _findProfileByPhone(userId: userId, phoneE164: phoneE164);
    final emailProfile = emailLower == null
        ? null
        : await _findProfileByEmail(userId: userId, emailLower: emailLower);

    if (phoneProfile != null && phoneProfile.id != guestProfileId) {
      throw StateError('Phone is already used by another guest profile.');
    }
    if (emailProfile != null && emailProfile.id != guestProfileId) {
      throw StateError('Email is already used by another guest profile.');
    }

    await client.from('guest_profiles').update({
      'display_name': displayName,
      'normalized_name': normalizedName,
      'phone_e164': phoneE164,
      'email_lower': emailLower,
    }).eq('id', guestProfileId);
  }

  Future<Map<String, dynamic>?> _loadGuestById(String guestId) async {
    final guestByIdLoader = _guestByIdLoader;
    if (guestByIdLoader != null) {
      return guestByIdLoader(guestId);
    }

    final row = await client
        .from('event_guests')
        .select(_eventGuestSelect)
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

      final rows = await client.from('event_guest_tag_assignments').select('''
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
          ''').eq('event_guest_id', guestId).eq('status', 'assigned').limit(1);
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

  Future<List<Map<String, dynamic>>> _loadCoverEntries(String guestId) async {
    final coverEntriesLoader = _coverEntriesLoader;
    if (coverEntriesLoader != null) {
      return coverEntriesLoader(guestId);
    }

    try {
      final result = await client.rpc(
        'list_guest_cover_entries',
        params: {
          'target_event_guest_id': guestId,
        },
      );
      if (result is! List) {
        throw StateError(
          'Expected list_guest_cover_entries to return a list.',
        );
      }

      return result
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList(growable: false);
    } catch (exception) {
      if (!_shouldUseFallback(exception, 'list_guest_cover_entries')) {
        rethrow;
      }

      final rows = await client
          .from('guest_cover_entries')
          .select()
          .eq('event_guest_id', guestId)
          .order('recorded_at', ascending: false);
      return rows
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList(growable: false);
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

    throw StateError(
        'Expected a map row result but received ${value.runtimeType}.');
  }

  bool _shouldUseFallback(Object exception, String functionName) {
    final message = exception.toString().toLowerCase();
    final normalizedFunctionName = functionName.toLowerCase();
    return message.contains(normalizedFunctionName) &&
        (message.contains('could not find') ||
            message.contains('schema cache') ||
            message.contains('404'));
  }

  String _coverEntryMethodName(CoverEntryMethod method) {
    switch (method) {
      case CoverEntryMethod.cash:
        return 'cash';
      case CoverEntryMethod.venmo:
        return 'venmo';
      case CoverEntryMethod.zelle:
        return 'zelle';
      case CoverEntryMethod.other:
        return 'other';
      case CoverEntryMethod.comp:
        return 'comp';
      case CoverEntryMethod.refund:
        return 'refund';
    }
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

    final normalizedUid =
        scannedUid.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '').toUpperCase();
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
      throw StateError(
          'This tag is already assigned to another guest in this event.');
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

    await client.from('event_guest_tag_assignments').update({
      'status': 'replaced',
      'released_at': DateTime.now().toUtc().toIso8601String(),
      'release_reason': 'replacement',
    }).eq('id', currentAssignment.assignmentId);

    await _assignGuestTagFallback(
      guestId: guestId,
      scannedUid: scannedUid,
      displayLabel: displayLabel,
    );
  }
}
