import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/auth/models/host_sign_in_draft.dart';

void main() {
  group('HostSignInDraft', () {
    test('requires an email', () {
      const draft = HostSignInDraft(email: '', password: 'correct-horse-test!');

      expect(draft.emailError, 'Email is required.');
    });

    test('requires a password', () {
      const draft = HostSignInDraft(
        email: 'host@example.test',
        password: '',
      );

      expect(draft.passwordError, 'Password is required.');
    });

    test('is valid when both fields are present', () {
      const draft = HostSignInDraft(
        email: 'host@example.test',
        password: 'correct-horse-test!',
      );

      expect(draft.isValid, isTrue);
    });
  });
}
