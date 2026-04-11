import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/app/app.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.host});

  HostAuthUser? host;
  final StreamController<HostAuthUser?> controller =
      StreamController<HostAuthUser?>.broadcast();

  @override
  Stream<HostAuthUser?> authStateChanges() => controller.stream;

  @override
  HostAuthUser? get currentHost => host;

  @override
  Future<HostAuthUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    host = HostAuthUser(id: 'usr_01', email: email);
    controller.add(host);
    return host;
  }

  @override
  Future<void> signOut() async {
    host = null;
    controller.add(null);
  }
}

class _FakeEventRepository implements EventRepository {
  _FakeEventRepository(this.events);

  final List<EventRecord> events;

  @override
  Future<EventRecord> createEvent(CreateEventInput input) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord?> getEvent(String eventId) async {
    for (final event in events) {
      if (event.id == eventId) {
        return event;
      }
    }
    return null;
  }

  @override
  Future<List<EventRecord>> listEvents() async => events;

  @override
  Future<List<EventRecord>> readCachedEvents() async => events;
}

class _FakeGuestRepository implements GuestRepository {
  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => const [];

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      const [];

  @override
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('renders host sign in when signed out', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MosaicApp(
          authRepository: _FakeAuthRepository(),
          eventRepository: _FakeEventRepository(const []),
          guestRepository: _FakeGuestRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Host Sign In'), findsOneWidget);
    expect(find.text('Events'), findsNothing);
  });

  testWidgets('renders event list when signed in', (tester) async {
    final authRepository = _FakeAuthRepository(
      host: const HostAuthUser(
        id: 'usr_01',
        email: 'brian.le1678@gmail.com',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MosaicApp(
          authRepository: authRepository,
          eventRepository: _FakeEventRepository([
            EventRecord.fromJson(const {
              'id': 'evt_01',
              'owner_user_id': 'usr_01',
              'title': 'Friday Night Mahjong',
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
          ]),
          guestRepository: _FakeGuestRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Friday Night Mahjong'), findsOneWidget);
    expect(find.text('Host Sign In'), findsNothing);
  });

  testWidgets('returns to host sign in after sign out', (tester) async {
    final authRepository = _FakeAuthRepository(
      host: const HostAuthUser(
        id: 'usr_01',
        email: 'brian.le1678@gmail.com',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MosaicApp(
          authRepository: authRepository,
          eventRepository: _FakeEventRepository([
            EventRecord.fromJson(const {
              'id': 'evt_01',
              'owner_user_id': 'usr_01',
              'title': 'Friday Night Mahjong',
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
          ]),
          guestRepository: _FakeGuestRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Host Sign In'), findsOneWidget);
    expect(find.text('Events'), findsNothing);
  });
}
