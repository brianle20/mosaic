import 'package:flutter/foundation.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/models/hand_result_draft.dart';

class HandEntryController extends ChangeNotifier {
  HandEntryController({required this.sessionRepository});

  final SessionRepository sessionRepository;

  bool isSubmitting = false;
  String? submitError;
  bool photoOwnershipTransferred = false;
  String? _transferredPhotoPath;
  bool _isDisposed = false;

  Future<SessionDetailRecord?> submit({
    required String tableSessionId,
    required HandResultDraft draft,
    HandResultRecord? existingHand,
  }) async {
    if (_isDisposed) {
      return null;
    }
    isSubmitting = true;
    submitError = null;
    photoOwnershipTransferred = draft.photoLocalPath != null &&
        draft.photoLocalPath == _transferredPhotoPath;
    _notifyIfActive();

    try {
      final queueStatus = sessionRepository is PhotoQueueCommitStatus
          ? sessionRepository as PhotoQueueCommitStatus
          : null;
      final detail = existingHand == null
          ? await sessionRepository.recordHand(
              draft.toRecordInput(tableSessionId: tableSessionId),
            )
          : await sessionRepository.editHand(
              draft.toEditInput(
                handResultId: existingHand.id,
                legacyDealerWasWaitingAtDraw:
                    existingHand.dealerWasWaitingAtDraw,
              ),
            );
      if (draft.photoLocalPath != null) {
        photoOwnershipTransferred = queueStatus?.photoMutationCommitted ?? true;
        if (photoOwnershipTransferred) {
          _transferredPhotoPath = draft.photoLocalPath;
        }
      }
      return detail;
    } catch (err) {
      final queueStatus = sessionRepository is PhotoQueueCommitStatus
          ? sessionRepository as PhotoQueueCommitStatus
          : null;
      if (draft.photoLocalPath != null &&
          (queueStatus?.photoMutationCommitted ?? false)) {
        photoOwnershipTransferred = true;
        _transferredPhotoPath = draft.photoLocalPath;
      }
      if (!_isDisposed) {
        submitError =
            userFacingError(err, fallback: 'Unable to save this hand.');
      }
      return null;
    } finally {
      isSubmitting = false;
      _notifyIfActive();
    }
  }

  Future<SessionDetailRecord?> voidHand({
    required String handResultId,
    String? correctionNote,
  }) async {
    if (_isDisposed) {
      return null;
    }
    isSubmitting = true;
    submitError = null;
    _notifyIfActive();

    try {
      return await sessionRepository.voidHand(
        VoidHandResultInput(
          handResultId: handResultId,
          correctionNote: correctionNote,
        ),
      );
    } catch (err) {
      if (!_isDisposed) {
        submitError =
            userFacingError(err, fallback: 'Unable to update this hand.');
      }
      return null;
    } finally {
      isSubmitting = false;
      _notifyIfActive();
    }
  }

  Future<SessionDetailRecord?> recordFalseWinPenalty({
    required String tableSessionId,
    required int penaltySeatIndex,
    String? correctionNote,
  }) async {
    if (_isDisposed) {
      return null;
    }
    isSubmitting = true;
    submitError = null;
    _notifyIfActive();

    try {
      return await sessionRepository.recordFalseWinPenalty(
        RecordFalseWinPenaltyInput(
          tableSessionId: tableSessionId,
          penaltySeatIndex: penaltySeatIndex,
          correctionNote:
              correctionNote == null || correctionNote.trim().isEmpty
                  ? null
                  : correctionNote.trim(),
        ),
      );
    } catch (err) {
      if (!_isDisposed) {
        submitError =
            userFacingError(err, fallback: 'Unable to save the false win.');
      }
      return null;
    } finally {
      isSubmitting = false;
      _notifyIfActive();
    }
  }

  Future<SessionDetailRecord?> voidFalseWinPenalty({
    required String handFalseWinPenaltyId,
    String? correctionNote,
  }) async {
    if (_isDisposed) {
      return null;
    }
    isSubmitting = true;
    submitError = null;
    _notifyIfActive();

    try {
      final correctionRepository =
          sessionRepository as FalseWinPenaltyCorrectionRepository;
      return await correctionRepository.voidFalseWinPenalty(
        VoidFalseWinPenaltyInput(
          handFalseWinPenaltyId: handFalseWinPenaltyId,
          correctionNote:
              correctionNote == null || correctionNote.trim().isEmpty
                  ? null
                  : correctionNote.trim(),
        ),
      );
    } catch (err) {
      if (!_isDisposed) {
        submitError =
            userFacingError(err, fallback: 'Unable to update the false win.');
      }
      return null;
    } finally {
      isSubmitting = false;
      _notifyIfActive();
    }
  }

  void _notifyIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
