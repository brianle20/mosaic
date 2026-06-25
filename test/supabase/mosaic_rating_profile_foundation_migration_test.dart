import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final files = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) =>
            file.path.endsWith('_mosaic_rating_profile_foundation.sql'))
        .toList();

    expect(files, hasLength(1));
    migration = files.single.readAsStringSync();
  });

  test('creates cross-event player and evidence tables', () {
    expect(migration, contains('create table if not exists public.players'));
    expect(migration, contains('alter table public.event_guests'));
    expect(migration, contains('player_id uuid references public.players(id)'));
    expect(
        migration, contains('create table if not exists public.hand_photos'));
    expect(migration,
        contains('create table if not exists public.hand_tile_entries'));
    expect(migration,
        contains('create table if not exists public.rating_snapshots'));
    expect(migration,
        contains('create table if not exists public.profile_snapshots'));
  });

  test('hand photos are host admin only and track upload state', () {
    expect(migration, contains("photo_capture_status text not null"));
    expect(migration, contains("photo_upload_status text not null"));
    expect(migration,
        contains("visibility text not null default 'host_admin_only'"));
    expect(migration, contains('hand_photos_visibility_check'));
    expect(migration, contains('hand_photos_upload_status_check'));
    expect(migration, contains('enable row level security'));
    expect(migration, contains('hand_photos_host_admin_select'));
  });

  test('tile entries store calculated fan separately from declared fan', () {
    expect(migration, contains('calculated_fan_count integer'));
    expect(migration, contains('fan_delta integer generated always as'));
    expect(migration, contains('review_status text not null'));
    expect(migration, contains('calculation_version text not null'));
  });

  test('rating and profile snapshots preserve provenance', () {
    expect(migration, contains('source_quality text not null'));
    expect(migration, contains('inputs_version text not null'));
    expect(migration, contains('rating_before integer'));
    expect(migration, contains('rating_after integer not null'));
    expect(migration, contains('tile_derived_confidence text not null'));
  });

  test('adds admin review and snapshot RPCs', () {
    expect(migration, contains('public.list_hand_evidence_review'));
    expect(migration, contains('public.upsert_hand_tile_entry'));
    expect(migration, contains('public.get_player_mosaic_profile'));
    expect(migration, contains('app_private.refresh_mosaic_player_snapshots'));
  });

  test('public profile RPC gates and sanitizes snapshot payloads', () {
    expect(migration, contains('player.public_profile_slug is not null'));
    expect(migration, contains("'ratingAfter'"));
    expect(migration, contains("'ratingDelta'"));
    expect(migration, contains("'provisionalState'"));
    expect(migration, contains("'styleArchetype'"));
    expect(migration, contains("'tileDerivedConfidence'"));
    expect(migration, isNot(contains('select to_jsonb(rating)')));
    expect(migration, isNot(contains('select to_jsonb(profile)')));
    expect(migration,
        isNot(contains("to_jsonb(profile) - 'private_review_json'")));
    expect(migration, isNot(contains("'sourceQuality'")));
    expect(migration, isNot(contains("'generatedFromOfficialDataThrough'")));
    expect(migration, isNot(contains("'generatedFromTileDataThrough'")));
  });

  test('tile entry upsert authorizes hand lookup before not-found checks', () {
    expect(
      migration,
      contains('''
  select hand_result.*
  into hand_row
  from public.hand_results as hand_result
  join public.table_sessions as session
    on session.id = hand_result.table_session_id
  where hand_result.id = target_hand_result_id
    and app_private.can_manage_event(session.event_id);'''),
    );
    expect(
      migration,
      isNot(contains("raise exception 'Hand result not found.'")),
    );
    expect(
      migration,
      contains("raise exception 'Hand result not found for current host.'"),
    );
  });

  test('record hand RPC requires and stores win photo metadata', () {
    expect(migration, contains('target_photo_client_id uuid default null'));
    expect(migration,
        contains('target_photo_captured_at timestamptz default null'));
    expect(migration,
        contains("raise exception 'Winning hand photo is required.'"));
    expect(
      migration,
      contains(
          "raise exception 'Only winning hands can include photo metadata.'"),
    );
    expect(migration, contains('insert into public.hand_photos'));
    expect(migration, contains('target_photo_client_id'));
    expect(migration, contains('target_photo_captured_at'));
  });

  test('record hand photo RPC updates pending photo row as host admin only',
      () {
    expect(migration, contains('public.record_hand_photo'));
    expect(migration, contains('target_hand_result_id uuid'));
    expect(migration, contains('target_client_photo_id uuid'));
    expect(
      migration,
      contains(
          'and app_private.can_score_session(hand_result.table_session_id)'),
    );
    expect(migration, contains("visibility = 'host_admin_only'"));
    expect(migration, contains("photo_upload_status = 'pending'"));
    expect(migration, contains("photo_upload_status = 'uploaded'"));
    expect(migration, contains("target_storage_bucket <> 'hand-photos'"));
    expect(migration, contains("'events/' || event_id::text"));
    expect(
      migration,
      contains("raise exception 'Invalid hand photo storage path.'"),
    );
    expect(migration, contains('storage_bucket = target_storage_bucket'));
    expect(migration, contains('storage_path = target_storage_path'));
  });

  test('hand photo storage bucket stays private with host admin policies', () {
    expect(migration, contains("values ('hand-photos', 'hand-photos', false"));
    expect(migration, contains('set public = false'));
    expect(migration, contains('hand_photos_host_admin_storage_insert'));
    expect(migration, contains('hand_photos_host_admin_storage_update'));
    expect(migration, contains('hand_photos_host_admin_storage_select'));
    expect(migration, contains('app_private.can_score_tournament'));
    expect(migration, contains('app_private.can_score_bonus'));
    expect(migration, isNot(contains('for select to anon')));
  });
}
