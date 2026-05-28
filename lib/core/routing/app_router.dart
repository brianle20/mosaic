import 'package:flutter/material.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/staff_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/screens/guest_detail_screen.dart';
import 'package:mosaic/features/activity/screens/activity_screen.dart';
import 'package:mosaic/features/events/screens/bonus_round_screen.dart';
import 'package:mosaic/features/events/screens/create_event_screen.dart';
import 'package:mosaic/features/events/screens/event_dashboard_screen.dart';
import 'package:mosaic/features/events/screens/event_list_screen.dart';
import 'package:mosaic/features/events/screens/event_staff_screen.dart';
import 'package:mosaic/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:mosaic/features/prizes/screens/prize_awards_screen.dart';
import 'package:mosaic/features/prizes/screens/prize_plan_screen.dart';
import 'package:mosaic/features/guests/screens/guest_form_screen.dart';
import 'package:mosaic/features/guests/screens/guest_roster_screen.dart';
import 'package:mosaic/features/scoring/screens/event_hand_ledger_screen.dart';
import 'package:mosaic/features/scoring/screens/session_detail_screen.dart';
import 'package:mosaic/features/tables/screens/seating_assignment_screen.dart';
import 'package:mosaic/features/tables/screens/table_form_screen.dart';
import 'package:mosaic/features/tables/screens/start_session_screen.dart';
import 'package:mosaic/features/tables/screens/tables_overview_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class AppRouter {
  const AppRouter({
    required this.eventRepository,
    required this.guestRepository,
    required this.tableRepository,
    required this.sessionRepository,
    required this.leaderboardRepository,
    required this.activityRepository,
    required this.prizeRepository,
    required this.seatingRepository,
    this.staffRepository,
    required this.nfcService,
    this.accessState,
  });

  final EventRepository eventRepository;
  final GuestRepository guestRepository;
  final TableRepository tableRepository;
  final SessionRepository sessionRepository;
  final LeaderboardRepository leaderboardRepository;
  final ActivityRepository activityRepository;
  final PrizeRepository prizeRepository;
  final SeatingRepository seatingRepository;
  final StaffRepository? staffRepository;
  final NfcService nfcService;
  final MosaicAccessState? accessState;

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
  static const activityRoute = '/activity';
  static const eventHandLedgerRoute = '/events/hand-ledger';
  static const bonusRoundRoute = '/events/bonus-round';
  static const prizePlanRoute = '/prizes/plan';
  static const prizeAwardsRoute = '/prizes/awards';
  static const seatingAssignmentsRoute = '/tables/seating';
  static const eventStaffRoute = '/events/staff';

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case eventListRoute:
        return MaterialPageRoute<void>(
          builder: (_) => EventListScreen(
            eventRepository: eventRepository,
            accessState: accessState,
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
            prizeRepository: prizeRepository,
            tableRepository: tableRepository,
            sessionRepository: sessionRepository,
            seatingRepository: seatingRepository,
            staffRepository:
                staffRepository ?? const _UnavailableStaffRepository(),
            nfcService: nfcService,
          ),
          settings: settings,
        );
      case eventStaffRoute:
        final args = settings.arguments as EventStaffArgs;
        return MaterialPageRoute<void>(
          builder: (_) => EventStaffScreen(
            eventId: args.eventId,
            eventTitle: args.eventTitle,
            staffRepository:
                staffRepository ?? const _UnavailableStaffRepository(),
          ),
          settings: settings,
        );
      case guestRosterRoute:
        final args = settings.arguments as GuestRosterArgs;
        return MaterialPageRoute<void>(
          builder: (_) => GuestRosterScreen(
            eventId: args.eventId,
            eventTitle: args.eventTitle,
            eventCoverChargeCents: args.eventCoverChargeCents,
            canCheckIn: args.canCheckIn,
            canManageGuests: args.canManageGuests,
            canManageCover: args.canManageCover,
            canAssignTags: args.canAssignTags,
            canManageTournamentStatus: args.canManageTournamentStatus,
            guestRepository: guestRepository,
            nfcService: nfcService,
          ),
          settings: settings,
        );
      case guestFormRoute:
        final args = settings.arguments as GuestFormArgs;
        return MaterialPageRoute<void>(
          builder: (_) => GuestFormScreen(
            eventId: args.eventId,
            existingGuests: args.existingGuests,
            defaultCoverAmountCents: args.defaultCoverAmountCents,
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
            canCheckIn: args.canCheckIn,
            canManageGuests: args.canManageGuests,
            canManageCover: args.canManageCover,
            canAssignTags: args.canAssignTags,
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
            scoringOpen: args.scoringOpen,
            scoringPhase: args.scoringPhase,
            readOnly: args.readOnly,
            canManageTables: args.canManageTables,
            tableRepository: tableRepository,
            sessionRepository: sessionRepository,
            guestRepository: guestRepository,
            seatingRepository: seatingRepository,
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
            seatingRepository: seatingRepository,
            sessionRepository: sessionRepository,
            nfcService: nfcService,
            scoringPhase: args.scoringPhase,
            preverifiedTableTagUid: args.preverifiedTableTagUid,
            allowAssignedTableEntry: args.allowAssignedTableEntry,
          ),
          settings: settings,
        );
      case sessionDetailRoute:
        final args = settings.arguments as SessionDetailArgs;
        return MaterialPageRoute<void>(
          builder: (_) => SessionDetailScreen(
            eventId: args.eventId,
            sessionId: args.sessionId,
            scoringOpen: args.scoringOpen,
            guestRepository: guestRepository,
            sessionRepository: sessionRepository,
            nfcService: nfcService,
          ),
          settings: settings,
        );
      case leaderboardRoute:
        final args = settings.arguments as LeaderboardArgs;
        return MaterialPageRoute<void>(
          builder: (_) => LeaderboardScreen(
            eventId: args.eventId,
            leaderboardRepository: leaderboardRepository,
            guestRepository: guestRepository,
            sessionRepository: sessionRepository,
            seatingRepository: seatingRepository,
            initialQualificationTab: args.initialQualificationTab,
          ),
          settings: settings,
        );
      case activityRoute:
        final args = settings.arguments as ActivityArgs;
        return MaterialPageRoute<void>(
          builder: (_) => ActivityScreen(
            eventId: args.eventId,
            activityRepository: activityRepository,
          ),
          settings: settings,
        );
      case eventHandLedgerRoute:
        final args = settings.arguments as EventHandLedgerArgs;
        return MaterialPageRoute<void>(
          builder: (_) => EventHandLedgerScreen(
            eventId: args.eventId,
            sessionRepository: sessionRepository,
          ),
          settings: settings,
        );
      case bonusRoundRoute:
        final args = settings.arguments as BonusRoundArgs;
        return MaterialPageRoute<void>(
          builder: (_) => BonusRoundScreen(
            eventId: args.eventId,
            leaderboardRepository: leaderboardRepository,
            tableRepository: tableRepository,
            sessionRepository: sessionRepository,
            seatingRepository: seatingRepository,
            nfcService: nfcService,
          ),
          settings: settings,
        );
      case prizePlanRoute:
        final args = settings.arguments as PrizePlanArgs;
        return MaterialPageRoute<void>(
          builder: (_) => PrizePlanScreen(
            eventId: args.eventId,
            prizeRepository: prizeRepository,
          ),
          settings: settings,
        );
      case prizeAwardsRoute:
        final args = settings.arguments as PrizeAwardsArgs;
        return MaterialPageRoute<void>(
          builder: (_) => PrizeAwardsScreen(
            eventId: args.eventId,
            guestNamesById: args.guestNamesById,
            prizeRepository: prizeRepository,
          ),
          settings: settings,
        );
      case seatingAssignmentsRoute:
        final args = settings.arguments as SeatingAssignmentsArgs;
        return MaterialPageRoute<void>(
          builder: (_) => SeatingAssignmentScreen(
            eventId: args.eventId,
            seatingRepository: seatingRepository,
            guestRepository: guestRepository,
            sessionRepository: sessionRepository,
            initialAssignments: args.initialAssignments,
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => EventListScreen(
            eventRepository: eventRepository,
            accessState: accessState,
          ),
          settings: settings,
        );
    }
  }
}

