import 'package:mosaic/data/models/event_models.dart';
import 'package:meta/meta.dart';

@immutable
class EventFormDraft {
  const EventFormDraft({
    required this.title,
    required this.timezone,
    required this.startsAt,
    this.venueName = '',
    this.venueAddress = '',
    this.description = '',
    this.coverChargeCents = 0,
    this.prizeBudgetCents = 0,
  });

  final String title;
  final String timezone;
  final DateTime startsAt;
  final String venueName;
  final String venueAddress;
  final String description;
  final int coverChargeCents;
  final int prizeBudgetCents;

  String? get titleError {
    if (title.trim().isEmpty) {
      return 'Title is required.';
    }

    return null;
  }

  String? get timezoneError {
    if (timezone.trim().isEmpty) {
      return 'Timezone is required.';
    }

    return null;
  }

  String? get coverChargeError {
    if (coverChargeCents < 0) {
      return 'Cover charge must be zero or more.';
    }

    return null;
  }

  String? get prizeBudgetError {
    if (prizeBudgetCents < 0) {
      return 'Prize budget must be zero or more.';
    }

    return null;
  }

  bool get isValid {
    return titleError == null &&
        timezoneError == null &&
        coverChargeError == null &&
        prizeBudgetError == null;
  }

  CreateEventInput toCreateInput() {
    return CreateEventInput(
      title: title.trim(),
      timezone: timezone.trim(),
      startsAt: startsAt,
      venueName: venueName.trim().isEmpty ? null : venueName.trim(),
      venueAddress: venueAddress.trim().isEmpty ? null : venueAddress.trim(),
      description: description.trim().isEmpty ? null : description.trim(),
      coverChargeCents: coverChargeCents,
      prizeBudgetCents: prizeBudgetCents,
    );
  }
}
