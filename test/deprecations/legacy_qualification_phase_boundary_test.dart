import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app code names qualification scoring as legacy-only support', () {
    final appFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    const disallowedActiveNames = <String>[
      'canScoreQualification',
    ];

    final offenders = <String>[];
    for (final file in appFiles) {
      final source = file.readAsStringSync();
      for (final name in disallowedActiveNames) {
        if (source.contains(name)) {
          offenders.add('${file.path}: $name');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
