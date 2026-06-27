import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/supabase_guest_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseGuestRepository tournament fields', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('creating a guest writes generated public names and selected status',
        () async {
      final cache = await LocalCache.create();
      late Map<String, dynamic> capturedProfileInsert;
      late Map<String, dynamic> capturedEventGuestInsert;
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        currentUserIdReader: () => 'usr_01',
        guestProfilesByNameLoader: (_, __) async => const [],
        profileOnEventChecker: ({
          required eventId,
          required guestProfileId,
        }) async {
          expect(eventId, 'evt_01');
          expect(guestProfileId, 'prf_01');
        },
        guestProfileInsertRunner: (json) async {
          capturedProfileInsert = json;
          return {
            'id': 'prf_01',
            ...json,
            'row_version': 1,
          };
        },
        eventGuestInsertRunner: (json) async {
          capturedEventGuestInsert = json;
          return {
            'id': 'gst_01',
            ...json,
            'attendance_status': 'expected',
            'cover_status': 'paid',
            'cover_amount_cents': 2000,
            'is_comped': false,
            'has_scored_play': false,
            'guest_profile': {
              'id': 'prf_01',
              'owner_user_id': 'usr_01',
              'display_name': 'Brian Le',
              'normalized_name': 'brian le',
              'public_display_name': 'Brian L.',
            },
          };
        },
      );

      final guest = await repository.createGuest(
        const CreateGuestInput(
          eventId: 'evt_01',
          displayName: 'Brian Le',
          normalizedName: 'brian le',
          coverStatus: CoverStatus.paid,
          coverAmountCents: 2000,
          isComped: false,
          tournamentStatus: EventTournamentStatus.qualifying,
        ),
      );

      expect(capturedProfileInsert['display_name'], 'Brian Le');
      expect(capturedProfileInsert['public_display_name'], 'Brian L.');
      expect(capturedEventGuestInsert['display_name'], 'Brian Le');
      expect(capturedEventGuestInsert['public_display_name'], 'Brian L.');
      expect(capturedEventGuestInsert['tournament_status'], 'qualifying');
      expect(guest.publicDisplayName, 'Brian L.');
      expect(guest.tournamentStatus, EventTournamentStatus.qualifying);
    });

    test('creating a guest preserves an explicit public display name',
        () async {
      final cache = await LocalCache.create();
      late Map<String, dynamic> capturedProfileInsert;
      late Map<String, dynamic> capturedEventGuestInsert;
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        currentUserIdReader: () => 'usr_01',
        guestProfilesByNameLoader: (_, __) async => const [],
        profileOnEventChecker: ({
          required eventId,
          required guestProfileId,
        }) async {},
        guestProfileInsertRunner: (json) async {
          capturedProfileInsert = json;
          return {
            'id': 'prf_02',
            ...json,
            'row_version': 1,
          };
        },
        eventGuestInsertRunner: (json) async {
          capturedEventGuestInsert = json;
          return {
            'id': 'gst_02',
            ...json,
            'attendance_status': 'expected',
            'cover_status': 'paid',
            'cover_amount_cents': 2000,
            'is_comped': false,
            'has_scored_play': false,
          };
        },
      );

      await repository.createGuest(
        const CreateGuestInput(
          eventId: 'evt_01',
          displayName: 'Alice Wong Chen',
          normalizedName: 'alice wong chen',
          publicDisplayName: 'Tournament Alice',
          coverStatus: CoverStatus.paid,
          coverAmountCents: 2000,
          isComped: false,
        ),
      );

      expect(
        capturedProfileInsert['public_display_name'],
        'Tournament Alice',
      );
      expect(
        capturedEventGuestInsert['public_display_name'],
        'Tournament Alice',
      );
    });

    test('creating a guest writes contact fields to profile but not event row',
        () async {
      final server = await _FakeGuestPostgrestServer.start();
      addTearDown(server.close);
      final cache = await LocalCache.create();
      late Map<String, dynamic> capturedProfileInsert;
      late Map<String, dynamic> capturedEventGuestInsert;
      final repository = SupabaseGuestRepository(
        client: SupabaseClient(server.url, 'publishable-key'),
        cache: cache,
        currentUserIdReader: () => 'usr_01',
        profileOnEventChecker: ({
          required eventId,
          required guestProfileId,
        }) async {},
        guestProfileInsertRunner: (json) async {
          capturedProfileInsert = json;
          return {
            'id': 'prf_contact',
            ...json,
            'row_version': 1,
          };
        },
        eventGuestInsertRunner: (json) async {
          capturedEventGuestInsert = json;
          return {
            'id': 'gst_contact',
            ...json,
            'attendance_status': 'expected',
            'cover_status': 'paid',
            'cover_amount_cents': 2000,
            'is_comped': false,
            'has_scored_play': false,
            'guest_profile': const {
              'id': 'prf_contact',
              'owner_user_id': 'usr_01',
              'display_name': 'Contact Guest',
              'normalized_name': 'contact guest',
              'public_display_name': 'Contact G.',
              'phone_e164': '+14155552671',
              'email_lower': 'contact@example.com',
            },
          };
        },
      );

      await repository.createGuest(
        const CreateGuestInput(
          eventId: 'evt_01',
          displayName: 'Contact Guest',
          normalizedName: 'contact guest',
          phoneE164: '+14155552671',
          emailLower: 'contact@example.com',
          coverStatus: CoverStatus.paid,
          coverAmountCents: 2000,
          isComped: false,
        ),
      );

      expect(capturedProfileInsert['phone_e164'], '+14155552671');
      expect(capturedProfileInsert['email_lower'], 'contact@example.com');
      expect(capturedEventGuestInsert, isNot(contains('phone_e164')));
      expect(capturedEventGuestInsert, isNot(contains('email_lower')));
    });

    test('returned guest keeps event public name over profile default',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        currentUserIdReader: () => 'usr_01',
        guestProfilesByNameLoader: (_, __) async => const [],
        profileOnEventChecker: ({
          required eventId,
          required guestProfileId,
        }) async {},
        guestProfileInsertRunner: (json) async {
          return {
            'id': 'prf_gus',
            ...json,
            'public_display_name': 'Agustin F.',
            'row_version': 1,
          };
        },
        eventGuestInsertRunner: (json) async {
          return {
            'id': 'gst_gus',
            ...json,
            'public_display_name': 'Gus',
            'attendance_status': 'expected',
            'cover_status': 'paid',
            'cover_amount_cents': 2000,
            'is_comped': false,
            'has_scored_play': false,
            'guest_profile': const {
              'id': 'prf_gus',
              'owner_user_id': 'usr_01',
              'display_name': 'Agustin Feliciano',
              'normalized_name': 'agustin feliciano',
              'public_display_name': 'Agustin F.',
            },
          };
        },
      );

      final guest = await repository.createGuest(
        const CreateGuestInput(
          eventId: 'evt_01',
          displayName: 'Agustin Feliciano',
          normalizedName: 'agustin feliciano',
          publicDisplayName: 'Gus',
          coverStatus: CoverStatus.paid,
          coverAmountCents: 2000,
          isComped: false,
        ),
      );

      expect(guest.publicDisplayName, 'Gus');
      expect(guest.publicName, 'Gus');
    });

    test('generated public names collapse extra spaces and use final initial',
        () async {
      final cache = await LocalCache.create();
      late Map<String, dynamic> capturedProfileInsert;
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        currentUserIdReader: () => 'usr_01',
        guestProfilesByNameLoader: (_, __) async => const [],
        profileOnEventChecker: ({
          required eventId,
          required guestProfileId,
        }) async {},
        guestProfileInsertRunner: (json) async {
          capturedProfileInsert = json;
          return {
            'id': 'prf_03',
            ...json,
            'row_version': 1,
          };
        },
        eventGuestInsertRunner: (json) async {
          return {
            'id': 'gst_03',
            ...json,
            'attendance_status': 'expected',
            'cover_status': 'paid',
            'cover_amount_cents': 2000,
            'is_comped': false,
            'has_scored_play': false,
          };
        },
      );

      await repository.createGuest(
        const CreateGuestInput(
          eventId: 'evt_01',
          displayName: '  Alice   Wong Chen  ',
          normalizedName: 'alice wong chen',
          coverStatus: CoverStatus.paid,
          coverAmountCents: 2000,
          isComped: false,
        ),
      );

      expect(capturedProfileInsert['public_display_name'], 'Alice C.');
    });

    test('creating a name-only guest reuses one matching saved profile',
        () async {
      final server = await _FakeGuestPostgrestServer.start(
        guestProfileRows: [
          _guestProfileRow(
            id: 'prf_alice',
            ownerUserId: 'usr_01',
            displayName: 'Alice Wong',
            normalizedName: 'alice wong',
            publicDisplayName: 'Alice W.',
          ),
        ],
      );
      addTearDown(server.close);
      final cache = await LocalCache.create();
      var insertedProfile = false;
      late Map<String, dynamic> capturedEventGuestInsert;
      final repository = SupabaseGuestRepository(
        client: SupabaseClient(server.url, 'publishable-key'),
        cache: cache,
        currentUserIdReader: () => 'usr_01',
        profileOnEventChecker: ({
          required eventId,
          required guestProfileId,
        }) async {
          expect(eventId, 'evt_01');
          expect(guestProfileId, 'prf_alice');
        },
        guestProfileInsertRunner: (json) async {
          insertedProfile = true;
          return {
            'id': 'prf_new',
            ...json,
            'row_version': 1,
          };
        },
        eventGuestInsertRunner: (json) async {
          capturedEventGuestInsert = json;
          return {
            'id': 'gst_alice',
            ...json,
            'attendance_status': 'expected',
            'cover_status': 'paid',
            'cover_amount_cents': 2000,
            'is_comped': false,
            'has_scored_play': false,
            'guest_profile': _guestProfileRow(
              id: 'prf_alice',
              ownerUserId: 'usr_01',
              displayName: 'Alice Wong',
              normalizedName: 'alice wong',
              publicDisplayName: 'Alice W.',
            ),
          };
        },
      );

      await repository.createGuest(
        const CreateGuestInput(
          eventId: 'evt_01',
          displayName: 'Alice Wong',
          normalizedName: 'alice wong',
          coverStatus: CoverStatus.paid,
          coverAmountCents: 2000,
          isComped: false,
        ),
      );

      expect(insertedProfile, isFalse);
      expect(capturedEventGuestInsert['guest_profile_id'], 'prf_alice');
    });

    test(
        'creating a name-only guest inserts when saved profile match is ambiguous',
        () async {
      final server = await _FakeGuestPostgrestServer.start(
        guestProfileRows: [
          _guestProfileRow(
            id: 'prf_alice_1',
            ownerUserId: 'usr_01',
            displayName: 'Alice Wong',
            normalizedName: 'alice wong',
            publicDisplayName: 'Alice W.',
          ),
          _guestProfileRow(
            id: 'prf_alice_2',
            ownerUserId: 'usr_01',
            displayName: 'Alice Wong',
            normalizedName: 'alice wong',
            publicDisplayName: 'Alice W.',
          ),
        ],
      );
      addTearDown(server.close);
      final cache = await LocalCache.create();
      late Map<String, dynamic> capturedProfileInsert;
      late Map<String, dynamic> capturedEventGuestInsert;
      final repository = SupabaseGuestRepository(
        client: SupabaseClient(server.url, 'publishable-key'),
        cache: cache,
        currentUserIdReader: () => 'usr_01',
        profileOnEventChecker: ({
          required eventId,
          required guestProfileId,
        }) async {
          expect(eventId, 'evt_01');
          expect(guestProfileId, 'prf_new');
        },
        guestProfileInsertRunner: (json) async {
          capturedProfileInsert = json;
          return {
            'id': 'prf_new',
            ...json,
            'row_version': 1,
          };
        },
        eventGuestInsertRunner: (json) async {
          capturedEventGuestInsert = json;
          return {
            'id': 'gst_alice',
            ...json,
            'attendance_status': 'expected',
            'cover_status': 'paid',
            'cover_amount_cents': 2000,
            'is_comped': false,
            'has_scored_play': false,
            'guest_profile': _guestProfileRow(
              id: 'prf_new',
              ownerUserId: 'usr_01',
              displayName: 'Alice Wong',
              normalizedName: 'alice wong',
            ),
          };
        },
      );

      await repository.createGuest(
        const CreateGuestInput(
          eventId: 'evt_01',
          displayName: 'Alice Wong',
          normalizedName: 'alice wong',
          coverStatus: CoverStatus.paid,
          coverAmountCents: 2000,
          isComped: false,
        ),
      );

      expect(capturedProfileInsert['normalized_name'], 'alice wong');
      expect(capturedEventGuestInsert['guest_profile_id'], 'prf_new');
    });

    test('updating a guest writes contact fields to profile but not event row',
        () async {
      final server = await _FakeGuestPostgrestServer.start();
      addTearDown(server.close);
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient(server.url, 'publishable-key'),
        cache: cache,
        currentUserIdReader: () => 'usr_01',
        guestByIdLoader: (guestId) async => _guestRow(
          id: guestId,
          guestProfileId: 'prf_contact',
        ),
      );

      await repository.updateGuest(
        const UpdateGuestInput(
          id: 'gst_contact',
          eventId: 'evt_01',
          displayName: 'Contact Guest',
          normalizedName: 'contact guest',
          phoneE164: '+14155552671',
          emailLower: 'contact@example.com',
          coverStatus: CoverStatus.paid,
          coverAmountCents: 2000,
          isComped: false,
        ),
      );

      expect(
        server.lastJsonBodyFor('guest_profiles')['phone_e164'],
        '+14155552671',
      );
      expect(
        server.lastJsonBodyFor('guest_profiles')['email_lower'],
        'contact@example.com',
      );
      expect(
        server.lastJsonBodyFor('event_guests'),
        isNot(contains('phone_e164')),
      );
      expect(
        server.lastJsonBodyFor('event_guests'),
        isNot(contains('email_lower')),
      );
    });

    test('updating tournament status targets the event guest row', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'update_event_guest_tournament_status');
          expect(params, {
            'target_event_guest_id': 'gst_01',
            'target_tournament_status': 'qualifying',
          });
          return _guestRow(
            id: 'gst_01',
            tournamentStatus: 'qualifying',
          );
        },
      );

      final guest = await repository.updateEventGuestTournamentStatus(
        eventGuestId: 'gst_01',
        status: EventTournamentStatus.qualifying,
      );

      expect(guest.id, 'gst_01');
      expect(guest.tournamentStatus, EventTournamentStatus.qualifying);
    });

    test('marking qualified does not require qualification hands', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'update_event_guest_tournament_status');
          expect(params['target_event_guest_id'], 'gst_02');
          expect(params['target_tournament_status'], 'qualified');
          return _guestRow(
            id: 'gst_02',
            tournamentStatus: 'qualified',
          );
        },
      );

      final guest = await repository.updateEventGuestTournamentStatus(
        eventGuestId: 'gst_02',
        status: EventTournamentStatus.qualified,
      );

      expect(guest.tournamentStatus, EventTournamentStatus.qualified);
    });

    test('removeGuest deletes through RPC and removes cached row', () async {
      final cache = await LocalCache.create();
      await cache.saveGuests('evt_01', [
        EventGuestRecord.fromJson({
          ..._guestRow(id: 'gst_01'),
          'display_name': 'Alice Wong',
          'normalized_name': 'alice wong',
        }),
        EventGuestRecord.fromJson({
          ..._guestRow(id: 'gst_02'),
          'display_name': 'Bob Lee',
          'normalized_name': 'bob lee',
        }),
      ]);
      final repository = SupabaseGuestRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'remove_event_guest');
          expect(params, {'target_event_guest_id': 'gst_01'});
          return _guestRow(id: 'gst_01');
        },
      );

      await repository.removeGuest('gst_01');

      final cachedGuests = cache.readGuests('evt_01');
      expect(cachedGuests.map((guest) => guest.id), ['gst_02']);
    });

    test('undoGuestCheckIn only targets guests with no scored play', () async {
      final server = await _FakeGuestPostgrestServer.start();
      addTearDown(server.close);
      final cache = await LocalCache.create();
      final repository = SupabaseGuestRepository(
        client: SupabaseClient(server.url, 'publishable-key'),
        cache: cache,
      );

      await repository.undoGuestCheckIn('gst_undo');

      final query = server.lastQueryFor('event_guests');
      expect(query['id'], ['eq.gst_undo']);
      expect(query['has_scored_play'], ['eq.false']);
      expect(query['select']?.single, contains('guest_profile'));
      expect(server.lastJsonBodyFor('event_guests'), {
        'attendance_status': 'expected',
        'checked_in_at': null,
      });
    });

    group('saved guest profiles', () {
      test('lists profiles scoped to the current host', () async {
        final cache = await LocalCache.create();
        String? capturedOwnerUserId;
        final repository = SupabaseGuestRepository(
          client: SupabaseClient('https://example.com', 'publishable-key'),
          cache: cache,
          currentUserIdReader: () => 'usr_01',
          guestProfilesLoader: (ownerUserId) async {
            capturedOwnerUserId = ownerUserId;
            return [
              _guestProfileRow(
                id: 'prf_alice',
                ownerUserId: ownerUserId,
                displayName: 'Alice Wong',
                normalizedName: 'alice wong',
                publicDisplayName: 'Alice W.',
              ),
              _guestProfileRow(
                id: 'prf_brian',
                ownerUserId: ownerUserId,
                displayName: 'Brian Le',
                normalizedName: 'brian le',
              ),
            ];
          },
        );

        final profiles = await repository.listGuestProfiles();

        expect(capturedOwnerUserId, 'usr_01');
        expect(
          profiles.map((profile) => profile.id),
          ['prf_alice', 'prf_brian'],
        );
        expect(profiles.first.displayName, 'Alice Wong');
        expect(profiles.first.publicDisplayName, 'Alice W.');
        expect(profiles.last.ownerUserId, 'usr_01');
      });

      test('returns an empty list when there is no current user', () async {
        final cache = await LocalCache.create();
        var loaderCalled = false;
        final repository = SupabaseGuestRepository(
          client: SupabaseClient('https://example.com', 'publishable-key'),
          cache: cache,
          currentUserIdReader: () => null,
          guestProfilesLoader: (_) async {
            loaderCalled = true;
            return [
              _guestProfileRow(
                id: 'prf_alice',
                ownerUserId: 'usr_01',
                displayName: 'Alice Wong',
                normalizedName: 'alice wong',
              ),
            ];
          },
        );

        final profiles = await repository.listGuestProfiles();

        expect(profiles, isEmpty);
        expect(loaderCalled, isFalse);
      });
    });
  });
}

