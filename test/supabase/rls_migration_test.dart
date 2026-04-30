import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every public table created by migrations enables row-level security',
      () {
    final migrationsDirectory = Directory('supabase/migrations');
    final migrationFiles = migrationsDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final createTablePattern = RegExp(
      r'create\s+table\s+(?:if\s+not\s+exists\s+)?public\.([a-z_]+)\b',
      caseSensitive: false,
    );
    final enableRlsPattern = RegExp(
      r'alter\s+table\s+public\.([a-z_]+)\s+enable\s+row\s+level\s+security\b',
      caseSensitive: false,
    );

    final createdTables = <String>{};
    final rlsEnabledTables = <String>{};

    for (final file in migrationFiles) {
      final sql = file.readAsStringSync();
      createdTables.addAll(
        createTablePattern.allMatches(sql).map((match) => match.group(1)!),
      );
      rlsEnabledTables.addAll(
        enableRlsPattern.allMatches(sql).map((match) => match.group(1)!),
      );
    }

    expect(
      createdTables.difference(rlsEnabledTables).toList()..sort(),
      isEmpty,
    );
  });
}
