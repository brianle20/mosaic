import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/'
      '20260627190000_mosaic_snapshot_refresh_guardrail.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
  });

  test('adds targeted Mosaic snapshot refresh for event players', () {
    final helperBody = _functionBody(
      migration,
      'app_private.refresh_mosaic_player_snapshots_for_event',
    );

    _expectOrdered(helperBody, [
      'event_row public.events%rowtype',
      'select *',
      'into event_row',
      'from public.events',
      'where id = target_event_id',
      'if event_row.id is null',
      'lower(event_row.title) not in',
      "'fv mahjong 1'",
      "'fv mahjong 2'",
      "'south wind 3'",
      'for player_row in',
      'select distinct guest.player_id',
      'from public.event_guests as guest',
      'where guest.event_id = target_event_id',
      'and guest.player_id is not null',
      'perform app_private.refresh_mosaic_player_snapshots(player_row.player_id);',
    ]);
  });

  test('latest score total refresh refreshes Mosaic snapshots after standings',
      () {
    final refreshBody = _latestFunctionBody(
      'app_private.refresh_event_score_totals',
    );

    _expectOrdered(refreshBody, [
      'insert into public.event_score_totals',
      'perform app_private.refresh_event_guest_scored_play(target_event_id);',
      'perform app_private.refresh_public_event_standings_snapshot(target_event_id);',
      'perform app_private.refresh_mosaic_player_snapshots_for_event(target_event_id);',
    ]);
  });

  test('latest score total refresh serializes per event', () {
    final refreshBody = _latestFunctionBody(
      'app_private.refresh_event_score_totals',
    );

    _expectOrdered(refreshBody, [
      'perform pg_advisory_xact_lock(',
      'hashtextextended(target_event_id::text, 0)',
      'delete from public.event_score_totals',
      'insert into public.event_score_totals',
    ]);
  });

  test('bridge mutation helper refreshes affected players and realigns guests',
      () {
    final helperBody = _functionBody(
      migration,
      'app_private.refresh_mosaic_player_snapshots_for_bridge_change',
    );

    expect(helperBody, contains('old.player_id'));
    expect(helperBody, contains('new.player_id'));
    expect(
      helperBody,
      contains('app_private.refresh_mosaic_player_snapshots(old.player_id)'),
    );
    expect(
      helperBody,
      contains('app_private.refresh_mosaic_player_snapshots(new.player_id)'),
    );
    _expectOrdered(helperBody, [
      "new.status = 'active'",
      'update public.event_guests as guest',
      'set player_id = new.player_id',
      'from public.events as event,',
      'public.guest_profiles as profile',
      'guest.guest_profile_id = new.guest_profile_id',
      'profile.owner_user_id = event.owner_user_id',
      'new.owner_user_id = event.owner_user_id',
      'guest.player_id is distinct from new.player_id',
      'app_private.refresh_mosaic_player_snapshots(old.player_id)',
      'app_private.refresh_mosaic_player_snapshots(new.player_id)',
    ]);
  });

  test('bridge helper refreshes snapshots after active bridge realignment', () {
    final helperBody = _functionBody(
      migration,
      'app_private.refresh_mosaic_player_snapshots_for_bridge_change',
    );

    _expectOrdered(helperBody, [
      "new.status = 'active'",
      'update public.event_guests as guest',
      'set player_id = new.player_id',
      'guest.player_id is distinct from new.player_id',
      'perform app_private.refresh_mosaic_player_snapshots(old.player_id);',
      'perform app_private.refresh_mosaic_player_snapshots(new.player_id);',
    ]);
  });

  test('bridge mutation triggers run for insert delete and update changes', () {
    expect(
      migration,
      contains(
        'drop trigger if exists '
        'player_guest_profiles_refresh_mosaic_snapshots_insert_delete',
      ),
    );
    expect(
      migration,
      contains(
        'create trigger '
        'player_guest_profiles_refresh_mosaic_snapshots_insert_delete',
      ),
    );
    expect(migration, contains('after insert or delete'));
    expect(
      migration,
      contains(
        'drop trigger if exists '
        'player_guest_profiles_refresh_mosaic_snapshots_update',
      ),
    );
    expect(
      migration,
      contains(
        'create trigger '
        'player_guest_profiles_refresh_mosaic_snapshots_update',
      ),
    );
    expect(
      migration,
      contains(
          'after update of player_id, guest_profile_id, owner_user_id, status'),
    );
    expect(
      migration,
      contains(
        'for each row execute function '
        'app_private.refresh_mosaic_player_snapshots_for_bridge_change()',
      ),
    );
  });

  test('migration rebuilds current snapshots and reloads PostgREST schema', () {
    _expectOrdered(migration, [
      'select app_private.refresh_mosaic_player_snapshots();',
      "select pg_notify('pgrst', 'reload schema');",
    ]);
  });
}

String _latestFunctionBody(String functionName) {
  final migrationsDirectory = Directory('supabase/migrations');
  expect(migrationsDirectory.existsSync(), isTrue);

  String? latestBody;
  for (final file in migrationsDirectory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path))) {
    final migration = file.readAsStringSync();
    if (migration.contains('create or replace function $functionName')) {
      latestBody = _functionBody(migration, functionName);
    }
  }

  expect(latestBody, isNotNull, reason: 'Missing $functionName');
  return latestBody!;
}

String _functionBody(String sql, String functionName) {
  final escapedName = RegExp.escape(functionName);
  final matches = RegExp(
    'create or replace function\\s+$escapedName\\s*'
    r'\([^)]*\)[\s\S]*?\bas\s+\$\$\n([\s\S]*?)\n\$\$;',
    caseSensitive: false,
  ).allMatches(sql);

  expect(matches, isNotEmpty, reason: 'Missing $functionName');
  return matches.last.group(1)!;
}

void _expectOrdered(String source, List<String> snippets) {
  var previousIndex = -1;
  for (final snippet in snippets) {
    final nextIndex = source.indexOf(snippet, previousIndex + 1);
    expect(
      nextIndex,
      isNot(-1),
      reason: 'Expected to find "$snippet" after index $previousIndex.',
    );
    previousIndex = nextIndex;
  }
}
