import 'package:meta/meta.dart';

@immutable
class HostAuthUser {
  const HostAuthUser({
    required this.id,
    required this.email,
  });

  final String id;
  final String email;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HostAuthUser &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            email == other.email;
  }

  @override
  int get hashCode => Object.hash(id, email);
}
