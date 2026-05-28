import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/auth/controllers/auth_controller.dart';
import 'package:mosaic/features/auth/screens/host_sign_in_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  HostAuthUser? current;
  Object? signInError;
  Object? sendOtpError;
  Object? verifyOtpError;
  String? lastEmail;
  String? lastPassword;
  String? sentOtpEmail;
  String? verifiedOtpEmail;
  String? verifiedOtpCode;

  final StreamController<HostAuthUser?> controller =
      StreamController<HostAuthUser?>.broadcast();

  @override
  Stream<HostAuthUser?> authStateChanges() => controller.stream;

  @override
  HostAuthUser? get currentHost => current;

  @override
  Future<HostAuthUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;

    if (signInError != null) {
      throw signInError!;
    }

    current = HostAuthUser(id: 'usr_01', email: email);
    controller.add(current);
    return current;
  }

  @override
  Future<void> sendEmailOtp({required String email}) async {
    sentOtpEmail = email;
    if (sendOtpError != null) {
      throw sendOtpError!;
    }
  }

  @override
  Future<HostAuthUser?> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    verifiedOtpEmail = email;
    verifiedOtpCode = code;
    if (verifyOtpError != null) {
      throw verifyOtpError!;
    }
    current = HostAuthUser(id: 'usr_otp', email: email);
    controller.add(current);
    return current;
  }

  @override
  Future<void> signOut() async {
    current = null;
    controller.add(null);
  }
}

void main() {
  testWidgets('defaults to email code sign-in', (tester) async {
    final controller = AuthController(authRepository: _FakeAuthRepository());
    await controller.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: HostSignInScreen(authController: controller),
      ),
    );

    expect(find.text('Host Sign In'), findsOneWidget);
    expect(
        find.text('Run live Mahjong events from one phone.'), findsOneWidget);
    expect(find.text('Email Code'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Send Code'), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);
  });

  testWidgets('configures email input for email entry', (tester) async {
    final controller = AuthController(authRepository: _FakeAuthRepository());
    await controller.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: HostSignInScreen(authController: controller),
      ),
    );

    final emailEditable = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).first,
        matching: find.byType(EditableText),
      ),
    );

    expect(emailEditable.keyboardType, TextInputType.emailAddress);
    expect(emailEditable.textCapitalization, TextCapitalization.none);
    expect(emailEditable.autocorrect, isFalse);
    expect(emailEditable.enableSuggestions, isFalse);
    expect(emailEditable.autofillHints, contains(AutofillHints.email));
  });

  testWidgets('configures password input for secure paste entry',
      (tester) async {
    final controller = AuthController(authRepository: _FakeAuthRepository());
    await controller.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: HostSignInScreen(authController: controller),
      ),
    );

    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();

    final passwordEditable = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).last,
        matching: find.byType(EditableText),
      ),
    );

    expect(passwordEditable.obscureText, isTrue);
    expect(passwordEditable.enableInteractiveSelection, isTrue);
    expect(passwordEditable.autocorrect, isFalse);
    expect(passwordEditable.enableSuggestions, isFalse);
    expect(passwordEditable.autofillHints, contains(AutofillHints.password));
  });

  testWidgets('email code mode sends code and shows code entry',
      (tester) async {
    final repository = _FakeAuthRepository();
    final controller = AuthController(authRepository: repository);
    await controller.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: HostSignInScreen(authController: controller),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'helper@example.com');
    await tester.tap(find.text('Send Code'));
    await tester.pumpAndSettle();

    expect(repository.sentOtpEmail, 'helper@example.com');
    expect(
      find.text('Enter the code sent to helper@example.com.'),
      findsOneWidget,
    );
    expect(find.text('Verify Code'), findsOneWidget);
    expect(find.text('Resend Code'), findsOneWidget);
    expect(find.text('Use a different email'), findsOneWidget);
  });

  testWidgets('email code entry does not show validation before edit',
      (tester) async {
    final controller = AuthController(authRepository: _FakeAuthRepository());
    await controller.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: HostSignInScreen(authController: controller),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'helper@example.com');
    await tester.tap(find.text('Send Code'));
    await tester.pumpAndSettle();

    expect(find.text('Code is required.'), findsNothing);
  });

  testWidgets('email code mode verifies code', (tester) async {
    final repository = _FakeAuthRepository();
    final controller = AuthController(authRepository: repository);
    await controller.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: HostSignInScreen(authController: controller),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'helper@example.com');
    await tester.tap(find.text('Send Code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Verify Code'));
    await tester.pumpAndSettle();

    expect(repository.verifiedOtpEmail, 'helper@example.com');
    expect(repository.verifiedOtpCode, '123456');
  });

  testWidgets('email code mode validates missing email and code',
      (tester) async {
    final controller = AuthController(authRepository: _FakeAuthRepository());
    await controller.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: HostSignInScreen(authController: controller),
      ),
    );

    await tester.tap(find.text('Send Code'));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'helper@example.com');
    await tester.tap(find.text('Send Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify Code'));
    await tester.pump();
    expect(find.text('Code is required.'), findsOneWidget);
  });

  testWidgets('password mode validates missing password', (tester) async {
    final controller = AuthController(authRepository: _FakeAuthRepository());
    await controller.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: HostSignInScreen(authController: controller),
      ),
    );

    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('password mode keeps password sign-in available', (tester) async {
    final repository = _FakeAuthRepository();
    final controller = AuthController(authRepository: repository);
    await controller.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: HostSignInScreen(authController: controller),
      ),
    );

    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign In'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'host@example.test',
    );
    await tester.enterText(
        find.byType(TextFormField).last, 'correct-horse-test!');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(repository.lastEmail, 'host@example.test');
    expect(repository.lastPassword, 'correct-horse-test!');
  });

  testWidgets('renders a friendly sign-in error', (tester) async {
    final repository = _FakeAuthRepository()
      ..signInError = Exception('Invalid login credentials');
    final controller = AuthController(authRepository: repository);
    await controller.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: HostSignInScreen(authController: controller),
      ),
    );

    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'host@example.test',
    );
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(
      find.text('Use an email code, or switch to password sign-in.'),
      findsOneWidget,
    );
  });
}
