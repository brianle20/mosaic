import 'package:meta/meta.dart';

@immutable
class HostSignInDraft {
  const HostSignInDraft({
    this.email = '',
    this.password = '',
    this.code = '',
  });

  final String email;
  final String password;
  final String code;

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

  String? get codeError {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return 'Code is required.';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return 'Enter the 6-digit code.';
    }

    return null;
  }

  bool get isValid => emailError == null && passwordError == null;

  HostSignInDraft copyWith({
    String? email,
    String? password,
    String? code,
  }) {
    return HostSignInDraft(
      email: email ?? this.email,
      password: password ?? this.password,
      code: code ?? this.code,
    );
  }
}
