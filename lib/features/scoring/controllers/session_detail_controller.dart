import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class SessionDetailController extends ChangeNotifier {
  SessionDetailController({
    required this.guestRepository,
    required this.sessionRepository,
  });

  final GuestRepository guestRepository;
  final SessionRepository sessionRepository;

  bool isLoading = false;
  bool isSubmittingOperation = false;
  String? error;
  String? actionError;
  SessionDetailRecord? detail;
  Map<String, String> guestNamesById = const {};
  Map<String, GuestTagAssignmentSummary> activeTagAssignmentsByGuestId =
      const {};

  Future<void> load({
    required String eventId,
    required String sessionId,
  }) async {
    isLoading = true;
    error = null;
    actionError = null;
    notifyListeners();

    try {
      final loadedDetail = await sessionRepository.loadSessionDetail(sessionId);
      final guests = await guestRepository.listGuests(eventId);
      guestNamesById = {
        for (final guest in guests) guest.id: guest.displayName,
      };
      try {
        activeTagAssignmentsByGuestId =
            await guestRepository.listActiveTagAssignments(eventId);
      } catch (_) {
        activeTagAssignmentsByGuestId = const {};
      }
      detail = loadedDetail;
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pauseSession() async {
    final currentDetail = detail;
    if (currentDetail == null || isSubmittingOperation) {
      return;
    }

    isSubmittingOperation = true;
    actionError = null;
    notifyListeners();

    try {
      detail = await sessionRepository.pauseSession(currentDetail.session.id);
    } catch (err) {
      actionError = _formatActionError(err);
    } finally {
      isSubmittingOperation = false;
      notifyListeners();
    }
  }

  Future<void> resumeSession() async {
    final currentDetail = detail;
    if (currentDetail == null || isSubmittingOperation) {
      return;
    }

    isSubmittingOperation = true;
    actionError = null;
    notifyListeners();

    try {
      detail = await sessionRepository.resumeSession(currentDetail.session.id);
    } catch (err) {
      actionError = _formatActionError(err);
    } finally {
      isSubmittingOperation = false;
      notifyListeners();
    }
  }

  Future<bool> endSession(String reason) async {
    final currentDetail = detail;
    if (currentDetail == null || isSubmittingOperation) {
      return false;
    }

    isSubmittingOperation = true;
    actionError = null;
    notifyListeners();

    try {
      detail = await sessionRepository.endSession(
        sessionId: currentDetail.session.id,
        reason: reason,
      );
      return true;
    } catch (err) {
      actionError = _formatActionError(err);
      return false;
    } finally {
      isSubmittingOperation = false;
      notifyListeners();
    }
  }

  String _formatActionError(Object exception) {
    final message = exception.toString();
    const statePrefix = 'Bad state: ';
    if (message.startsWith(statePrefix)) {
      return message.substring(statePrefix.length);
    }
    return message;
  }
}
