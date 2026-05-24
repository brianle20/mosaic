import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';
import 'package:mosaic/features/checkin/screens/add_cover_entry_screen.dart';
import 'package:mosaic/features/guests/controllers/guest_roster_controller.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';
import 'package:mosaic/widgets/empty_state_card.dart';
import 'package:mosaic/widgets/status_chip.dart';

enum _GuestRosterOverflowAction {
  markPaidManually,
  addCoverEntry,
  markQualifying,
  markQualified,
  moveToOpenPlayOnly,
  withdraw,
}

enum _GuestRosterCheckInFilter {
  all,
  notCheckedIn,
  checkedIn,
}

enum _GuestRosterTournamentFilter {
  all,
  qualifying,
  qualified,
  openPlayOnly,
  withdrawn,
}

const _guestCardSectionGap = 6.0;

class GuestRosterScreen extends StatefulWidget {
  const GuestRosterScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.eventCoverChargeCents,
    required this.guestRepository,
    required this.nfcService,
  });

  final String eventId;
  final String eventTitle;
  final int eventCoverChargeCents;
  final GuestRepository guestRepository;
  final NfcService nfcService;

  @override
  State<GuestRosterScreen> createState() => _GuestRosterScreenState();
}

class _GuestRosterScreenState extends State<GuestRosterScreen> {
  late final GuestRosterController _controller;
  final _searchController = TextEditingController();
  _GuestRosterCheckInFilter _checkInFilter = _GuestRosterCheckInFilter.all;
  _GuestRosterTournamentFilter _tournamentFilter =
      _GuestRosterTournamentFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _controller = GuestRosterController(guestRepository: widget.guestRepository)
      ..addListener(_handleUpdate)
      ..load(widget.eventId);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _controller
      ..removeListener(_handleUpdate)
      ..dispose();
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openAddGuest() async {
    await Navigator.of(context).pushNamed(
      AppRouter.guestFormRoute,
      arguments: GuestFormArgs(
        eventId: widget.eventId,
        existingGuests: _controller.guests,
        defaultCoverAmountCents: widget.eventCoverChargeCents,
      ),
    );
    if (!mounted) {
      return;
    }
    await _controller.load(widget.eventId);
  }

  Future<void> _openGuestDetail(EventGuestRecord guest) async {
    await Navigator.of(context).pushNamed(
      AppRouter.guestDetailRoute,
      arguments: GuestDetailArgs(
        eventId: widget.eventId,
        guestId: guest.id,
      ),
    );
    if (!mounted) {
      return;
    }
    await _controller.load(widget.eventId);
  }

  Future<void> _markPaid(EventGuestRecord guest) async {
    await _runQuickAction(
      () => _controller.markPaid(guest.id),
      successMessage: '${guest.displayName} is now marked paid.',
    );
  }

  Future<void> _markComped(EventGuestRecord guest) async {
    await _runQuickAction(
      () => _controller.markComped(guest.id),
      successMessage: '${guest.displayName} is now marked comped.',
    );
  }

  Future<void> _checkInAndAssign(EventGuestRecord guest) async {
    await _runQuickAction(
      () => _controller.checkInAndAssign(
        guestId: guest.id,
        scanForTag: () => widget.nfcService.scanPlayerTagForAssignment(context),
      ),
      successMessage: '${guest.displayName} is checked in and tagged.',
    );
  }

  Future<void> _assignTag(EventGuestRecord guest) async {
    await _runQuickAction(
      () => _controller.assignTag(
        guestId: guest.id,
        scanForTag: () => widget.nfcService.scanPlayerTagForAssignment(context),
      ),
      successMessage: 'Player tag assigned to ${guest.displayName}.',
    );
  }

  Future<void> _updateTournamentStatus(
    EventGuestRecord guest,
    EventTournamentStatus status,
  ) async {
    await _runQuickAction(
      () => _controller.updateTournamentStatus(
        guestId: guest.id,
        status: status,
      ),
      successMessage:
          '${guest.displayName} is now ${_tournamentStatusLabel(status).toLowerCase()}.',
    );
  }

