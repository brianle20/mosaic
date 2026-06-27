import 'package:mosaic/data/models/staff_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase/supabase.dart';

typedef StaffRpcRunner = Future<dynamic> Function(
  String functionName,
  Map<String, dynamic> params,
);

class SupabaseStaffRepository implements StaffRepository {
  SupabaseStaffRepository({required SupabaseClient client})
      : _rpcRunner = ((functionName, params) {
          return client.rpc(functionName, params: params);
        });

  SupabaseStaffRepository.withRpcRunner({
    required StaffRpcRunner rpcRunner,
  }) : _rpcRunner = rpcRunner;

  final StaffRpcRunner _rpcRunner;

  @override
  Future<List<EventStaffMembershipRecord>> listEventStaff(
    String eventId,
  ) async {
    final response = await _rpcRunner(
      'list_event_staff_memberships',
      {'target_event_id': eventId},
    );
    if (response is List) {
      return response
          .map((row) => EventStaffMembershipRecord.fromJson(
                (row as Map).cast<String, dynamic>(),
              ))
          .toList(growable: false);
    }

    throw StateError(
      'Expected a row list from list_event_staff_memberships but received '
      '${response.runtimeType}.',
    );
  }

  @override
  Future<EventStaffMembershipRecord> upsertEventStaff(
    UpsertEventStaffMembershipInput input,
  ) async {
    final response = await _rpcRunner(
      'upsert_event_staff_membership',
      {
        'target_event_id': input.eventId,
        'staff_email': input.email,
        'staff_phone_e164': input.phoneE164,
        'staff_display_name': input.displayName,
        'staff_role': eventStaffRoleToJson(input.role),
      },
    );
    return _singleRowFromResponse(
      'upsert_event_staff_membership',
      response,
    );
  }

  @override
  Future<EventStaffMembershipRecord> disableEventStaffMembership(
    String membershipId,
  ) async {
    final response = await _rpcRunner(
      'disable_event_staff_membership',
      {'target_membership_id': membershipId},
    );
    return _singleRowFromResponse(
      'disable_event_staff_membership',
      response,
    );
  }
}

EventStaffMembershipRecord _singleRowFromResponse(
  String functionName,
  Object? response,
) {
  if (response is List) {
    if (response.isEmpty) {
      throw StateError('Expected a row from $functionName but received none.');
    }
    final first = response.first;
    if (first is Map<String, dynamic>) {
      return EventStaffMembershipRecord.fromJson(first);
    }
    if (first is Map) {
      return EventStaffMembershipRecord.fromJson(
        first.cast<String, dynamic>(),
      );
    }
  }

  if (response is Map<String, dynamic>) {
    return EventStaffMembershipRecord.fromJson(response);
  }

  if (response is Map) {
    return EventStaffMembershipRecord.fromJson(
      response.cast<String, dynamic>(),
    );
  }

  throw StateError(
    'Expected a single row map from $functionName but received '
    '${response.runtimeType}.',
  );
}
