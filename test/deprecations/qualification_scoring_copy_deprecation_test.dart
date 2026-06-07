import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app code no longer exposes qualification scoring copy', () {
    final appFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    const disallowedCopy = <String>[
      'Ready for qualification play',
      'qualifier hands',
      'Start qualification',
      'qualification standings',
      'qualification scoring',
    ];

    final offenders = <String>[];
    for (final file in appFiles) {
      final source = file.readAsStringSync();
      for (final copy in disallowedCopy) {
        if (source.contains(copy)) {
          offenders.add('${file.path}: $copy');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
