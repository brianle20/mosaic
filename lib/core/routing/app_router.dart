import 'package:flutter/material.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/screens/guest_detail_screen.dart';
import 'package:mosaic/features/events/screens/create_event_screen.dart';
import 'package:mosaic/features/events/screens/event_dashboard_screen.dart';
import 'package:mosaic/features/events/screens/event_list_screen.dart';
import 'package:mosaic/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:mosaic/features/guests/screens/guest_form_screen.dart';
import 'package:mosaic/features/guests/screens/guest_roster_screen.dart';
import 'package:mosaic/features/scoring/screens/session_detail_screen.dart';
import 'package:mosaic/features/tables/screens/table_form_screen.dart';
import 'package:mosaic/features/tables/screens/start_session_screen.dart';
import 'package:mosaic/features/tables/screens/tables_overview_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';
import 'package:mosaic/data/models/table_models.dart';

class AppRouter {
  const AppRouter({
    required this.eventRepository,
    required this.guestRepository,
    required this.tableRepository,
    required this.sessionRepository,
    required this.leaderboardRepository,
    required this.nfcService,
  });

  final EventRepository eventRepository;
  final GuestRepository guestRepository;
  final TableRepository tableRepository;
  final SessionRepository sessionRepository;
  final LeaderboardRepository leaderboardRepository;
  final NfcService nfcService;

  static const eventListRoute = '/';
  static const createEventRoute = '/events/create';
  static const eventDashboardRoute = '/events/dashboard';
  static const guestRosterRoute = '/guests';
  static const guestDetailRoute = '/guests/detail';
  static const guestFormRoute = '/guests/form';
  static const tablesOverviewRoute = '/tables';
  static const tableFormRoute = '/tables/form';
  static const startSessionRoute = '/tables/start-session';
  static const sessionDetailRoute = '/sessions/detail';
  static const leaderboardRoute = '/leaderboard';

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
            leaderboardRepository: leaderboardRepository,
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
      case tablesOverviewRoute:
        final args = settings.arguments as TablesOverviewArgs;
        return MaterialPageRoute<void>(
          builder: (_) => TablesOverviewScreen(
            eventId: args.eventId,
            eventTitle: args.eventTitle,
            tableRepository: tableRepository,
            sessionRepository: sessionRepository,
          ),
          settings: settings,
        );
      case tableFormRoute:
        final args = settings.arguments as TableFormArgs;
        return MaterialPageRoute<void>(
          builder: (_) => TableFormScreen(
            eventId: args.eventId,
            tableRepository: tableRepository,
            nfcService: nfcService,
            initialTable: args.initialTable,
          ),
          settings: settings,
        );
      case startSessionRoute:
        final args = settings.arguments as StartSessionArgs;
        return MaterialPageRoute<void>(
          builder: (_) => StartSessionScreen(
            eventId: args.eventId,
            table: args.table,
            guestRepository: guestRepository,
            sessionRepository: sessionRepository,
            nfcService: nfcService,
          ),
          settings: settings,
        );
      case sessionDetailRoute:
        final args = settings.arguments as SessionDetailArgs;
        return MaterialPageRoute<void>(
          builder: (_) => SessionDetailScreen(
            eventId: args.eventId,
            sessionId: args.sessionId,
            guestRepository: guestRepository,
            sessionRepository: sessionRepository,
          ),
          settings: settings,
        );
      case leaderboardRoute:
        final args = settings.arguments as LeaderboardArgs;
        return MaterialPageRoute<void>(
          builder: (_) => LeaderboardScreen(
            eventId: args.eventId,
            leaderboardRepository: leaderboardRepository,
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

class TablesOverviewArgs {
  const TablesOverviewArgs({
    required this.eventId,
    required this.eventTitle,
  });

  final String eventId;
  final String eventTitle;
}

class TableFormArgs {
  const TableFormArgs({
    required this.eventId,
    this.initialTable,
  });

  final String eventId;
  final EventTableRecord? initialTable;
}

class StartSessionArgs {
  const StartSessionArgs({
    required this.eventId,
    required this.table,
  });

  final String eventId;
  final EventTableRecord table;
}

class SessionDetailArgs {
  const SessionDetailArgs({
    required this.eventId,
    required this.sessionId,
  });

  final String eventId;
  final String sessionId;
}

class LeaderboardArgs {
  const LeaderboardArgs({
    required this.eventId,
  });

  final String eventId;
}
