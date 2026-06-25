import 'package:mosaic/data/offline/offline_models.dart';

abstract interface class OfflineStore {
  Future<void> insertMutation(OfflineMutationRecord mutation);

  Future<void> insertPhotoUpload(OfflinePhotoUploadRecord upload);

  Future<void> insertMutationWithPhotoUpload(
    OfflineMutationRecord mutation,
    OfflinePhotoUploadRecord upload,
  );

  Future<OfflineMutationRecord?> readMutation(String id);

  Future<List<OfflineMutationRecord>> readPendingMutations();

  Future<List<OfflineMutationRecord>> readMutationsForSession(String sessionId);

  Future<List<OfflinePhotoUploadRecord>> readPendingPhotoUploads();

  Future<List<OfflinePhotoUploadRecord>> readPhotoUploadsForSession(
    String sessionId,
  );

  Future<void> markSyncing(String id, {required DateTime attemptedAt});

  Future<void> markSynced(String id);

  Future<void> markFailed(String id, String error);

  Future<void> markSessionBlocked(String sessionId, String error);

  Future<void> markPhotoUploadUploading(
    String id, {
    required DateTime attemptedAt,
  });

  Future<void> markPhotoUploadUploaded(
    String id, {
    required String storagePath,
  });

  Future<void> markPhotoUploadFailed(String id, String error);

  Future<void> markPhotoUploadBlocked(String id, String error);

  Future<void> attachRemoteHandResultToPhotoUpload(
    String mutationId,
    String remoteHandResultId,
  );

  Future<void> resetPhotoUploadsUploadingToPending();

  Future<void> resetSyncingToPending();

  Future<void> close();
}
