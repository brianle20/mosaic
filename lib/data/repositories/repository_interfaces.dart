import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/ruleset_models.dart';
import 'package:mosaic/data/models/session_models.dart';

abstract interface class EventRepository {
  Future<List<EventRecord>> listEvents();

  Future<EventRecord> createEvent(EventRecord event);
}

abstract interface class GuestRepository {
  Future<List<EventGuestRecord>> listGuests(String eventId);

  Future<EventGuestRecord> upsertGuest(EventGuestRecord guest);
}

abstract interface class RulesetRepository {
  Future<List<RulesetRecord>> listRulesets();
}

abstract interface class SessionRepository {
  Future<List<TableSessionRecord>> listSessions(String eventId);
}

abstract interface class PrizeRepository {
  Future<PrizePlanRecord?> loadPrizePlan({
    required String eventId,
    required int prizeBudgetCents,
  });
}
