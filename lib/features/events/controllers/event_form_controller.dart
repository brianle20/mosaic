import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/models/event_form_draft.dart';

class EventFormController extends ChangeNotifier {
  EventFormController({required EventRepository eventRepository})
      : _eventRepository = eventRepository;

  final EventRepository _eventRepository;

  bool isSubmitting = false;
  String? submitError;

  Future<EventRecord?> submit(EventFormDraft draft) async {
    if (!draft.isValid) {
      notifyListeners();
      return null;
    }

    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      final event = await _eventRepository.createEvent(draft.toCreateInput());
      isSubmitting = false;
      notifyListeners();
      return event;
    } catch (exception) {
      submitError = exception.toString();
      isSubmitting = false;
      notifyListeners();
      return null;
    }
  }
}
