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
    final entries =
        rows.map(GuestCoverEntryRecord.fromJson).toList(growable: false)
          ..sort((left, right) {
            final transactionComparison =
                right.transactionOn.compareTo(left.transactionOn);
            if (transactionComparison != 0) {
              return transactionComparison;
            }
            return (right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                    left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
          });
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

    if (input.instagramHandle case final instagramHandle?) {
      await addMatch(
        await _findProfileByInstagram(
          userId: userId,
          instagramHandle: instagramHandle,
        ),
        GuestProfileMatchType.instagram,
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
    required DateTime transactionOn,
    String? note,
  }) async {
    try {
      await _runRpcSingle(
        'record_cover_entry',
        {
          'target_event_guest_id': guestId,
          'target_amount_cents': amountCents,
          'target_method': _coverEntryMethodName(method),
          'target_transaction_on': _dateToJson(transactionOn),
          'target_note': note,
        },
      );
    } catch (exception) {
      if (!_shouldUseFallback(exception, 'record_cover_entry')) {
        rethrow;
      }

      await _runRpcSingle(
        'record_cover_entry',
        {
          'target_event_guest_id': guestId,
          'target_amount_cents': amountCents,
          'target_method': _coverEntryMethodName(method),
          'target_note': note,
        },
      );
    }

    final detail = await getGuestDetail(guestId);
    if (detail == null) {
      throw StateError('Updated guest could not be reloaded.');
    }

    return detail;
  }

  @override
  Future<GuestDetailRecord> checkInGuest(String guestId) async {
    final row = await _runRpcSingle(
      'check_in_guest',
      {
        'target_event_guest_id': guestId,
      },
    );
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
    await _runRpcSingle(
      'assign_guest_tag',
      {
        'target_event_guest_id': guestId,
        'scanned_uid': scannedUid,
        'scanned_display_label': displayLabel,
      },
    );
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
    await _runRpcSingle(
      'replace_guest_tag',
      {
        'target_event_guest_id': guestId,
        'scanned_uid': scannedUid,
        'scanned_display_label': displayLabel,
      },
    );
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
      instagramHandle: input.instagramHandle,
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

    if (input.guestProfileId case final guestProfileId?) {
      final row = await client
          .from('guest_profiles')
          .select()
          .eq('owner_user_id', userId)
          .eq('id', guestProfileId)
          .single();
      return GuestProfileRecord.fromJson(row);
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
    final instagramProfile = input.instagramHandle == null
        ? null
        : await _findProfileByInstagram(
            userId: userId,
            instagramHandle: input.instagramHandle!,
          );

    final matchedProfiles = [
      phoneProfile,
      emailProfile,
      instagramProfile,
    ].nonNulls.toList(growable: false);
    final matchedProfileIds = {
      for (final profile in matchedProfiles) profile.id,
    };
    if (matchedProfileIds.length > 1) {
      throw StateError(
        'Phone, email, and Instagram match different guest profiles. Review the guest details before saving.',
      );
    }

    final matchedProfile = phoneProfile ?? emailProfile ?? instagramProfile;
    if (matchedProfile != null) {
      return _fillBlankProfileFields(
        profile: matchedProfile,
        phoneE164: input.phoneE164,
        emailLower: input.emailLower,
        instagramHandle: input.instagramHandle,
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
          'instagram_handle': input.instagramHandle,
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

  Future<GuestProfileRecord?> _findProfileByInstagram({
    required String userId,
    required String instagramHandle,
  }) async {
    final row = await client
        .from('guest_profiles')
        .select()
        .eq('owner_user_id', userId)
        .eq('instagram_handle', instagramHandle)
        .maybeSingle();
    final castRow = _castRow(row);
    return castRow == null ? null : GuestProfileRecord.fromJson(castRow);
  }

  Future<GuestProfileRecord> _fillBlankProfileFields({
    required GuestProfileRecord profile,
    required String? phoneE164,
    required String? emailLower,
    required String? instagramHandle,
  }) async {
    final updates = <String, dynamic>{};
    if (profile.phoneE164 == null && phoneE164 != null) {
      updates['phone_e164'] = phoneE164;
    }
    if (profile.emailLower == null && emailLower != null) {
      updates['email_lower'] = emailLower;
    }
    if (profile.instagramHandle == null && instagramHandle != null) {
      updates['instagram_handle'] = instagramHandle;
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
    required String? instagramHandle,
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
    final instagramProfile = instagramHandle == null
        ? null
        : await _findProfileByInstagram(
            userId: userId,
            instagramHandle: instagramHandle,
          );

    if (phoneProfile != null && phoneProfile.id != guestProfileId) {
      throw StateError('Phone is already used by another guest profile.');
    }
    if (emailProfile != null && emailProfile.id != guestProfileId) {
      throw StateError('Email is already used by another guest profile.');
    }
    if (instagramProfile != null && instagramProfile.id != guestProfileId) {
      throw StateError('Instagram is already used by another guest profile.');
    }

    await client.from('guest_profiles').update({
      'display_name': displayName,
      'normalized_name': normalizedName,
      'phone_e164': phoneE164,
      'email_lower': emailLower,
      'instagram_handle': instagramHandle,
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

      late final List rows;
      try {
        rows = await client
            .from('guest_cover_entries')
            .select()
            .eq('event_guest_id', guestId)
            .order('transaction_on', ascending: false)
            .order('created_at', ascending: false);
      } catch (tableException) {
        if (!tableException.toString().contains('transaction_on')) {
          rethrow;
        }
        rows = await client
            .from('guest_cover_entries')
            .select()
            .eq('event_guest_id', guestId)
            .order('recorded_at', ascending: false)
            .order('created_at', ascending: false);
      }
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

  String _dateToJson(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
