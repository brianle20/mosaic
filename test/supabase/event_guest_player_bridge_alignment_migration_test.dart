import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/'
      '20260627180000_event_guest_player_bridge_alignment.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
  });

  test('documents event guest player id as bridge-aligned cache', () {
    expect(
      migration,
      contains('comment on column public.event_guests.player_id'),
    );
    expect(migration, contains('Cached resolved Mosaic player identity'));
    expect(migration, contains('public.player_guest_profiles'));
    expect(migration, contains('canonical saved-profile-to-player bridge'));
  });

  test('repairs existing event guest player ids from active bridge rows', () {
    expect(migration, contains('update public.event_guests as guest'));
    expect(migration, contains('set player_id = bridge.player_id'));
    expect(
      migration,
      contains('from public.player_guest_profiles as bridge'),
    );
    expect(migration,
        contains('bridge.guest_profile_id = guest.guest_profile_id'));
    expect(migration, contains("bridge.status = 'active'"));
    expect(migration, contains('profile.owner_user_id = event.owner_user_id'));
    expect(migration,
        contains('guest.player_id is distinct from bridge.player_id'));
  });

  test('trigger aligns future event guest writes to active bridge', () {
    final functionBody = _extractFunctionBody(
      migration,
      'app_private.align_event_guest_player_bridge',
    );

    expect(functionBody, contains('bridged_player_id uuid'));
    expect(functionBody, contains('new.guest_profile_id is null'));
    expect(functionBody, contains('bridge.player_id'));
    expect(functionBody,
        contains('bridge.guest_profile_id = new.guest_profile_id'));
    expect(
        functionBody, contains('bridge.owner_user_id = event.owner_user_id'));
    expect(functionBody, contains("bridge.status = 'active'"));
    expect(functionBody, contains('new.player_id := bridged_player_id'));
    expect(functionBody, contains('return new'));
  });

  test('trigger runs when event guest profile or player id changes', () {
    expect(
      migration,
      contains('drop trigger if exists event_guests_align_player_bridge'),
    );
    expect(
      migration,
      contains('create trigger event_guests_align_player_bridge'),
    );
    expect(
      migration,
      contains('before insert or update of guest_profile_id, player_id'),
    );
    expect(
      migration,
      contains(
        'for each row execute function app_private.align_event_guest_player_bridge()',
      ),
    );
  });

  test('alignment migration follows duplicate profile merge migration', () {
    final mergeMigration = File(
      'supabase/migrations/20260627143000_merge_duplicate_guest_profiles.sql',
    );
    expect(mergeMigration.existsSync(), isTrue);
    expect(
      '20260627180000_event_guest_player_bridge_alignment.sql'.compareTo(
        '20260627143000_merge_duplicate_guest_profiles.sql',
      ),
      greaterThan(0),
    );
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
