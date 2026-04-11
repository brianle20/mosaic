import 'package:flutter/material.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/guests/controllers/guest_form_controller.dart';
import 'package:mosaic/features/guests/models/guest_form_draft.dart';

class GuestFormScreen extends StatefulWidget {
  const GuestFormScreen({
    super.key,
    required this.eventId,
    required this.existingGuests,
    required this.guestRepository,
    this.initialGuest,
    this.onSaved,
  });

  final String eventId;
  final List<EventGuestRecord> existingGuests;
  final EventGuestRecord? initialGuest;
  final GuestRepository guestRepository;
  final ValueChanged<EventGuestRecord>? onSaved;

  @override
  State<GuestFormScreen> createState() => _GuestFormScreenState();
}

class _GuestFormScreenState extends State<GuestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _noteController;
  late final TextEditingController _coverAmountController;
  late CoverStatus _coverStatus;
  late final GuestFormController _controller;

  @override
  void initState() {
    super.initState();
    final guest = widget.initialGuest;
    _nameController = TextEditingController(text: guest?.displayName ?? '');
    _phoneController = TextEditingController(text: guest?.phoneE164 ?? '');
    _emailController = TextEditingController(text: guest?.emailLower ?? '');
    _noteController = TextEditingController(text: guest?.note ?? '');
    _coverAmountController = TextEditingController(
      text: '${guest?.coverAmountCents ?? 0}',
    );
    _coverStatus = guest?.coverStatus ?? CoverStatus.unpaid;
    _controller = GuestFormController(guestRepository: widget.guestRepository)
      ..addListener(_handleUpdate);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _noteController.dispose();
    _coverAmountController.dispose();
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

  GuestFormDraft _buildDraft() {
    return GuestFormDraft(
      displayName: _nameController.text,
      phoneE164: _phoneController.text,
      email: _emailController.text,
      note: _noteController.text,
      coverAmountCents: int.tryParse(_coverAmountController.text) ?? -1,
      coverStatus: _coverStatus,
    );
  }

  Future<void> _submit() async {
    final draft = _buildDraft();
    setState(() {});
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final savedGuest = await _controller.submit(
      eventId: widget.eventId,
      draft: draft,
      existingGuest: widget.initialGuest,
    );
    if (!mounted || savedGuest == null) {
      return;
    }

    widget.onSaved?.call(savedGuest);
    if (widget.onSaved == null) {
      Navigator.of(context).pop(savedGuest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duplicateWarning = _buildDraft().duplicateNameWarning(
      widget.existingGuests
          .where((guest) => guest.id != widget.initialGuest?.id),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialGuest == null ? 'Add Guest' : 'Edit Guest'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _controller.isSubmitting ? null : _submit,
          child: Text(_controller.isSubmitting ? 'Saving...' : 'Save Guest'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (_) => _buildDraft().displayNameError,
            ),
            if (duplicateWarning != null) ...[
              const SizedBox(height: 8),
              Text(duplicateWarning),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CoverStatus>(
              initialValue: _coverStatus,
              decoration: const InputDecoration(labelText: 'Cover Status'),
              items: CoverStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _coverStatus = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _coverAmountController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Cover Amount (cents)'),
              validator: (_) => _buildDraft().coverAmountError,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note'),
              maxLines: 3,
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
