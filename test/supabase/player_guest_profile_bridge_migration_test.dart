import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/20260625183000_player_guest_profile_bridge.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
  });

  test('creates a durable guest profile to player bridge', () {
    expect(
      migration,
      contains('create table if not exists public.player_guest_profiles'),
    );
    expect(
      migration,
      contains('player_id uuid not null references public.players(id)'),
    );
    expect(
      migration,
      contains(
        'guest_profile_id uuid not null references public.guest_profiles(id)',
      ),
    );
    expect(
      migration,
      contains('owner_user_id uuid not null references public.users(id)'),
    );
    expect(migration, contains('player_guest_profiles_status_check'));
    expect(migration, contains('player_guest_profiles_confidence_check'));
    expect(
      migration,
      contains(
          'create unique index if not exists player_guest_profiles_active_profile_unique'),
    );
    expect(
      migration,
      contains(
          'create unique index if not exists player_guest_profiles_pair_unique'),
    );
  });

  test('bridge backfill preserves existing player links by guest profile', () {
    expect(
      migration,
      contains('insert into public.player_guest_profiles'),
    );
    expect(migration, contains('select distinct on (guest.guest_profile_id)'));
    expect(migration, contains('join public.guest_profiles as profile'));
    expect(migration, contains('profile.owner_user_id = event.owner_user_id'));
    expect(migration, contains('guest.player_id is not null'));
    expect(migration, contains("'historical_event_guest'"));
    expect(
      migration,
      contains('update public.event_guests as guest'),
    );
    expect(
      migration,
      contains('guest.player_id is distinct from bridge.player_id'),
    );
    expect(migration, contains('bridge.owner_user_id = event.owner_user_id'));
    expect(migration,
        contains('select app_private.refresh_mosaic_player_snapshots();'));
  });

  test('ensure players reuses bridged players before creating new ones', () {
    final ensurePlayersBody = _extractFunctionBody(
      migration,
      'app_private.ensure_players_for_event',
    );
    final bridgeLookupIndex = ensurePlayersBody.indexOf(
      'from public.player_guest_profiles as bridge',
    );
    final bridgedBranchIndex = ensurePlayersBody.indexOf(
      'if bridged_player_id is not null then',
    );
    final bridgedBranchMatch = RegExp(
      r'if bridged_player_id is not null then([\s\S]*?)end if;',
      caseSensitive: false,
    ).firstMatch(ensurePlayersBody);
    final createPlayerIndex = ensurePlayersBody.indexOf(
      'insert into public.players',
    );

    expect(ensurePlayersBody, isNotEmpty);
    expect(ensurePlayersBody, contains('bridged_player_id uuid'));
    expect(
      ensurePlayersBody,
      contains('from public.player_guest_profiles as bridge'),
    );
    expect(
      ensurePlayersBody,
      contains('bridge.guest_profile_id = guest_row.guest_profile_id'),
    );
    expect(ensurePlayersBody, contains('profile_is_event_owned boolean'));
    expect(ensurePlayersBody, contains('for update'));
    expect(
      ensurePlayersBody,
      contains('profile.owner_user_id = event_owner_user_id'),
    );
    expect(
      ensurePlayersBody,
      contains('bridge.owner_user_id = event_owner_user_id'),
    );
    expect(
      ensurePlayersBody,
      contains('if bridged_player_id is not null then'),
    );
    expect(
      ensurePlayersBody,
      contains('set player_id = bridged_player_id'),
    );
    expect(bridgeLookupIndex, isNonNegative);
    expect(bridgedBranchIndex, greaterThan(bridgeLookupIndex));
    expect(bridgedBranchMatch, isNotNull);
    final bridgedBranchSql = bridgedBranchMatch!.group(1)!;
    expect(bridgedBranchSql, contains('set player_id = bridged_player_id'));
    expect(bridgedBranchSql, contains('continue;'));
    expect(createPlayerIndex, greaterThan(bridgedBranchMatch.end));
    expect(
      ensurePlayersBody,
      contains('insert into public.players'),
    );
    expect(
      ensurePlayersBody,
      contains('insert into public.player_guest_profiles'),
    );
    expect(ensurePlayersBody, contains("'projection_seed'"));
  });
}

String _extractFunctionBody(String sql, String functionName) {
  final escapedName = RegExp.escape(functionName);
  final matches = RegExp(
    'create or replace function\\s+$escapedName\\s*'
    r'\([^)]*\)[\s\S]*?\bas\s+\$\$\n([\s\S]*?)\n\$\$;',
    caseSensitive: false,
  ).allMatches(sql);

  return matches.isEmpty ? '' : matches.last.group(1)!;
}
