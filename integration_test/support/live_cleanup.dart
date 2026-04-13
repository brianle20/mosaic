import 'live_fixture_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveCleanupOperation {
  const LiveCleanupOperation(this.label);

  final String label;
}

List<LiveCleanupOperation> plannedCleanupOperations(LiveFixtureState state) {
  final operations = <LiveCleanupOperation>[];

  if (state.eventId != null) {
    operations.addAll(const <LiveCleanupOperation>[
      LiveCleanupOperation('guest_cover_entries'),
      LiveCleanupOperation('prize_awards'),
      LiveCleanupOperation('event_guest_tag_assignments'),
      LiveCleanupOperation('table_sessions'),
      LiveCleanupOperation('event_tables'),
      LiveCleanupOperation('event_guests'),
      LiveCleanupOperation('events'),
    ]);
  }

  if (state.normalizedTagUids.isNotEmpty) {
    operations.add(const LiveCleanupOperation('nfc_tags'));
  }

  return operations;
}

Future<void> cleanupLiveFixture(LiveFixtureState state) async {
  final client = Supabase.instance.client;

  if (state.eventId != null) {
    await client
        .from('guest_cover_entries')
        .delete()
        .eq('event_id', state.eventId!);
    await client.from('prize_awards').delete().eq('event_id', state.eventId!);
    await client
        .from('event_guest_tag_assignments')
        .delete()
        .eq('event_id', state.eventId!);
    await client.from('table_sessions').delete().eq('event_id', state.eventId!);
    await client.from('event_tables').delete().eq('event_id', state.eventId!);
    await client.from('event_guests').delete().eq('event_id', state.eventId!);
    await client.from('events').delete().eq('id', state.eventId!);
  } else if (state.eventTitle != null) {
    await client.from('events').delete().eq('title', state.eventTitle!);
  }

  for (final uid in state.normalizedTagUids) {
    await client.from('nfc_tags').delete().eq('uid_hex', uid);
  }
}
