import 'dart:convert';

import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  LocalCache(this._preferences);

  final SharedPreferences _preferences;

  static Future<LocalCache> create() async {
    final preferences = await SharedPreferences.getInstance();
    return LocalCache(preferences);
  }

  static const _eventsKey = 'events';
  static const _eventKeyPrefix = 'event:';
  static const _guestListKeyPrefix = 'guests:';
  static const _tableListKeyPrefix = 'tables:';
  static const _sessionListKeyPrefix = 'sessions:';

  Future<void> saveEvents(List<EventRecord> events) async {
    await _preferences.setString(
      _eventsKey,
      jsonEncode(events.map((event) => event.toJson()).toList()),
    );
  }

  List<EventRecord> readEvents() {
    final raw = _preferences.getString(_eventsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((event) => EventRecord.fromJson(event as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveEvent(EventRecord event) async {
    await _preferences.setString(
      '$_eventKeyPrefix${event.id}',
      jsonEncode(event.toJson()),
    );
  }

  EventRecord? readEvent(String eventId) {
    final raw = _preferences.getString('$_eventKeyPrefix$eventId');
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return EventRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveGuests(String eventId, List<EventGuestRecord> guests) async {
    await _preferences.setString(
      '$_guestListKeyPrefix$eventId',
      jsonEncode(guests.map((guest) => guest.toJson()).toList()),
    );
  }

  List<EventGuestRecord> readGuests(String eventId) {
    final raw = _preferences.getString('$_guestListKeyPrefix$eventId');
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
            (guest) => EventGuestRecord.fromJson(guest as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveTables(String eventId, List<EventTableRecord> tables) async {
    await _preferences.setString(
      '$_tableListKeyPrefix$eventId',
      jsonEncode(tables.map((table) => table.toJson()).toList()),
    );
  }

  List<EventTableRecord> readTables(String eventId) {
    final raw = _preferences.getString('$_tableListKeyPrefix$eventId');
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((table) => EventTableRecord.fromJson(table as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveSessions(
    String eventId,
    List<TableSessionRecord> sessions,
  ) async {
    await _preferences.setString(
      '$_sessionListKeyPrefix$eventId',
      jsonEncode(sessions.map((session) => session.toJson()).toList()),
    );
  }

  List<TableSessionRecord> readSessions(String eventId) {
    final raw = _preferences.getString('$_sessionListKeyPrefix$eventId');
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (session) =>
              TableSessionRecord.fromJson(session as Map<String, dynamic>),
        )
        .toList(growable: false);
  }
}
