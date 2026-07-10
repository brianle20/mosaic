import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/offline/network_reachability.dart';
import 'package:supabase/supabase.dart';

SupabaseClient _unusedClient() => SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
    );

void main() {
  test('onReachable emits only after backend reachability becomes true',
      () async {
    final connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    var reachable = false;
    final reachability = DefaultNetworkReachability(
      client: _unusedClient(),
      connectivityChecker: () async => reachable
          ? const [ConnectivityResult.wifi]
          : const [ConnectivityResult.none],
      connectivityChanges: connectivity.stream,
      backendProbe: () async {
        if (!reachable) {
          throw const NetworkUnavailableException('offline');
        }
      },
    );
    final emissions = <int>[];
    final subscription = reachability.onReachable.listen(
      (_) => emissions.add(1),
    );

    connectivity.add(const [ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    expect(emissions, isEmpty);

    reachable = true;
    connectivity.add(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(emissions, hasLength(1));

    connectivity.add(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(emissions, hasLength(1));

    await subscription.cancel();
    await connectivity.close();
  });
}
