import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/auth/models/host_sign_in_draft.dart';

void main() {
  group('HostSignInDraft', () {
    test('requires an email', () {
      const draft = HostSignInDraft(email: '', password: '12345678!');

      expect(draft.emailError, 'Email is required.');
    });

    test('requires a password', () {
      const draft = HostSignInDraft(
        email: 'brian.le1678@gmail.com',
        password: '',
      );

      expect(draft.passwordError, 'Password is required.');
    });

    test('is valid when both fields are present', () {
      const draft = HostSignInDraft(
        email: 'brian.le1678@gmail.com',
        password: '12345678!',
      );

      expect(draft.isValid, isTrue);
    });
  });
}
