import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/models/event_form_formatters.dart';
import 'package:mosaic/features/guests/controllers/bulk_saved_guest_controller.dart';
import 'package:mosaic/widgets/empty_state_card.dart';
import 'package:mosaic/widgets/money_text_form_field.dart';

const bulkSavedGuestSearchFieldKey = Key('bulk-saved-guest-search-field');
const bulkSavedGuestTournamentStatusFieldKey =
    Key('bulk-saved-guest-tournament-status-field');
const bulkSavedGuestCoverStatusFieldKey =
    Key('bulk-saved-guest-cover-status-field');
const bulkSavedGuestCoverAmountFieldKey =
    Key('bulk-saved-guest-cover-amount-field');

class BulkSavedGuestScreen extends StatefulWidget {
  const BulkSavedGuestScreen({
    super.key,
    required this.eventId,
    required this.eventCoverChargeCents,
    required this.existingGuests,
    required this.guestRepository,
    this.canManageTournamentStatus = true,
    this.canManageCover = true,
  });

  final String eventId;
  final int eventCoverChargeCents;
  final List<EventGuestRecord> existingGuests;
  final GuestRepository guestRepository;
  final bool canManageTournamentStatus;
  final bool canManageCover;

  @override
  State<BulkSavedGuestScreen> createState() => _BulkSavedGuestScreenState();
}

class _BulkSavedGuestScreenState extends State<BulkSavedGuestScreen> {
  final _formKey = GlobalKey<FormState>();
  late final BulkSavedGuestController _controller;
  late final TextEditingController _searchController;
  late final TextEditingController _coverAmountController;

