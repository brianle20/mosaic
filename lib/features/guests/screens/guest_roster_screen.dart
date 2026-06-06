import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';
import 'package:mosaic/features/checkin/screens/add_cover_entry_screen.dart';
import 'package:mosaic/features/guests/controllers/guest_roster_controller.dart';
import 'package:mosaic/widgets/empty_state_card.dart';
import 'package:mosaic/widgets/status_chip.dart';

enum _GuestRosterOverflowAction {
  markPaidManually,
  addCoverEntry,
  moveToOpenPlayOnly,
  withdraw,
  removeGuest,
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
    this.canCheckIn = true,
    this.canManageGuests = true,
    this.canManageCover = true,
    this.canManageTournamentStatus = true,
    required this.guestRepository,
  });

  final String eventId;
  final String eventTitle;
  final int eventCoverChargeCents;
  final bool canCheckIn;
  final bool canManageGuests;
  final bool canManageCover;
  final bool canManageTournamentStatus;
  final GuestRepository guestRepository;

  @override
  State<GuestRosterScreen> createState() => _GuestRosterScreenState();
}

class _GuestRosterScreenState extends State<GuestRosterScreen> {
  late final GuestRosterController _controller;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  _GuestRosterCheckInFilter _checkInFilter = _GuestRosterCheckInFilter.all;
  _GuestRosterTournamentFilter _tournamentFilter =
      _GuestRosterTournamentFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _searchFocusNode.addListener(_handleSearchChanged);
    _controller = GuestRosterController(guestRepository: widget.guestRepository)
      ..addListener(_handleUpdate)
      ..load(widget.eventId);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _searchFocusNode
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
    if (!widget.canManageGuests) {
      return;
    }
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
        canCheckIn: widget.canCheckIn,
        canManageGuests: widget.canManageGuests,
        canManageCover: widget.canManageCover,
      ),
    );
    if (!mounted) {
      return;
    }
    await _controller.load(widget.eventId);
  }

  Future<void> _markPaid(EventGuestRecord guest) async {
    if (!widget.canManageCover) {
      return;
    }
    await _runQuickAction(
      () => _controller.markPaid(guest.id),
      successMessage: '${guest.displayName} is now marked paid.',
    );
  }

  Future<void> _markComped(EventGuestRecord guest) async {
    if (!widget.canManageCover) {
      return;
    }
    await _runQuickAction(
      () => _controller.markComped(guest.id),
      successMessage: '${guest.displayName} is now marked comped.',
    );
  }

  Future<void> _checkInGuest(EventGuestRecord guest) async {
    if (!widget.canCheckIn) {
      return;
    }
    final status = guest.tournamentStatus;
    if (status == EventTournamentStatus.withdrawn) {
      return;
    }
    await _runQuickAction(
      () => _controller.checkInForPlayMode(
        guestId: guest.id,
        status: status,
      ),
      successMessage:
          '${guest.displayName} is checked in: ${_checkInFeedbackLabel(status)}.',
    );
  }

  Future<void> _updateTournamentStatus(
    EventGuestRecord guest,
    EventTournamentStatus status,
  ) async {
    if (!widget.canManageTournamentStatus) {
      return;
    }
    await _runQuickAction(
      () => _controller.updateTournamentStatus(
        guestId: guest.id,
        status: status,
      ),
      successMessage:
          '${guest.displayName} is now ${_tournamentStatusStatusLabel(status, isCheckedIn: guest.isCheckedIn).toLowerCase()}.',
    );
  }

  Future<void> _qualifyCheckedInConsidered(Set<String> guestIds) async {
    if (!widget.canManageTournamentStatus) {
      return;
    }
    try {
      final count = await _controller.qualifyCheckedInConsidered(
        guestIds: guestIds,
      );
      if (!mounted || count == 0) {
        return;
      }
      final suffix = count == 1 ? 'guest' : 'guests';
      _showMessage('Qualified $count considered $suffix.');
    } catch (exception) {
      if (!mounted) {
        return;
      }
      _showMessage(_formatActionError(exception));
    }
  }

  Future<void> _confirmRemoveGuest(EventGuestRecord guest) async {
    if (!widget.canManageGuests) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${guest.displayName}?'),
        content: const Text(
          'Remove this guest from the event? This is only for accidental adds and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _runQuickAction(
      () => _controller.removeGuest(guest.id),
      successMessage: '${guest.displayName} was removed.',
    );
  }

  Future<void> _addCoverEntry(EventGuestRecord guest) async {
    if (!widget.canManageCover) {
      return;
    }
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
    final checkedInConsideredGuestIds = checkedInGuests
        .where(_isCheckedInConsideredGuest)
        .map((guest) => guest.id)
        .toSet();
    final isBulkQualifying = _controller.isQualifyingCheckedInConsidered;

    return Scaffold(
      appBar: AppBar(title: const Text('Guests')),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: () => _controller.load(widget.eventId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.canManageGuests) ...[
              FilledButton.icon(
                style: _topActionButtonStyle(),
                onPressed: _openAddGuest,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Guest'),
              ),
              const SizedBox(height: 6),
            ],
            if (widget.canManageTournamentStatus &&
                checkedInConsideredGuestIds.isNotEmpty) ...[
              FilledButton.icon(
                style: _topActionButtonStyle(),
                onPressed: isBulkQualifying
                    ? null
                    : () => _qualifyCheckedInConsidered(
                          checkedInConsideredGuestIds,
                        ),
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('Qualify Checked-In Considered'),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 12),
            Text(widget.eventTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
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
                  message: 'Add guests to start check-in and live seating.',
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
      focusNode: _searchFocusNode,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _searchFocusNode.unfocus(),
      decoration: InputDecoration(
        labelText: 'Search guests',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _buildSearchSuffixIcon(),
      ),
    );
  }

  Widget? _buildSearchSuffixIcon() {
    final hasSearchText = _searchController.text.isNotEmpty;
    final isFocused = _searchFocusNode.hasFocus;
    if (!hasSearchText && !isFocused) {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasSearchText)
          IconButton(
            tooltip: 'Clear search',
            onPressed: _searchController.clear,
            icon: const Icon(Icons.clear),
          ),
        if (isFocused)
          IconButton(
            tooltip: 'Dismiss keyboard',
            onPressed: _searchFocusNode.unfocus,
            icon: const Icon(Icons.keyboard_hide),
          ),
      ],
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
          label: 'Considered',
        ),
        _buildTournamentFilterChip(
          value: _GuestRosterTournamentFilter.qualified,
          label: 'Qualified',
        ),
        _buildTournamentFilterChip(
          value: _GuestRosterTournamentFilter.openPlayOnly,
          label: 'Not Playing Tournament',
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
                    label: _tournamentStatusLabel(guest),
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

  bool _hasOverflowActions(EventGuestRecord guest) {
    return _overflowActionsForGuest(guest).isNotEmpty;
  }

  List<_GuestRosterOverflowAction> _overflowActionsForGuest(
    EventGuestRecord guest,
  ) {
    if (!guest.isEligibleForPlayerTagAssignment) {
      final actions = <_GuestRosterOverflowAction>[];
      if (widget.canManageCover) {
        actions.add(_GuestRosterOverflowAction.markPaidManually);
      }
      if (_canRemoveGuest(guest)) {
        actions.add(_GuestRosterOverflowAction.removeGuest);
      }
      return actions;
    }

    final actions = <_GuestRosterOverflowAction>[];
    if (widget.canManageCover) {
      actions.add(_GuestRosterOverflowAction.addCoverEntry);
    }
    if (_canRemoveGuest(guest)) {
      actions.add(_GuestRosterOverflowAction.removeGuest);
    }

    if (!widget.canManageTournamentStatus) {
      return actions;
    }

    switch (guest.tournamentStatus) {
      case EventTournamentStatus.openPlayOnly:
        actions.addAll(const [
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
          _GuestRosterOverflowAction.moveToOpenPlayOnly,
        ]);
    }

    return actions;
  }

  String _overflowActionLabel(_GuestRosterOverflowAction action) {
    return switch (action) {
      _GuestRosterOverflowAction.markPaidManually => 'Mark Paid Manually',
      _GuestRosterOverflowAction.addCoverEntry => 'Add Cover Entry',
      _GuestRosterOverflowAction.moveToOpenPlayOnly => 'Not Playing Tournament',
      _GuestRosterOverflowAction.withdraw => 'Withdraw',
      _GuestRosterOverflowAction.removeGuest => 'Remove Guest',
    };
  }

  bool _canRemoveGuest(EventGuestRecord guest) {
    return widget.canManageGuests &&
        _controller.hasLoadedActiveTagAssignments &&
        guest.attendanceStatus == AttendanceStatus.expected &&
        guest.checkedInAt == null &&
        guest.coverStatus == CoverStatus.unpaid &&
        !guest.isComped &&
        !guest.hasScoredPlay &&
        !_controller.activeTagAssignments.containsKey(guest.id);
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
      case _GuestRosterOverflowAction.moveToOpenPlayOnly:
        _updateTournamentStatus(guest, EventTournamentStatus.openPlayOnly);
      case _GuestRosterOverflowAction.withdraw:
        _updateTournamentStatus(guest, EventTournamentStatus.withdrawn);
      case _GuestRosterOverflowAction.removeGuest:
        _confirmRemoveGuest(guest);
    }
  }

  Widget _buildQuickActionsForGuest(EventGuestRecord guest) {
    final isSubmitting = _controller.isSubmittingGuest(guest.id);
    if (!guest.isEligibleForPlayerTagAssignment) {
      if (!widget.canManageCover) {
        return const SizedBox.shrink();
      }
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

    if (!guest.isCheckedIn) {
      if (!widget.canCheckIn ||
          guest.tournamentStatus == EventTournamentStatus.withdrawn) {
        return const SizedBox.shrink();
      }
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: _compactActionButtonStyle(),
          onPressed: isSubmitting ? null : () => _checkInGuest(guest),
          child: _singleLineButtonLabel(
            _checkInActionLabel(guest.tournamentStatus),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
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

  ButtonStyle _topActionButtonStyle() {
    return ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size.fromHeight(40)),
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

  bool _isCheckedInConsideredGuest(EventGuestRecord guest) {
    return guest.isCheckedIn &&
        guest.tournamentStatus == EventTournamentStatus.qualifying;
  }

  String _tournamentStatusLabel(EventGuestRecord guest) {
    return _tournamentStatusStatusLabel(
      guest.tournamentStatus,
      isCheckedIn: guest.isCheckedIn,
    );
  }

  String _tournamentStatusStatusLabel(
    EventTournamentStatus status, {
    required bool isCheckedIn,
  }) {
    return switch (status) {
      EventTournamentStatus.openPlayOnly => 'Not Playing Tournament',
      EventTournamentStatus.qualifying => 'Considered',
      EventTournamentStatus.qualified =>
        isCheckedIn ? 'Qualified' : 'Prequalified',
      EventTournamentStatus.withdrawn => 'Withdrawn',
    };
  }

  String _checkInActionLabel(EventTournamentStatus status) {
    return switch (status) {
      EventTournamentStatus.qualified => 'Check In: Prequalified',
      EventTournamentStatus.qualifying => 'Check In: Considered',
      EventTournamentStatus.openPlayOnly => 'Check In: Not Playing Tournament',
      EventTournamentStatus.withdrawn => 'Check In',
    };
  }

  String _checkInFeedbackLabel(EventTournamentStatus status) {
    return switch (status) {
      EventTournamentStatus.qualified => 'prequalified',
      EventTournamentStatus.qualifying => 'considered',
      EventTournamentStatus.openPlayOnly => 'not playing tournament',
      EventTournamentStatus.withdrawn => 'withdrawn',
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
    if (guest.tournamentStatus == EventTournamentStatus.withdrawn) {
      return 'Withdrawn from tournament play';
    }
    if (!guest.isEligibleForPlayerTagAssignment) {
      return 'Needs payment or comp';
    }
    if (!guest.isCheckedIn) {
      return 'Ready for check-in';
    }
    return switch (guest.tournamentStatus) {
      EventTournamentStatus.openPlayOnly =>
        'Checked in; not playing tournament',
      EventTournamentStatus.qualifying => 'Checked in as considered',
      EventTournamentStatus.qualified => 'Qualified for tournament play',
      EventTournamentStatus.withdrawn => 'Withdrawn from tournament play',
    };
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
