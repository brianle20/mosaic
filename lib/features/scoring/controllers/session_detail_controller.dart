import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class SessionDetailController extends ChangeNotifier {
  SessionDetailController({
    required this.guestRepository,
    required this.sessionRepository,
  });

  final GuestRepository guestRepository;
  final SessionRepository sessionRepository;

  bool isLoading = false;
  String? error;
  SessionDetailRecord? detail;
  Map<String, String> guestNamesById = const {};

  Future<void> load({
    required String eventId,
    required String sessionId,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final loadedDetail = await sessionRepository.loadSessionDetail(sessionId);
      final guests = await guestRepository.listGuests(eventId);
      guestNamesById = {
        for (final guest in guests) guest.id: guest.displayName,
      };
      detail = loadedDetail;
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
