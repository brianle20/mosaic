import 'dart:convert';

import 'package:mosaic/data/models/activity_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
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
  static const _guestCoverEntriesKeyPrefix = 'guest-cover-entries:';
  static const _tableListKeyPrefix = 'tables:';
  static const _sessionListKeyPrefix = 'sessions:';
  static const _sessionDetailKeyPrefix = 'session-detail:';
  static const _leaderboardKeyPrefix = 'leaderboard:';
  static const _prizePlanKeyPrefix = 'prize-plan:';
  static const _prizePreviewKeyPrefix = 'prize-preview:';
  static const _prizeAwardsKeyPrefix = 'prize-awards:';
  static const _activityKeyPrefix = 'activity:';

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

  Future<void> saveGuestCoverEntries(
    String guestId,
    List<GuestCoverEntryRecord> entries,
  ) async {
    await _preferences.setString(
      '$_guestCoverEntriesKeyPrefix$guestId',
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  List<GuestCoverEntryRecord> readGuestCoverEntries(String guestId) {
    final raw = _preferences.getString('$_guestCoverEntriesKeyPrefix$guestId');
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) =>
            GuestCoverEntryRecord.fromJson(entry as Map<String, dynamic>))
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
        .map(
            (table) => EventTableRecord.fromJson(table as Map<String, dynamic>))
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

  Future<void> saveSessionDetail(SessionDetailRecord detail) async {
    await _preferences.setString(
      '$_sessionDetailKeyPrefix${detail.session.id}',
      jsonEncode(detail.toJson()),
    );
  }

  SessionDetailRecord? readSessionDetail(String sessionId) {
    final raw = _preferences.getString('$_sessionDetailKeyPrefix$sessionId');
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return SessionDetailRecord.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveLeaderboard(
    String eventId,
    List<LeaderboardEntry> entries,
  ) async {
    await _preferences.setString(
      '$_leaderboardKeyPrefix$eventId',
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  List<LeaderboardEntry> readLeaderboard(String eventId) {
    final raw = _preferences.getString('$_leaderboardKeyPrefix$eventId');
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (entry) => LeaderboardEntry.fromJson(entry as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<void> savePrizePlan(String eventId, PrizePlanDetail detail) async {
    await _preferences.setString(
      '$_prizePlanKeyPrefix$eventId',
      jsonEncode(detail.toJson()),
    );
  }

  PrizePlanDetail? readPrizePlan(String eventId) {
    final raw = _preferences.getString('$_prizePlanKeyPrefix$eventId');
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final planJson = (decoded['plan'] as Map).cast<String, dynamic>();
    final prizeBudgetCents = (planJson['prize_budget_cents'] as num).toInt();
    return PrizePlanDetail.fromJson(decoded,
        prizeBudgetCents: prizeBudgetCents);
  }

  Future<void> savePrizePreview(
    String eventId,
    List<PrizeAwardPreviewRow> preview,
  ) async {
    await _preferences.setString(
      '$_prizePreviewKeyPrefix$eventId',
      jsonEncode(preview.map((row) => row.toJson()).toList(growable: false)),
    );
  }

  List<PrizeAwardPreviewRow> readPrizePreview(String eventId) {
    final raw = _preferences.getString('$_prizePreviewKeyPrefix$eventId');
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((row) =>
            PrizeAwardPreviewRow.fromJson((row as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<void> savePrizeAwards(
    String eventId,
    List<PrizeAwardRecord> awards,
  ) async {
    await _preferences.setString(
      '$_prizeAwardsKeyPrefix$eventId',
      jsonEncode(awards.map((award) => award.toJson()).toList(growable: false)),
    );
  }

  List<PrizeAwardRecord> readPrizeAwards(String eventId) {
    final raw = _preferences.getString('$_prizeAwardsKeyPrefix$eventId');
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((award) =>
            PrizeAwardRecord.fromJson((award as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<void> saveActivity(
    String eventId,
    EventActivityCategory category,
    List<EventActivityEntry> entries,
  ) async {
    await _preferences.setString(
      '$_activityKeyPrefix$eventId:${category.name}',
      jsonEncode(
          entries.map((entry) => entry.toJson()).toList(growable: false)),
    );
  }

  List<EventActivityEntry> readActivity(
    String eventId,
    EventActivityCategory category,
  ) {
    final raw =
        _preferences.getString('$_activityKeyPrefix$eventId:${category.name}');
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) =>
            EventActivityEntry.fromJson((entry as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }
}
