import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String> lookupEventIdByTitle(String eventTitle) async {
  final row = await Supabase.instance.client
      .from('events')
      .select('id')
      .eq('title', eventTitle)
      .maybeSingle();
  expect(row, isNotNull);
  return row!['id'] as String;
}

Future<List<Map<String, dynamic>>> loadGuestRows(String eventId) async {
  return (await Supabase.instance.client
          .from('event_guests')
          .select('id, display_name, attendance_status, cover_status')
          .eq('event_id', eventId)
          .order('display_name', ascending: true))
      .cast<Map<String, dynamic>>();
}

Future<String> lookupSessionId(String eventId, String tableId) async {
  final rows = await Supabase.instance.client
      .from('table_sessions')
      .select('id, status')
      .eq('event_id', eventId)
      .eq('event_table_id', tableId);
  expect(rows, hasLength(1));
  return rows.single['id'] as String;
}

Future<List<dynamic>> loadLeaderboard(String eventId) async {
  return await Supabase.instance.client.rpc(
    'get_event_leaderboard',
    params: {'target_event_id': eventId},
  ) as List<dynamic>;
}

Future<void> assertNoRowsExistForEvent(String eventId) async {
  final client = Supabase.instance.client;

  final coverEntries = await client
      .from('guest_cover_entries')
      .select('event_id')
      .eq('event_id', eventId);
  final prizeAwards = await client
      .from('prize_awards')
      .select('event_id')
      .eq('event_id', eventId);
  final guestAssignments = await client
      .from('event_guest_tag_assignments')
      .select('event_id')
      .eq('event_id', eventId);
  final sessions = await client
      .from('table_sessions')
      .select('event_id')
      .eq('event_id', eventId);
  final tables = await client
      .from('event_tables')
      .select('event_id')
      .eq('event_id', eventId);
  final guests = await client
      .from('event_guests')
      .select('event_id')
      .eq('event_id', eventId);
  final events = await client.from('events').select('id').eq('id', eventId);

  expect(coverEntries, isEmpty);
  expect(prizeAwards, isEmpty);
  expect(guestAssignments, isEmpty);
  expect(sessions, isEmpty);
  expect(tables, isEmpty);
  expect(guests, isEmpty);
  expect(events, isEmpty);
}
