import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/guests/models/guest_form_draft.dart';

class GuestFormController extends ChangeNotifier {
  GuestFormController({required GuestRepository guestRepository})
      : _guestRepository = guestRepository;

  final GuestRepository _guestRepository;

  bool isSubmitting = false;
  String? submitError;

  Future<EventGuestRecord?> submit({
    required String eventId,
    required GuestFormDraft draft,
    GuestProfileRecord? selectedProfile,
    EventGuestRecord? existingGuest,
  }) async {
    if (!draft.isValid) {
      notifyListeners();
      return null;
    }

    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      final savedGuest = existingGuest == null
          ? await _guestRepository.createGuest(
              draft.toCreateInput(
                eventId: eventId,
                guestProfileId: selectedProfile?.id,
              ),
            )
          : await _guestRepository.updateGuest(
              draft.toUpdateInput(
                id: existingGuest.id,
                eventId: eventId,
              ),
            );

      isSubmitting = false;
      notifyListeners();
      return savedGuest;
    } catch (exception) {
      submitError = exception.toString();
      isSubmitting = false;
      notifyListeners();
      return null;
    }
  }
}
