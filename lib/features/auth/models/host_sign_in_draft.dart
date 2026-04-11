import 'package:meta/meta.dart';

@immutable
class HostSignInDraft {
  const HostSignInDraft({
    this.email = '',
    this.password = '',
  });

  final String email;
  final String password;

  String? get emailError {
    if (email.trim().isEmpty) {
      return 'Email is required.';
    }

    return null;
  }

  String? get passwordError {
    if (password.isEmpty) {
      return 'Password is required.';
    }

    return null;
  }

  bool get isValid => emailError == null && passwordError == null;

  HostSignInDraft copyWith({
    String? email,
    String? password,
  }) {
    return HostSignInDraft(
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }
}
