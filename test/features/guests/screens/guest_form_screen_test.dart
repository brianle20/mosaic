import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/guests/screens/guest_form_screen.dart';

class _RecordingGuestRepository implements GuestRepository {
  CreateGuestInput? created;

  @override
  Future<GuestDetailRecord> assignGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord> checkInGuest(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) async {
    created = input;
    return EventGuestRecord.fromJson({
      'id': 'gst_01',
      'event_id': input.eventId,
      'display_name': input.displayName,
      'normalized_name': input.normalizedName,
      'attendance_status': 'expected',
      'cover_status': input.coverStatus.name,
      'cover_amount_cents': input.coverAmountCents,
      'is_comped': input.isComped,
      'has_scored_play': false,
      'phone_e164': input.phoneE164,
      'email_lower': input.emailLower,
      'note': input.note,
    });
  }

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) async => null;

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => const [];

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      const {};

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      const [];

  @override
  Future<GuestDetailRecord> replaceGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('shows validation and submits a new guest', (tester) async {
    final repository = _RecordingGuestRepository();
    EventGuestRecord? createdGuest;

    await tester.pumpWidget(
      MaterialApp(
        home: GuestFormScreen(
          eventId: 'evt_01',
          existingGuests: const [],
          guestRepository: repository,
          onSaved: (guest) => createdGuest = guest,
        ),
      ),
    );

    await tester.tap(find.text('Save Guest'));
    await tester.pump();
    expect(find.text('Name is required.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Alice Wong');
    await tester.ensureVisible(find.text('Save Guest'));
    await tester.tap(find.text('Save Guest'));
    await tester.pumpAndSettle();

    expect(repository.created, isNotNull);
    expect(repository.created!.normalizedName, 'alice wong');
    expect(createdGuest, isNotNull);
  });
}