  @override
  void initState() {
    super.initState();
    _controller = BulkSavedGuestController(
      guestRepository: widget.guestRepository,
      eventId: widget.eventId,
      eventCoverChargeCents: widget.eventCoverChargeCents,
      existingGuests: widget.existingGuests,
    )..addListener(_handleControllerUpdate);
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _coverAmountController = TextEditingController(
      text: formatMoneyCents(widget.eventCoverChargeCents),
    );
    _controller.loadProfiles();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerUpdate)
      ..dispose();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _coverAmountController.dispose();
    super.dispose();
  }

  void _handleControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleSearchChanged() {
    _controller.searchQuery = _searchController.text;
  }

  Future<void> _submit() async {
    if (_controller.selectedCount == 0 || _controller.isSubmitting) {
      return;
    }

    if (widget.canManageCover && !(_formKey.currentState?.validate() ?? true)) {
      return;
    }

    final result = await _controller.addSelectedGuests();
    if (!mounted) {
      return;
    }

    if (result.hasPartialSuccess) {
      _showMessage(_partialSuccessMessage(result));
      return;
    }

    if (result.addedCount > 0) {
      Navigator.of(context).pop(result.addedCount);
      return;
    }

    if (result.isCompleteFailure) {
      _showMessage('Could not add selected guests.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _partialSuccessMessage(BulkSavedGuestAddResult result) {
    final addedLabel = result.addedCount == 1 ? 'guest' : 'guests';
    return 'Added ${result.addedCount} $addedLabel. '
        '${result.failedCount} could not be added.';
  }

  void _handleCoverAmountChanged(String value) {
    final parsed = parseMoneyAmount(value);
    if (parsed.cents case final cents?) {
      _controller.coverAmountCents = cents;
    }
  }

  String? _moneyFieldError(String value) {
    final result = parseMoneyAmount(value);
    final error = result.error;
    if (error == null) {
      return null;
    }

    return switch (error) {
      MoneyInputError.invalid => 'Enter a valid amount.',
      MoneyInputError.negative => 'Amount must be zero or more.',
      MoneyInputError.tooManyDecimalPlaces =>
        'Use dollars and cents, like \$15 or \$15.50.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add From Saved Guests')),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: _controller.loadProfiles,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: bulkSavedGuestSearchFieldKey,
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search saved guests',
                  prefixIcon: Icon(Icons.search),
                ),
                textInputAction: TextInputAction.search,
              ),
            ),
            Expanded(child: _buildProfileList()),
          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _buildProfileList() {
    final profiles = _controller.filteredProfiles;
    if (_controller.profiles.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: EmptyStateCard(
            icon: Icons.people_outline,
            title: 'No saved guests yet',
            message:
                'Create guests from the roster first, then they will appear here for future events.',
          ),
        ),
      );
    }

    if (profiles.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: EmptyStateCard(
            icon: Icons.search_off,
            title: 'No matching saved guests',
            message: 'No saved guests match this search.',
          ),
        ),
      );
    }

    final allAdded = _controller.profiles.every(
      (profile) => _controller.isAlreadyAdded(profile.id),
    );

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      itemCount: profiles.length + (allAdded ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (allAdded && index == 0) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: EmptyStateCard(
              icon: Icons.check_circle_outline,
              title: 'All saved guests added',
              message: 'All saved guests are already on this event.',
            ),
          );
        }

        final profile = profiles[index - (allAdded ? 1 : 0)];
        return _SavedGuestProfileTile(
          profile: profile,
          isAlreadyAdded: _controller.isAlreadyAdded(profile.id),
          isSelected: _controller.isSelected(profile.id),
          onTap: () => _controller.toggleSelection(profile.id),
        );
      },
    );
  }

  Widget _buildFooter() {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedCount = _controller.selectedCount;
    final guestLabel = selectedCount == 1 ? 'Guest' : 'Guests';

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bulk defaults',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                if (widget.canManageTournamentStatus) ...[
                  DropdownButtonFormField<EventTournamentStatus>(
                    key: bulkSavedGuestTournamentStatusFieldKey,
                    initialValue: _controller.tournamentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Tournament Status',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: EventTournamentStatus.qualified,
                        child: Text('Prequalified'),
                      ),
                      DropdownMenuItem(
                        value: EventTournamentStatus.qualifying,
                        child: Text('Considered'),
                      ),
                      DropdownMenuItem(
                        value: EventTournamentStatus.openPlayOnly,
                        child: Text('Not Playing'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _controller.tournamentStatus = value;
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.canManageCover) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<CoverStatus>(
                          key: bulkSavedGuestCoverStatusFieldKey,
                          initialValue: _controller.coverStatus,
                          decoration: const InputDecoration(
                            labelText: 'Cover Status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: CoverStatus.unpaid,
                              child: Text('unpaid'),
                            ),
                            DropdownMenuItem(
                              value: CoverStatus.paid,
                              child: Text('paid'),
                            ),
                            DropdownMenuItem(
                              value: CoverStatus.comped,
                              child: Text('comped'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              _controller.coverStatus = value;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MoneyTextFormField(
                          fieldKey: bulkSavedGuestCoverAmountFieldKey,
                          controller: _coverAmountController,
                          labelText: 'Cover Amount',
                          validator: _moneyFieldError,
                          onChanged: _handleCoverAmountChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$selectedCount selected',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: selectedCount == 0 || _controller.isSubmitting
                          ? null
                          : _submit,
                      icon: _controller.isSubmitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1),
                      label: Text('Add $selectedCount $guestLabel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedGuestProfileTile extends StatelessWidget {
  const _SavedGuestProfileTile({
    required this.profile,
    required this.isAlreadyAdded,
    required this.isSelected,
    required this.onTap,
  });

  final GuestProfileRecord profile;
  final bool isAlreadyAdded;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor =
        isAlreadyAdded ? colorScheme.onSurfaceVariant : null;

    return ListTile(
      key: ValueKey<String>('bulk-saved-guest-row-${profile.id}'),
      enabled: !isAlreadyAdded,
      onTap: isAlreadyAdded ? null : onTap,
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isSelected
            ? colorScheme.primary
            : isAlreadyAdded
                ? colorScheme.outline
                : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        profile.displayName,
        style: TextStyle(color: foregroundColor),
      ),
      subtitle: _SavedGuestProfileSubtitle(
        profile: profile,
        foregroundColor: foregroundColor,
      ),
      trailing: isAlreadyAdded
          ? Text(
              'Already added',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            )
          : null,
    );
  }
}

class _SavedGuestProfileSubtitle extends StatelessWidget {
  const _SavedGuestProfileSubtitle({
    required this.profile,
    required this.foregroundColor,
  });

  final GuestProfileRecord profile;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (profile.publicDisplayName?.trim().isNotEmpty ?? false)
        profile.publicDisplayName!.trim(),
      if (_contactLine(profile).isNotEmpty) _contactLine(profile),
    ];

    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color:
              foregroundColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines) Text(line, style: textStyle),
      ],
    );
  }

  String _contactLine(GuestProfileRecord profile) {
    final parts = <String>[
      if (profile.phoneE164?.trim().isNotEmpty ?? false)
        profile.phoneE164!.trim(),
      if (profile.emailLower?.trim().isNotEmpty ?? false)
        profile.emailLower!.trim(),
      if (profile.instagramHandle?.trim().isNotEmpty ?? false)
        '@${profile.instagramHandle!.trim()}',
    ];
    return parts.join(' · ');
  }
}
