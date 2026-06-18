import 'package:mosaic/data/offline/offline_models.dart';

abstract interface class OfflineStore {
  Future<void> insertMutation(OfflineMutationRecord mutation);

  Future<OfflineMutationRecord?> readMutation(String id);

  Future<List<OfflineMutationRecord>> readPendingMutations();

  Future<List<OfflineMutationRecord>> readMutationsForSession(String sessionId);

  Future<void> markSyncing(String id, {required DateTime attemptedAt});

  Future<void> markSynced(String id);

  Future<void> markFailed(String id, String error);

  Future<void> markSessionBlocked(String sessionId, String error);

  Future<void> resetSyncingToPending();

  Future<void> close();
}
