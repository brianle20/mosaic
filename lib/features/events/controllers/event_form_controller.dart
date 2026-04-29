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
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _notifyIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<EventRecord?> submit(EventFormDraft draft) async {
    if (!draft.isValid) {
      _notifyIfActive();
      return null;
    }

    isSubmitting = true;
    submitError = null;
    _notifyIfActive();

    try {
      final event = await _eventRepository.createEvent(draft.toCreateInput());
      isSubmitting = false;
      _notifyIfActive();
      return event;
    } catch (exception) {
      submitError = exception.toString();
      isSubmitting = false;
      _notifyIfActive();
      return null;
    }
  }
}