Map<String, dynamic> _guestRow({
  required String id,
  String guestProfileId = 'prf_01',
  String tournamentStatus = 'open_play_only',
}) {
  return {
    'id': id,
    'event_id': 'evt_01',
    'guest_profile_id': guestProfileId,
    'display_name': 'Brian Le',
    'normalized_name': 'brian le',
    'public_display_name': 'Brian L.',
    'tournament_status': tournamentStatus,
    'attendance_status': 'checked_in',
    'cover_status': 'paid',
    'cover_amount_cents': 2000,
    'is_comped': false,
    'has_scored_play': false,
  };
}

Map<String, dynamic> _guestProfileRow({
  required String id,
  required String ownerUserId,
  required String displayName,
  required String normalizedName,
  String? publicDisplayName,
}) {
  return {
    'id': id,
    'owner_user_id': ownerUserId,
    'display_name': displayName,
    'normalized_name': normalizedName,
    'public_display_name': publicDisplayName,
    'row_version': 1,
  };
}

class _FakeGuestPostgrestServer {
  _FakeGuestPostgrestServer._(
    this._server, {
    required List<Map<String, dynamic>> guestProfileRows,
  }) : _guestProfileRows = guestProfileRows;

  final HttpServer _server;
  final List<Map<String, dynamic>> _guestProfileRows;
  final _jsonBodiesByTable = <String, List<Map<String, dynamic>>>{};
  final _queriesByTable = <String, List<Map<String, List<String>>>>{};