  Future<void> _addCoverEntry(EventGuestRecord guest) async {
    final initialAmountCents = await _initialCoverEntryAmountCents(guest);
    if (!mounted) {
      return;
    }

    final submission = await Navigator.of(context).push<SubmitCoverEntryInput>(
      MaterialPageRoute(
        builder: (_) => AddCoverEntryScreen(
          initialAmountCents: initialAmountCents,
        ),
      ),
    );
    if (submission == null) {
      return;
    }

    await _runQuickAction(
      () => _controller.recordCoverEntry(
        guestId: guest.id,
        input: submission,
      ),
      successMessage: 'Cover entry saved for ${guest.displayName}.',
    );
  }

  Future<int> _initialCoverEntryAmountCents(EventGuestRecord guest) async {
    if (guest.coverStatus != CoverStatus.partial) {
      return suggestedCoverEntryAmountCents(guest: guest);
    }

    var coverEntries = await widget.guestRepository.readCachedGuestCoverEntries(
      guest.id,
    );
    if (coverEntries.isEmpty) {
      coverEntries = await widget.guestRepository.loadGuestCoverEntries(
        guest.id,
      );
    }

    return suggestedCoverEntryAmountCents(
      guest: guest,
      coverEntries: coverEntries,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runQuickAction(
    Future<bool> Function() action, {
    required String successMessage,
  }) async {
    try {
      final didComplete = await action();
      if (!mounted) {
        return;
      }
      if (!didComplete) {
        return;
      }
      _showMessage(successMessage);
    } catch (exception) {
      if (!mounted) {
        return;
      }
      _showMessage(_formatActionError(exception));
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text.trim().toLowerCase();
    final filteredGuests = _controller.guests
        .where((guest) => _matchesSearch(guest, searchQuery))
        .where(_matchesCheckInFilter)
        .where(_matchesTournamentFilter)
        .toList(growable: false);
    final notCheckedInGuests = filteredGuests
        .where((guest) => !guest.isCheckedIn)
        .toList(growable: false);
    final checkedInGuests = filteredGuests
        .where((guest) => guest.isCheckedIn)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Guests')),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: () => _controller.load(widget.eventId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: _openAddGuest,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Guest'),
            ),
            const SizedBox(height: 16),
            Text(widget.eventTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (_controller.guests.isNotEmpty) ...[
              _buildSearchField(),
              const SizedBox(height: 12),
              _buildCheckInFilter(),
              const SizedBox(height: 8),
              _buildTournamentFilter(),
              const SizedBox(height: 12),
              ..._buildGuestSection(
                context,
                title: 'Pending',
                guests: notCheckedInGuests,
              ),
              ..._buildGuestSection(
                context,
                title: 'Checked In',
                guests: checkedInGuests,
              ),
              if (filteredGuests.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: EmptyStateCard(
                    icon: Icons.search_off,
                    title: 'No matching guests',
                    message: 'Try a different search or filter.',
                  ),
                ),
            ],
            if (_controller.guests.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyStateCard(
                  icon: Icons.people_outline,
                  title: 'No guests yet',
                  message:
                      'Add guests to start check-in, tag assignment, and live seating.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: 'Search guests',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: _searchController.clear,
                icon: const Icon(Icons.clear),
              ),
      ),
    );
  }

  Widget _buildCheckInFilter() {
    return SegmentedButton<_GuestRosterCheckInFilter>(
      segments: const [
        ButtonSegment(
          value: _GuestRosterCheckInFilter.all,
          label: Text('All'),
        ),
        ButtonSegment(
          value: _GuestRosterCheckInFilter.notCheckedIn,
          label: Text('Pending'),
        ),
        ButtonSegment(
          value: _GuestRosterCheckInFilter.checkedIn,
          label: Text('Checked In'),
        ),
      ],
      selected: {_checkInFilter},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() {
          _checkInFilter = selection.single;
        });
      },
    );
  }

  Widget _buildTournamentFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _buildTournamentFilterChip(
          value: _GuestRosterTournamentFilter.all,
          label: 'All Tournament',
        ),
        _buildTournamentFilterChip(
          value: _GuestRosterTournamentFilter.qualifying,
          label: 'Qualifying',
        ),
        _buildTournamentFilterChip(
          value: _GuestRosterTournamentFilter.qualified,
          label: 'Qualified',
        ),
        _buildTournamentFilterChip(
          value: _GuestRosterTournamentFilter.openPlayOnly,
          label: 'Open Play Only',
        ),
        _buildTournamentFilterChip(
          value: _GuestRosterTournamentFilter.withdrawn,
          label: 'Withdrawn',
        ),
      ],
    );
  }

  Widget _buildTournamentFilterChip({
    required _GuestRosterTournamentFilter value,
    required String label,
  }) {
    return ChoiceChip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      selected: _tournamentFilter == value,
      onSelected: (_) {
        setState(() {
          _tournamentFilter = value;
        });
      },
    );
  }

  bool _matchesCheckInFilter(EventGuestRecord guest) {
    return switch (_checkInFilter) {
      _GuestRosterCheckInFilter.all => true,
      _GuestRosterCheckInFilter.notCheckedIn => !guest.isCheckedIn,
      _GuestRosterCheckInFilter.checkedIn => guest.isCheckedIn,
    };
  }

  bool _matchesTournamentFilter(EventGuestRecord guest) {
    return switch (_tournamentFilter) {
      _GuestRosterTournamentFilter.all => true,
      _GuestRosterTournamentFilter.qualifying =>
        guest.tournamentStatus == EventTournamentStatus.qualifying,
      _GuestRosterTournamentFilter.qualified =>
        guest.tournamentStatus == EventTournamentStatus.qualified,
      _GuestRosterTournamentFilter.openPlayOnly =>
        guest.tournamentStatus == EventTournamentStatus.openPlayOnly,
      _GuestRosterTournamentFilter.withdrawn =>
        guest.tournamentStatus == EventTournamentStatus.withdrawn,
    };
  }

  bool _matchesSearch(EventGuestRecord guest, String searchQuery) {
    if (searchQuery.isEmpty) {
      return true;
    }

    final searchableValues = [
      guest.displayName,
      guest.normalizedName,
      guest.phoneE164,
      guest.emailLower,
      guest.instagramHandle,
    ];

    return searchableValues.whereType<String>().any(
          (value) => value.toLowerCase().contains(searchQuery),
        );
  }

  List<Widget> _buildGuestSection(
    BuildContext context, {
    required String title,
    required List<EventGuestRecord> guests,
  }) {
    if (guests.isEmpty) {
      return const [];
    }

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          '$title (${guests.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      for (final guest in guests) _buildGuestCard(context, guest),
      const SizedBox(height: 8),
    ];
  }

  Widget _buildGuestCard(BuildContext context, EventGuestRecord guest) {
    return Card(
      child: InkWell(
        onTap: () => _openGuestDetail(guest),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      key: ValueKey('guest-row-${guest.id}'),
                      guest.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (_hasOverflowActions(guest)) _buildOverflowMenu(guest),
                ],
              ),
              const SizedBox(height: _guestCardSectionGap),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip(
                    label: _coverStatusLabel(guest.coverStatus),
                    tone: _coverStatusTone(guest.coverStatus),
                  ),
                  StatusChip(
                    label: _tournamentStatusLabel(guest.tournamentStatus),
                    tone: _tournamentStatusTone(guest.tournamentStatus),
                  ),
                ],
              ),
              const SizedBox(height: _guestCardSectionGap),
              Text(
                _rowSummary(guest),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: _guestCardSectionGap),
              _buildQuickActionsForGuest(guest),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _primaryActionForGuest(EventGuestRecord guest) {
    final hasTag = _controller.activeTagAssignments.containsKey(guest.id);
    final isSubmitting = _controller.isSubmittingGuest(guest.id);

    if (!guest.isCheckedIn) {
      return FilledButton(
        onPressed: isSubmitting ? null : () => _checkInAndAssign(guest),
        child: const Text('Check In & Tag'),
      );
    }

    if (!hasTag) {
      return FilledButton(
        onPressed: isSubmitting ? null : () => _assignTag(guest),
        child: const Text('Assign Tag'),
      );
    }

    return switch (guest.tournamentStatus) {
      EventTournamentStatus.openPlayOnly => FilledButton(
          onPressed: isSubmitting
              ? null
              : () => _updateTournamentStatus(
                    guest,
                    EventTournamentStatus.qualifying,
                  ),
          child: const Text('Mark Qualifying'),
        ),
      EventTournamentStatus.qualifying => FilledButton(
          onPressed: isSubmitting
              ? null
              : () => _updateTournamentStatus(
                    guest,
                    EventTournamentStatus.qualified,
                  ),
          child: const Text('Mark Qualified'),
        ),
      EventTournamentStatus.qualified => null,
      EventTournamentStatus.withdrawn => null,
    };
  }

  bool _hasOverflowActions(EventGuestRecord guest) {
    if (!guest.isEligibleForPlayerTagAssignment) {
      return true;
    }

    return _overflowActionsForGuest(guest).isNotEmpty;
  }

  List<_GuestRosterOverflowAction> _overflowActionsForGuest(
    EventGuestRecord guest,
  ) {
    if (!guest.isEligibleForPlayerTagAssignment) {
      return const [_GuestRosterOverflowAction.markPaidManually];
    }

    final actions = <_GuestRosterOverflowAction>[
      _GuestRosterOverflowAction.addCoverEntry,
    ];

    switch (guest.tournamentStatus) {
      case EventTournamentStatus.openPlayOnly:
        actions.addAll(const [
          _GuestRosterOverflowAction.markQualified,
          _GuestRosterOverflowAction.withdraw,
        ]);
      case EventTournamentStatus.qualifying:
        actions.addAll(const [
          _GuestRosterOverflowAction.moveToOpenPlayOnly,
          _GuestRosterOverflowAction.withdraw,
        ]);
      case EventTournamentStatus.qualified:
        actions.addAll(const [
          _GuestRosterOverflowAction.moveToOpenPlayOnly,
          _GuestRosterOverflowAction.withdraw,
        ]);
      case EventTournamentStatus.withdrawn:
        actions.addAll(const [
          _GuestRosterOverflowAction.markQualifying,
          _GuestRosterOverflowAction.markQualified,
          _GuestRosterOverflowAction.moveToOpenPlayOnly,
        ]);
    }

    return actions;
  }

  String _overflowActionLabel(_GuestRosterOverflowAction action) {
    return switch (action) {
      _GuestRosterOverflowAction.markPaidManually => 'Mark Paid Manually',
      _GuestRosterOverflowAction.addCoverEntry => 'Add Cover Entry',
      _GuestRosterOverflowAction.markQualifying => 'Mark Qualifying',
      _GuestRosterOverflowAction.markQualified => 'Mark Qualified',
      _GuestRosterOverflowAction.moveToOpenPlayOnly => 'Move to Open Play Only',
      _GuestRosterOverflowAction.withdraw => 'Withdraw',
    };
  }

  void _handleOverflowAction(
    EventGuestRecord guest,
    _GuestRosterOverflowAction action,
  ) {
    switch (action) {
      case _GuestRosterOverflowAction.markPaidManually:
        _markPaid(guest);
      case _GuestRosterOverflowAction.addCoverEntry:
        _addCoverEntry(guest);
      case _GuestRosterOverflowAction.markQualifying:
        _updateTournamentStatus(guest, EventTournamentStatus.qualifying);
      case _GuestRosterOverflowAction.markQualified:
        _updateTournamentStatus(guest, EventTournamentStatus.qualified);
      case _GuestRosterOverflowAction.moveToOpenPlayOnly:
        _updateTournamentStatus(guest, EventTournamentStatus.openPlayOnly);
      case _GuestRosterOverflowAction.withdraw:
        _updateTournamentStatus(guest, EventTournamentStatus.withdrawn);
    }
  }

  Widget _buildPrimaryActionForGuest(EventGuestRecord guest) {
    final primaryAction = _primaryActionForGuest(guest);
    if (primaryAction == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: primaryAction,
    );
  }

  Widget _buildQuickActionsForGuest(EventGuestRecord guest) {
    final isSubmitting = _controller.isSubmittingGuest(guest.id);
    if (!guest.isEligibleForPlayerTagAssignment) {
      return Row(
        children: [
          Expanded(
            flex: 5,
            child: FilledButton(
              style: _compactActionButtonStyle(),
              onPressed: isSubmitting ? null : () => _addCoverEntry(guest),
              child: _singleLineButtonLabel('Add Cover Entry'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: OutlinedButton(
              style: _compactActionButtonStyle(),
              onPressed: isSubmitting ? null : () => _markComped(guest),
              child: _singleLineButtonLabel('Mark Comped'),
            ),
          ),
        ],
      );
    }

    return _buildPrimaryActionForGuest(guest);
  }

  Widget _buildOverflowMenu(EventGuestRecord guest) {
    final isSubmitting = _controller.isSubmittingGuest(guest.id);
    final actions = _overflowActionsForGuest(guest);

    return SizedBox.square(
      dimension: 32,
      child: PopupMenuButton<_GuestRosterOverflowAction>(
        enabled: !isSubmitting,
        padding: EdgeInsets.zero,
        iconSize: 20,
        splashRadius: 18,
        tooltip: 'More actions for ${guest.displayName}',
        onSelected: (action) => _handleOverflowAction(guest, action),
        itemBuilder: (context) => [
          for (final action in actions)
            PopupMenuItem(
              value: action,
              child: Text(_overflowActionLabel(action)),
            ),
        ],
        icon: const Icon(Icons.more_horiz),
      ),
    );
  }

  ButtonStyle _compactActionButtonStyle() {
    return ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(0, 44)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 12),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _singleLineButtonLabel(String label) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }

  String _coverStatusLabel(CoverStatus status) {
    return switch (status) {
      CoverStatus.unpaid => 'Unpaid',
      CoverStatus.paid => 'Paid',
      CoverStatus.partial => 'Partial',
      CoverStatus.comped => 'Comped',
      CoverStatus.refunded => 'Refunded',
    };
  }

  String _tournamentStatusLabel(EventTournamentStatus status) {
    return switch (status) {
      EventTournamentStatus.openPlayOnly => 'Open Play Only',
      EventTournamentStatus.qualifying => 'Qualifying',
      EventTournamentStatus.qualified => 'Qualified',
      EventTournamentStatus.withdrawn => 'Withdrawn',
    };
  }

  StatusChipTone _tournamentStatusTone(EventTournamentStatus status) {
    return switch (status) {
      EventTournamentStatus.openPlayOnly => StatusChipTone.neutral,
      EventTournamentStatus.qualifying => StatusChipTone.warning,
      EventTournamentStatus.qualified => StatusChipTone.success,
      EventTournamentStatus.withdrawn => StatusChipTone.neutral,
    };
  }

  StatusChipTone _coverStatusTone(CoverStatus status) {
    return switch (status) {
      CoverStatus.paid => StatusChipTone.success,
      CoverStatus.comped => StatusChipTone.success,
      CoverStatus.partial => StatusChipTone.warning,
      CoverStatus.unpaid => StatusChipTone.warning,
      CoverStatus.refunded => StatusChipTone.neutral,
    };
  }

  String _rowSummary(EventGuestRecord guest) {
    final assignment = _controller.activeTagAssignments[guest.id];
    if (guest.isCheckedIn &&
        guest.isEligibleForPlayerTagAssignment &&
        assignment != null) {
      return 'Ready to Play - ${_tagSummary(assignment)}';
    }
    if (!guest.isEligibleForPlayerTagAssignment) {
      return 'Needs payment or comp before tag assignment';
    }
    if (!guest.isCheckedIn) {
      return 'Ready for check-in';
    }
    if (assignment == null) {
      return 'Needs player tag';
    }
    return 'Operational status available';
  }

  String _tagSummary(GuestTagAssignmentSummary assignment) {
    final label = assignment.tag.displayLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return 'Tag $label';
    }
    return 'UID ${_shortUid(assignment.tag.uidHex)}';
  }

  String _shortUid(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.length <= 12) {
      return normalizedUid;
    }
    return '${normalizedUid.substring(0, 12)}...';
  }

  String _formatActionError(Object exception) {
    final message = exception.toString();
    const prefix = 'Bad state: ';
    if (message.startsWith(prefix)) {
      return message.substring(prefix.length);
    }
    return message;
  }
}
