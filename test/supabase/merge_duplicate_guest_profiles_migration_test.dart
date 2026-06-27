import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/20260627143000_merge_duplicate_guest_profiles.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
  });

  test('repoints duplicate guest profiles to a canonical profile before delete',
      () {
    final updateIndex = migration.indexOf(
      'update public.event_guests as guest',
    );
    final deleteIndex = migration.indexOf('delete from public.guest_profiles');

    expect(updateIndex, isNonNegative);
    expect(deleteIndex, isNonNegative);
    expect(deleteIndex, greaterThan(updateIndex));
    expect(migration, contains('canonical_profile_id'));
    expect(migration, contains('duplicate_profile_id'));
    expect(
      migration,
      contains('guest.guest_profile_id = duplicate.duplicate_profile_id'),
    );
  });

  test('only merges duplicate profiles when identity fields do not conflict',
      () {
    expect(migration, contains('count(distinct profile.phone_e164) <= 1'));
    expect(migration, contains('count(distinct profile.email_lower) <= 1'));
    expect(
      migration,
      contains('count(distinct profile.instagram_handle) <= 1'),
    );
    expect(
      migration,
      contains('coalesce(profile.public_display_name,'),
    );
  });

  test('skips groups that would collapse multiple guests on one event', () {
    expect(
      migration,
      contains('event_guest_conflicts'),
    );
    expect(
      migration,
      contains('having count(*) > 1'),
    );
    expect(
      migration,
      contains('conflict.profile_group_key = duplicate.profile_group_key'),
    );
  });
}
