import 'package:flutter/material.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/models/event_form_formatters.dart';
import 'package:mosaic/features/guests/controllers/guest_form_controller.dart';
import 'package:mosaic/features/guests/models/guest_contact_formatters.dart';
import 'package:mosaic/features/guests/models/guest_form_draft.dart';

const guestNameFieldKey = Key('guest-name-field');
const guestCoverAmountFieldKey = Key('guest-cover-amount-field');

class GuestFormScreen extends StatefulWidget {
  const GuestFormScreen({
    super.key,
    required this.eventId,
    required this.existingGuests,
    required this.guestRepository,
    this.defaultCoverAmountCents = 0,
    this.initialGuest,
    this.onSaved,
  });

  final String eventId;
  final List<EventGuestRecord> existingGuests;
  final EventGuestRecord? initialGuest;
  final GuestRepository guestRepository;
  final int defaultCoverAmountCents;
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
  List<GuestProfileMatch> _profileMatches = const [];
  bool _isLoadingProfileMatches = false;
  int _profileMatchRequestId = 0;

  @override
  void initState() {
    super.initState();
    final guest = widget.initialGuest;
    _nameController = TextEditingController(text: guest?.displayName ?? '');
    _phoneController = TextEditingController(
      text: formatPhoneForDisplay(guest?.phoneE164),
    );
    _emailController = TextEditingController(text: guest?.emailLower ?? '');
    _noteController = TextEditingController(text: guest?.note ?? '');
    _coverAmountController = TextEditingController(
      text: formatMoneyCents(
        guest?.coverAmountCents ?? widget.defaultCoverAmountCents,
      ),
    );
    _coverStatus = guest?.coverStatus ?? CoverStatus.unpaid;
    _controller = GuestFormController(guestRepository: widget.guestRepository)
      ..addListener(_handleUpdate);
    _nameController.addListener(_loadProfileMatches);
    _phoneController.addListener(_loadProfileMatches);
    _emailController.addListener(_loadProfileMatches);
    _loadProfileMatches();
  }

  @override
  void dispose() {
    _nameController.removeListener(_loadProfileMatches);
    _phoneController.removeListener(_loadProfileMatches);
    _emailController.removeListener(_loadProfileMatches);
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
    final coverAmount = parseMoneyAmount(_coverAmountController.text);

    return GuestFormDraft(
      displayName: _nameController.text,
      phoneE164: _phoneController.text,
      email: _emailController.text,
      note: _noteController.text,
      coverAmountCents: coverAmount.cents ?? -1,
      coverStatus: _coverStatus,
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

  Future<void> _loadProfileMatches() async {
    final requestId = ++_profileMatchRequestId;
    final draft = _buildDraft();
    final phoneE164 = draft.phoneE164Value();
    final emailLower = draft.emailLowerValue();
    final normalizedName = draft.normalizedDisplayName();
    if (phoneE164 == null && emailLower == null && normalizedName.isEmpty) {
      if (mounted) {
        setState(() {
          _profileMatches = const [];
          _isLoadingProfileMatches = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingProfileMatches = true;
    });

    final matches = await widget.guestRepository.findGuestProfileMatches(
      GuestProfileLookupInput(
        normalizedName: normalizedName,
        phoneE164: phoneE164,
        emailLower: emailLower,
      ),
    );
    if (!mounted || requestId != _profileMatchRequestId) {
      return;
    }

    setState(() {
      _profileMatches = matches;
      _isLoadingProfileMatches = false;
    });
  }

  GuestProfileMatch? _primaryIdentityMatch() {
    for (final match in _profileMatches) {
      if (match.matchType == GuestProfileMatchType.phone ||
          match.matchType == GuestProfileMatchType.email) {
        return match;
      }
    }

    return null;
  }

  Iterable<GuestProfileMatch> _nameOnlyMatches() {
    final primaryMatchId = _primaryIdentityMatch()?.profile.id;
    return _profileMatches.where(
      (match) =>
          match.matchType == GuestProfileMatchType.name &&
          match.profile.id != primaryMatchId,
    );
  }

  void _applyProfile(GuestProfileRecord profile) {
    _nameController.text = profile.displayName;
    _phoneController.text = formatPhoneForDisplay(profile.phoneE164);
    _emailController.text = profile.emailLower ?? '';
  }

  Widget _buildProfileMatchMessage() {
    final primaryMatch = _primaryIdentityMatch();
    final nameMatches = _nameOnlyMatches().toList(growable: false);
    if (primaryMatch == null &&
        nameMatches.isEmpty &&
        !_isLoadingProfileMatches) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingProfileMatches)
            const Text('Checking saved guests...')
          else if (primaryMatch != null)
            Text('Using existing guest: ${primaryMatch.profile.displayName}')
          else
            for (final match in nameMatches)
              TextButton(
                onPressed: () => _applyProfile(match.profile),
                child: Text('Possible match: ${match.profile.displayName}'),
              ),
        ],
      ),
    );
  }

  Future<bool> _confirmDuplicateGuest(EventGuestRecord duplicateGuest) async {
    final actionLabel =
        widget.initialGuest == null ? 'Add Anyway' : 'Save Anyway';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.initialGuest == null
              ? 'Add duplicate guest?'
              : 'Save duplicate guest?',
        ),
        content: Text(
          '${duplicateGuest.displayName} is already on this event. '
          '${widget.initialGuest == null ? 'Add another' : 'Save this'} guest with the same name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _submit() async {
    final draft = _buildDraft();
    setState(() {});
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final duplicateGuest = draft.duplicateNameMatch(
      widget.existingGuests,
      excludeGuestId: widget.initialGuest?.id,
    );
    if (duplicateGuest != null) {
      final confirmed = await _confirmDuplicateGuest(duplicateGuest);
      if (!mounted || !confirmed) {
        return;
      }
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
      widget.existingGuests,
      excludeGuestId: widget.initialGuest?.id,
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
              key: guestNameFieldKey,
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (_) => _buildDraft().displayNameError,
            ),
            _buildProfileMatchMessage(),
            if (duplicateWarning != null) ...[
              const SizedBox(height: 8),
              Text(duplicateWarning),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
              inputFormatters: const [UsPhoneInputFormatter()],
              validator: (_) => _buildDraft().phoneError,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
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
              key: guestCoverAmountFieldKey,
              controller: _coverAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [MoneyCentsInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Cover Amount',
                prefixText: r'$',
              ),
              validator: (value) => _moneyFieldError(value ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note'),
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
