import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/staff_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class EventStaffController extends ChangeNotifier {
  EventStaffController({
    required StaffRepository staffRepository,
    required this.eventId,
  }) : _staffRepository = staffRepository;

  final StaffRepository _staffRepository;
  final String eventId;

  bool isLoading = true;
  bool isSubmitting = false;
  String? error;
  String? submitError;
  List<EventStaffMembershipRecord> memberships = const [];

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      memberships = await _staffRepository.listEventStaff(eventId);
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> upsertStaff({
    String? email,
    String? phoneE164,
    required String displayName,
    required EventStaffRole role,
  }) async {
    final normalizedEmail = email?.trim();
    final normalizedPhone = phoneE164?.trim();
    final normalizedName = displayName.trim();
    final hasEmail = normalizedEmail != null && normalizedEmail.isNotEmpty;
    final hasPhone = normalizedPhone != null && normalizedPhone.isNotEmpty;
    if ((!hasEmail && !hasPhone) || normalizedName.isEmpty) {
      submitError = 'Enter an email or phone number and display name.';
      notifyListeners();
      return false;
    }

    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      final record = await _staffRepository.upsertEventStaff(
        UpsertEventStaffMembershipInput(
          eventId: eventId,
          email: hasEmail ? normalizedEmail : null,
          phoneE164: hasPhone ? normalizedPhone : null,
          displayName: normalizedName,
          role: role,
        ),
      );
      _replaceMembership(record);
      isSubmitting = false;
      notifyListeners();
      return true;
    } catch (exception) {
      submitError = exception.toString();
      isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> disableMembership(String membershipId) async {
    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      final record =
          await _staffRepository.disableEventStaffMembership(membershipId);
      _replaceMembership(record);
    } catch (exception) {
      submitError = exception.toString();
    }

    isSubmitting = false;
    notifyListeners();
  }

  void _replaceMembership(EventStaffMembershipRecord record) {
    final updated = [
      for (final membership in memberships)
        if (membership.id == record.id) record else membership,
    ];
    if (!memberships.any((membership) => membership.id == record.id)) {
      updated.add(record);
    }
    updated
        .sort((left, right) => left.displayName.compareTo(right.displayName));
    memberships = updated;
  }
}