class _UnavailableStaffRepository implements StaffRepository {
  const _UnavailableStaffRepository();

  @override
  Future<List<EventStaffMembershipRecord>> listEventStaff(String eventId) =>
      throw UnimplementedError();

  @override
  Future<EventStaffMembershipRecord> upsertEventStaff(
    UpsertEventStaffMembershipInput input,
  ) =>
      throw UnimplementedError();

  @override
  Future<EventStaffMembershipRecord> disableEventStaffMembership(
    String membershipId,
  ) =>
      throw UnimplementedError();
}

class EventDashboardArgs {
  const EventDashboardArgs({
    required this.eventId,
    this.callerRole = MosaicAccessRole.owner,
  });

  final String eventId;
  final MosaicAccessRole callerRole;
}

class EventStaffArgs {
  const EventStaffArgs({
    required this.eventId,
    required this.eventTitle,
  });

  final String eventId;
  final String eventTitle;
}

class GuestRosterArgs {
  const GuestRosterArgs({
    required this.eventId,
    required this.eventTitle,
    required this.eventCoverChargeCents,
    this.canCheckIn = true,
    this.canManageGuests = true,
    this.canManageCover = true,
    this.canAssignTags = true,
    this.canManageTournamentStatus = true,
  });

  final String eventId;
  final String eventTitle;
  final int eventCoverChargeCents;
  final bool canCheckIn;
  final bool canManageGuests;
  final bool canManageCover;
  final bool canAssignTags;
  final bool canManageTournamentStatus;
}

