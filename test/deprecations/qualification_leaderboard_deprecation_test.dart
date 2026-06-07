import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app code no longer exposes qualification leaderboard APIs', () {
    final appFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    final offenders = <String>[];
    for (final file in appFiles) {
      final source = file.readAsStringSync();
      if (source.contains('QualificationLeaderboardRow') ||
          source.contains('fetchQualificationLeaderboard')) {
        offenders.add(file.path);
      }
    }

    expect(offenders, isEmpty);
  });
}
