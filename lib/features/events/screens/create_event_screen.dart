import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_form_controller.dart';
import 'package:mosaic/features/events/models/event_form_draft.dart';
import 'package:mosaic/features/events/models/event_form_formatters.dart';
import 'package:mosaic/widgets/money_text_form_field.dart';

const createEventTitleFieldKey = Key('create-event-title-field');
const createEventStartsTileKey = Key('create-event-starts-tile');
const createEventVenueNameFieldKey = Key('create-event-venue-name-field');
const createEventVenueAddressFieldKey = Key(
  'create-event-venue-address-field',
);
const createEventCoverChargeFieldKey = Key('create-event-cover-charge-field');

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
  final _coverChargeController = TextEditingController(text: '0.00');
  late final EventFormController _controller;

  final String _timezone = 'America/Los_Angeles';
  late DateTime _startsAt;

  @override
  void initState() {
    super.initState();
    _startsAt = defaultEventStartAt(DateTime.now());
    _controller = EventFormController(eventRepository: widget.eventRepository)
      ..addListener(_handleUpdate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _venueNameController.dispose();
    _venueAddressController.dispose();
    _coverChargeController.dispose();
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
    final coverCharge = parseMoneyAmount(_coverChargeController.text);

    return EventFormDraft(
      title: _titleController.text,
      timezone: _timezone,
      venueName: _venueNameController.text,
      venueAddress: _venueAddressController.text,
      coverChargeCents: coverCharge.cents ?? -1,
      startsAt: _startsAt,
    );
  }

  String? _moneyValidationMessage(MoneyInputError error) {
    return switch (error) {
      MoneyInputError.invalid => 'Enter a valid amount.',
      MoneyInputError.negative => 'Amount must be zero or more.',
      MoneyInputError.tooManyDecimalPlaces =>
        'Use dollars and cents, like \$15 or \$15.50.',
    };
  }

  String? _moneyFieldError(String value) {
    final result = parseMoneyAmount(value);
    final error = result.error;
    return error == null ? null : _moneyValidationMessage(error);
  }

  Future<void> _pickStartsAt() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (!mounted || pickedDate == null) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (!mounted || pickedTime == null) {
      return;
    }

    setState(() {
      _startsAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
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
              key: createEventTitleFieldKey,
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (_) => _buildDraft().titleError,
            ),
            const SizedBox(height: 12),
            ListTile(
              key: createEventStartsTileKey,
              contentPadding: EdgeInsets.zero,
              title: const Text('Starts'),
              subtitle: Text(formatEventStart(_startsAt)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickStartsAt,
            ),
            TextFormField(
              key: createEventVenueNameFieldKey,
              controller: _venueNameController,
              decoration: const InputDecoration(labelText: 'Venue Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: createEventVenueAddressFieldKey,
              controller: _venueAddressController,
              decoration: const InputDecoration(labelText: 'Venue Address'),
            ),
            const SizedBox(height: 12),
            MoneyTextFormField(
              fieldKey: createEventCoverChargeFieldKey,
              controller: _coverChargeController,
              labelText: 'Cover Charge',
              validator: _moneyFieldError,
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
