import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/models/event_form_formatters.dart';
import 'package:mosaic/features/guests/controllers/guest_form_controller.dart';
import 'package:mosaic/features/guests/models/guest_contact_formatters.dart';
import 'package:mosaic/features/guests/models/guest_form_draft.dart';
import 'package:mosaic/widgets/money_text_form_field.dart';

const guestNameFieldKey = Key('guest-name-field');
const guestCoverAmountFieldKey = Key('guest-cover-amount-field');
const _profileMatchDebounceDuration = Duration(milliseconds: 400);

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
  late final TextEditingController _instagramController;
  late final TextEditingController _noteController;
  late final TextEditingController _coverAmountController;
  late CoverStatus _coverStatus;
  late final GuestFormController _controller;
  List<GuestProfileMatch> _profileMatches = const [];
  GuestProfileRecord? _selectedProfile;
  Timer? _profileMatchDebounce;
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
    _instagramController = TextEditingController(
      text: formatInstagramHandleForDisplay(guest?.instagramHandle),
    );
    _noteController = TextEditingController(text: guest?.note ?? '');
    _coverAmountController = TextEditingController(
      text: formatMoneyCents(
        guest?.coverAmountCents ?? widget.defaultCoverAmountCents,
      ),
    );
    _coverStatus = guest?.coverStatus ?? CoverStatus.unpaid;
    _controller = GuestFormController(guestRepository: widget.guestRepository)
      ..addListener(_handleUpdate);
    _nameController.addListener(_scheduleProfileMatchLoad);
    _phoneController.addListener(_scheduleProfileMatchLoad);
    _emailController.addListener(_scheduleProfileMatchLoad);
    _instagramController.addListener(_scheduleProfileMatchLoad);
  }

  @override
  void dispose() {
    _profileMatchDebounce?.cancel();
    _nameController.removeListener(_scheduleProfileMatchLoad);
    _phoneController.removeListener(_scheduleProfileMatchLoad);
    _emailController.removeListener(_scheduleProfileMatchLoad);
    _instagramController.removeListener(_scheduleProfileMatchLoad);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _instagramController.dispose();
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
      instagramHandle: _instagramController.text,
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

  void _scheduleProfileMatchLoad() {
    _profileMatchDebounce?.cancel();
    final draft = _buildDraft();
    final selectedProfile = _selectedProfile;
    if (selectedProfile != null &&
        !_draftStillMatchesSelectedProfile(draft, selectedProfile)) {
      _selectedProfile = null;
    }
    if (!_shouldLookupProfileMatches(draft)) {
      _profileMatchRequestId += 1;
      if (mounted) {
        setState(() {
          _profileMatches = const [];
        });
      }
      return;
    }

    _profileMatchDebounce = Timer(
      _profileMatchDebounceDuration,
      _loadProfileMatches,
    );
  }

  bool _draftStillMatchesSelectedProfile(
    GuestFormDraft draft,
    GuestProfileRecord profile,
  ) {
    final phoneE164 = draft.phoneE164Value();
    final emailLower = draft.emailLowerValue();
    final instagramHandle = draft.instagramHandleValue();
    return draft.normalizedDisplayName() == profile.normalizedName ||
        (phoneE164 != null && phoneE164 == profile.phoneE164) ||
        (emailLower != null && emailLower == profile.emailLower) ||
        (instagramHandle != null && instagramHandle == profile.instagramHandle);
  }

  bool _shouldLookupProfileMatches(GuestFormDraft draft) {
    final phoneE164 = draft.phoneE164Value();
    final emailLower = draft.emailLowerValue();
    final instagramHandle = draft.instagramHandleValue();
    final normalizedName = draft.normalizedDisplayName();
    final guest = widget.initialGuest;
    if (guest != null &&
        normalizedName == guest.normalizedName &&
        phoneE164 == guest.phoneE164 &&
        emailLower == guest.emailLower &&
        instagramHandle == guest.instagramHandle) {
      return false;
    }

    return phoneE164 != null ||
        emailLower != null ||
        instagramHandle != null ||
        normalizedName.isNotEmpty;
  }

  Future<void> _loadProfileMatches() async {
    final requestId = ++_profileMatchRequestId;
    final draft = _buildDraft();
    if (!_shouldLookupProfileMatches(draft)) {
      if (mounted) {
        setState(() {
          _profileMatches = const [];
        });
      }
      return;
    }

    final matches = await widget.guestRepository.findGuestProfileMatches(
      GuestProfileLookupInput(
        normalizedName: draft.normalizedDisplayName(),
        phoneE164: draft.phoneE164Value(),
        emailLower: draft.emailLowerValue(),
        instagramHandle: draft.instagramHandleValue(),
      ),
    );
    if (!mounted || requestId != _profileMatchRequestId) {
      return;
    }

    setState(() {
      _profileMatches = matches;
    });
  }

  GuestProfileMatch? _primaryIdentityMatch() {
    for (final match in _visibleProfileMatches()) {
      if (match.matchType == GuestProfileMatchType.phone ||
          match.matchType == GuestProfileMatchType.email ||
          match.matchType == GuestProfileMatchType.instagram) {
        return match;
      }
    }

    return null;
  }

  Iterable<GuestProfileMatch> _visibleProfileMatches() {
    final editedProfileId = widget.initialGuest?.guestProfileId;
    if (editedProfileId == null) {
      return _profileMatches;
    }

    return _profileMatches.where(
      (match) => match.profile.id != editedProfileId,
    );
  }

  Iterable<GuestProfileMatch> _nameOnlyMatches() {
    final primaryMatchId = _primaryIdentityMatch()?.profile.id;
    return _visibleProfileMatches().where(
      (match) =>
          match.matchType == GuestProfileMatchType.name &&
          match.profile.id != primaryMatchId,
    );
  }

  void _applyProfile(GuestProfileRecord profile) {
    setState(() {
      _selectedProfile = profile;
      _nameController.text = profile.displayName;
      _phoneController.text = formatPhoneForDisplay(profile.phoneE164);
      _emailController.text = profile.emailLower ?? '';
      _instagramController.text = formatInstagramHandleForDisplay(
        profile.instagramHandle,
      );
    });
  }

  Widget _buildProfileMatchMessage() {
    final selectedProfile = _selectedProfile;
    if (selectedProfile != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Using existing guest: ${selectedProfile.displayName}'),
      );
    }

    final primaryMatch = _primaryIdentityMatch();
    final nameMatches = _nameOnlyMatches().toList(growable: false);
    if (primaryMatch == null && nameMatches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (primaryMatch != null)
            Text('Using existing guest: ${primaryMatch.profile.displayName}')
          else
            for (final match in nameMatches)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${match.profile.displayName} exists from another event.',
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Use this guest profile to keep their info synced across events.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _applyProfile(match.profile),
                      child: const Text('Use Existing Guest'),
                    ),
                  ],
                ),
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
      selectedProfile: _selectedProfile ?? _primaryIdentityMatch()?.profile,
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
            TextFormField(
              controller: _instagramController,
              decoration: const InputDecoration(labelText: 'Instagram'),
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              validator: (_) => _buildDraft().instagramHandleError,
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
            MoneyTextFormField(
              fieldKey: guestCoverAmountFieldKey,
              controller: _coverAmountController,
              labelText: 'Cover Amount',
              validator: _moneyFieldError,
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
