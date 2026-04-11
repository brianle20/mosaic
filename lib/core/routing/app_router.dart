import 'package:flutter/material.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/screens/guest_detail_screen.dart';
import 'package:mosaic/features/events/screens/create_event_screen.dart';
import 'package:mosaic/features/events/screens/event_dashboard_screen.dart';
import 'package:mosaic/features/events/screens/event_list_screen.dart';
import 'package:mosaic/features/guests/screens/guest_form_screen.dart';
import 'package:mosaic/features/guests/screens/guest_roster_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class AppRouter {
  const AppRouter({
    required this.eventRepository,
    required this.guestRepository,
    required this.nfcService,
  });

  final EventRepository eventRepository;
  final GuestRepository guestRepository;
  final NfcService nfcService;

  static const eventListRoute = '/';
  static const createEventRoute = '/events/create';
  static const eventDashboardRoute = '/events/dashboard';
  static const guestRosterRoute = '/guests';
  static const guestDetailRoute = '/guests/detail';
  static const guestFormRoute = '/guests/form';

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case eventListRoute:
        return MaterialPageRoute<void>(
          builder: (_) => EventListScreen(
            eventRepository: eventRepository,
          ),
          settings: settings,
        );
      case createEventRoute:
        return MaterialPageRoute<void>(
          builder: (_) => CreateEventScreen(
            eventRepository: eventRepository,
          ),
          settings: settings,
        );
      case eventDashboardRoute:
        final args = settings.arguments as EventDashboardArgs;
        return MaterialPageRoute<void>(
          builder: (_) => EventDashboardScreen(
            args: args,
            eventRepository: eventRepository,
            guestRepository: guestRepository,
          ),
          settings: settings,
        );
      case guestRosterRoute:
        final args = settings.arguments as GuestRosterArgs;
        return MaterialPageRoute<void>(
          builder: (_) => GuestRosterScreen(
            eventId: args.eventId,
            eventTitle: args.eventTitle,
            guestRepository: guestRepository,
          ),
          settings: settings,
        );
      case guestFormRoute:
        final args = settings.arguments as GuestFormArgs;
        return MaterialPageRoute<void>(
          builder: (_) => GuestFormScreen(
            eventId: args.eventId,
            existingGuests: args.existingGuests,
            initialGuest: args.initialGuest,
            guestRepository: guestRepository,
          ),
          settings: settings,
        );
      case guestDetailRoute:
        final args = settings.arguments as GuestDetailArgs;
        return MaterialPageRoute<void>(
          builder: (_) => GuestDetailScreen(
            guestId: args.guestId,
            eventId: args.eventId,
            guestRepository: guestRepository,
            nfcService: nfcService,
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => EventListScreen(
            eventRepository: eventRepository,
          ),
          settings: settings,
        );
    }
  }
}

class EventDashboardArgs {
  const EventDashboardArgs({
    required this.eventId,
  });

  final String eventId;
}

class GuestRosterArgs {
  const GuestRosterArgs({
    required this.eventId,
    required this.eventTitle,
  });

  final String eventId;
  final String eventTitle;
}

class GuestFormArgs {
  const GuestFormArgs({
    required this.eventId,
    required this.existingGuests,
    this.initialGuest,
  });

  final String eventId;
  final List<EventGuestRecord> existingGuests;
  final EventGuestRecord? initialGuest;
}

class GuestDetailArgs {
  const GuestDetailArgs({
    required this.eventId,
    required this.guestId,
  });

  final String eventId;
  final String guestId;
}