  String get url => 'http://${_server.address.host}:${_server.port}';

  static Future<_FakeGuestPostgrestServer> start({
    List<Map<String, dynamic>> guestProfileRows = const [],
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeGuestPostgrestServer._(
      server,
      guestProfileRows: guestProfileRows,
    );
    server.listen(fake._handleRequest);
    return fake;
  }

  Map<String, dynamic> lastJsonBodyFor(String table) {
    final bodies = _jsonBodiesByTable[table];
    if (bodies == null || bodies.isEmpty) {
      throw StateError('No JSON body captured for $table.');
    }
    return bodies.last;
  }

  Map<String, List<String>> lastQueryFor(String table) {
    final queries = _queriesByTable[table];
    if (queries == null || queries.isEmpty) {
      throw StateError('No query captured for $table.');
    }
    return queries.last;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handleRequest(HttpRequest request) async {
    final table = request.uri.pathSegments.last;
    _queriesByTable
        .putIfAbsent(table, () => [])
        .add(request.uri.queryParametersAll);

    if (request.method == 'PATCH' || request.method == 'POST') {
      final body = await utf8.decoder.bind(request).join();
      if (body.isNotEmpty) {
        _jsonBodiesByTable
            .putIfAbsent(table, () => [])
            .add((jsonDecode(body) as Map).cast<String, dynamic>());
      }
    }

    final responseBody = switch ((request.method, table)) {
      ('GET', 'guest_profiles') => _guestProfileRows,
      ('PATCH', 'guest_profiles') => <String, dynamic>{},
      ('PATCH', 'event_guests') => {
          ..._guestRow(
            id: 'gst_contact',
            guestProfileId: 'prf_contact',
          ),
          'display_name': 'Contact Guest',
          'normalized_name': 'contact guest',
          'public_display_name': 'Contact G.',
          'attendance_status': 'expected',
          'guest_profile': const {
            'id': 'prf_contact',
            'owner_user_id': 'usr_01',
            'display_name': 'Contact Guest',
            'normalized_name': 'contact guest',
            'public_display_name': 'Contact G.',
            'phone_e164': '+14155552671',
            'email_lower': 'contact@example.com',
          },
        },
      _ => <String, dynamic>{},
    };

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(responseBody));
    await request.response.close();
  }
}
