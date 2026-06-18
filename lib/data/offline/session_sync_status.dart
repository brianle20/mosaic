import 'package:mosaic/data/offline/offline_models.dart';

abstract interface class SessionSyncStatusProvider {
  Future<SessionSyncSnapshot> readSessionSyncSnapshot(String sessionId);
}
