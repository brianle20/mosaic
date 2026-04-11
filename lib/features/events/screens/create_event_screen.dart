import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_form_controller.dart';
import 'package:mosaic/features/events/models/event_form_draft.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({
    super.key,
    required this.eventRepository,
    this.onCreated,
  });

  final EventRepository eventRepository;
  final ValueChanged<EventRecord>? onCreated;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _venueNameController = TextEditingController();
  final _venueAddressController = TextEditingController();
  final _coverChargeController = TextEditingController(text: '0');
  final _prizeBudgetController = TextEditingController(text: '0');
  late final EventFormController _controller;

  String _timezone = 'America/Los_Angeles';
  final DateTime _startsAt = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _controller = EventFormController(eventRepository: widget.eventRepository)
      ..addListener(_handleUpdate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _venueNameController.dispose();
    _venueAddressController.dispose();
    _coverChargeController.dispose();
    _prizeBudgetController.dispose();
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

  EventFormDraft _buildDraft() {
    return EventFormDraft(
      title: _titleController.text,
      timezone: _timezone,
      venueName: _venueNameController.text,
      venueAddress: _venueAddressController.text,
      coverChargeCents: int.tryParse(_coverChargeController.text) ?? -1,
      prizeBudgetCents: int.tryParse(_prizeBudgetController.text) ?? -1,
      startsAt: _startsAt,
    );
  }

  Future<void> _submit() async {
    final draft = _buildDraft();
    setState(() {});
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final event = await _controller.submit(draft);
    if (!mounted || event == null) {
      return;
    }

    widget.onCreated?.call(event);
    if (widget.onCreated == null) {
      Navigator.of(context).pushReplacementNamed(
        AppRouter.eventDashboardRoute,
        arguments: EventDashboardArgs(eventId: event.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _controller.isSubmitting ? null : _submit,
          child: Text(_controller.isSubmitting ? 'Saving...' : 'Save Event'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (_) => _buildDraft().titleError,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _timezone,
              decoration: const InputDecoration(labelText: 'Timezone'),
              onChanged: (value) => _timezone = value,
              validator: (_) => _buildDraft().timezoneError,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Starts At'),
              subtitle: Text(_startsAt.toLocal().toString()),
            ),
            TextFormField(
              controller: _venueNameController,
              decoration: const InputDecoration(labelText: 'Venue Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _venueAddressController,
              decoration: const InputDecoration(labelText: 'Venue Address'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _coverChargeController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Cover Charge (cents)'),
              validator: (_) => _buildDraft().coverChargeError,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _prizeBudgetController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Prize Budget (cents)'),
              validator: (_) => _buildDraft().prizeBudgetError,
            ),
            if (_controller.submitError != null) ...[
              const SizedBox(height: 12),
              Text(_controller.submitError!),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
