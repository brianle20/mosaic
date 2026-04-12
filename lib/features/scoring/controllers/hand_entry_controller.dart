import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/models/hand_result_draft.dart';

class HandEntryController extends ChangeNotifier {
  HandEntryController({required this.sessionRepository});

  final SessionRepository sessionRepository;

  bool isSubmitting = false;
  String? submitError;

  Future<SessionDetailRecord?> submit({
    required String tableSessionId,
    required HandResultDraft draft,
    HandResultRecord? existingHand,
  }) async {
    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      final detail = existingHand == null
          ? await sessionRepository.recordHand(
              draft.toRecordInput(tableSessionId: tableSessionId),
            )
          : await sessionRepository.editHand(
              draft.toEditInput(handResultId: existingHand.id),
            );
      return detail;
    } catch (err) {
      submitError = err.toString();
      return null;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<SessionDetailRecord?> voidHand({
    required String handResultId,
    String? correctionNote,
  }) async {
    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      return await sessionRepository.voidHand(
        VoidHandResultInput(
          handResultId: handResultId,
          correctionNote: correctionNote,
        ),
      );
    } catch (err) {
      submitError = err.toString();
      return null;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}
