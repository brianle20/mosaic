import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/staff_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_staff_controller.dart';
import 'package:mosaic/widgets/app_actions.dart';
import 'package:mosaic/widgets/app_chrome.dart';
import 'package:mosaic/widgets/app_surfaces.dart';
import 'package:mosaic/widgets/empty_state_card.dart';
import 'package:mosaic/widgets/status_chip.dart';

class EventStaffScreen extends StatefulWidget {
  const EventStaffScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.staffRepository,
  });

  final String eventId;
  final String eventTitle;
  final StaffRepository staffRepository;

  @override
  State<EventStaffScreen> createState() => _EventStaffScreenState();
}

class _EventStaffScreenState extends State<EventStaffScreen> {
  late final EventStaffController _controller;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  EventStaffRole _role = EventStaffRole.qualificationScorer;

  @override
  void initState() {
    super.initState();
    _controller = EventStaffController(
      staffRepository: widget.staffRepository,
      eventId: widget.eventId,
    )
      ..addListener(_handleUpdate)
      ..load();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleUpdate)
      ..dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveStaff() async {
    final saved = await _controller.upsertStaff(
      email: _emailController.text,
      phoneE164: _phoneController.text,
      displayName: _nameController.text,
      role: _role,
    );
    if (!saved || !mounted) {
      return;
    }
    _emailController.clear();
    _phoneController.clear();
    _nameController.clear();
    setState(() {
      _role = EventStaffRole.qualificationScorer;
    });
  }

  String _roleLabel(EventStaffRole role) {
    return switch (role) {
      EventStaffRole.qualificationScorer => 'Qualification Scorer',
      EventStaffRole.eventScorer => 'Event Scorer',
    };
  }

  String _statusLabel(EventStaffStatus status) {
    return switch (status) {
      EventStaffStatus.active => 'Active',
      EventStaffStatus.disabled => 'Disabled',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SoftHostScaffold(
      title: 'Staff',
      actions: [
        GlassCircleButton(
          visualKey: const ValueKey('eventStaffBackAction'),
          icon: Icons.chevron_left,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: _controller.load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Text(
              widget.eventTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            AppListSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add or Update Staff',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'helper@example.com',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      hintText: '+15551234567',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<EventStaffRole>(
                    segments: [
                      ButtonSegment(
                        value: EventStaffRole.qualificationScorer,
                        label: Text(
                          _roleLabel(EventStaffRole.qualificationScorer),
                        ),
                      ),
                      ButtonSegment(
                        value: EventStaffRole.eventScorer,
                        label: Text(_roleLabel(EventStaffRole.eventScorer)),
                      ),
                    ],
                    selected: {_role},
                    onSelectionChanged: _controller.isSubmitting
                        ? null
                        : (selection) {
                            setState(() {
                              _role = selection.single;
                            });
                          },
                  ),
                  if (_controller.submitError != null) ...[
                    const SizedBox(height: 10),
                    InlineErrorBanner(message: _controller.submitError!),
                  ],
                  const SizedBox(height: 12),
                  HeroActionButton(
                    onPressed: () => _saveStaff(),
                    enabled: !_controller.isSubmitting,
                    icon: Icons.person_add,
                    label: _controller.isSubmitting ? 'Saving' : 'Save Staff',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final membership in _controller.memberships)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppListSurface(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              membership.displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              membership.email ??
                                  membership.phoneE164 ??
                                  'No contact',
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                StatusChip(
                                  label: _roleLabel(membership.role),
                                  tone: StatusChipTone.info,
                                ),
                                StatusChip(
                                  label: _statusLabel(membership.status),
                                  tone: membership.status ==
                                          EventStaffStatus.active
                                      ? StatusChipTone.success
                                      : StatusChipTone.neutral,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (membership.status == EventStaffStatus.active)
                        TextButton(
                          onPressed: _controller.isSubmitting
                              ? null
                              : () => _controller.disableMembership(
                                    membership.id,
                                  ),
                          child: const Text('Disable'),
                        ),
                    ],
                  ),
                ),
              ),
            if (_controller.memberships.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: EmptyStateCard(
                  icon: Icons.people_outline,
                  title: 'No staff yet',
                  message: 'Add scorers who can help run this event.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
