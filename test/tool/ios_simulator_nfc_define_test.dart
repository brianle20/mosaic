import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS simulator push path always enables manual NFC debug mode', () {
    final repoRoot = Directory.current;
    final script = File('${repoRoot.path}/tool/run_ios_simulator_debug.sh');
    final agents = File('${repoRoot.path}/AGENTS.md').readAsStringSync();
    final readme = File('${repoRoot.path}/README.md').readAsStringSync();

    expect(script.existsSync(), isTrue);
    expect(
      Process.runSync('test', ['-x', script.path]).exitCode,
      0,
      reason: 'Simulator helper must be executable.',
    );

    final scriptText = script.readAsStringSync();
    expect(scriptText, contains('flutter build ios --simulator --debug'));
    expect(
      scriptText,
      contains('--dart-define=MOSAIC_USE_MANUAL_NFC=true'),
    );

    for (final docs in [agents, readme]) {
      expect(docs, contains('tool/run_ios_simulator_debug.sh'));
      for (final line in docs.split('\n')) {
        if (line.contains('flutter build ios --simulator --debug')) {
          expect(
            line,
            contains('--dart-define=MOSAIC_USE_MANUAL_NFC=true'),
            reason:
                'Simulator build docs must pass manual NFC debug mode: $line',
          );
        }
      }
    }
  });
}