class EventHandLedgerArgs {
  const EventHandLedgerArgs({
    required this.eventId,
  });

  final String eventId;
}

class BonusRoundArgs {
  const BonusRoundArgs({
    required this.eventId,
  });

  final String eventId;
}

class GuestFormArgs {
  const GuestFormArgs({
    required this.eventId,
    required this.existingGuests,
    required this.defaultCoverAmountCents,
    this.initialGuest,
  });

  final String eventId;
  final List<EventGuestRecord> existingGuests;
  final int defaultCoverAmountCents;
  final EventGuestRecord? initialGuest;
}

class GuestDetailArgs {
  const GuestDetailArgs({
    required this.eventId,
    required this.guestId,
    this.canCheckIn = true,
    this.canManageGuests = true,
    this.canManageCover = true,
    this.canAssignTags = true,
  });

  final String eventId;
  final String guestId;
  final bool canCheckIn;
  final bool canManageGuests;
  final bool canManageCover;
  final bool canAssignTags;
}

class TablesOverviewArgs {
  const TablesOverviewArgs({
    required this.eventId,
    required this.eventTitle,
    required this.scoringOpen,
    this.scoringPhase = EventScoringPhase.tournament,
    this.readOnly = false,
    this.canManageTables = true,
  });

  final String eventId;
  final String eventTitle;
  final bool scoringOpen;
  final EventScoringPhase scoringPhase;
  final bool readOnly;
  final bool canManageTables;
}

class ActivityArgs {
  const ActivityArgs({
    required this.eventId,
  });

  final String eventId;
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
    this.scoringPhase = EventScoringPhase.qualification,
    this.preverifiedTableTagUid,
    this.allowAssignedTableEntry = false,
  });

  final String eventId;
  final EventTableRecord table;
  final EventScoringPhase scoringPhase;
  final String? preverifiedTableTagUid;
  final bool allowAssignedTableEntry;
}

class SeatingAssignmentsArgs {
  const SeatingAssignmentsArgs({
    required this.eventId,
    this.initialAssignments = const [],
  });

  final String eventId;
  final List<SeatingAssignmentRecord> initialAssignments;
}

class SessionDetailArgs {
  const SessionDetailArgs({
    required this.eventId,
    required this.sessionId,
    this.scoringOpen = true,
  });

  final String eventId;
  final String sessionId;
  final bool scoringOpen;
}

class LeaderboardArgs {
  const LeaderboardArgs({
    required this.eventId,
    this.initialQualificationTab = false,
  });

  final String eventId;
  final bool initialQualificationTab;
}

class PrizePlanArgs {
  const PrizePlanArgs({
    required this.eventId,
  });

  final String eventId;
}

class PrizeAwardsArgs {
  const PrizeAwardsArgs({
    required this.eventId,
    this.guestNamesById = const {},
  });

  final String eventId;
  final Map<String, String> guestNamesById;
}
