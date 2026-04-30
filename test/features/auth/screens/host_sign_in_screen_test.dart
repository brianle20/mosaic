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
  String? lastEmail;
  String? lastPassword;

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
  Future<void> signOut() async {
    current = null;
    controller.add(null);
  }
}

void main() {
  testWidgets('renders email, password, and submit action', (tester) async {
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
    expect(
      find.text(
        'Sign in with the host account to manage check-in, sessions, scoring, and prizes.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign In'), findsOneWidget);
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

  testWidgets('shows validation messages for missing fields', (tester) async {
    final controller = AuthController(authRepository: _FakeAuthRepository());
    await controller.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: HostSignInScreen(authController: controller),
      ),
    );

    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('submits email and password through the controller',
      (tester) async {
    final repository = _FakeAuthRepository();
    final controller = AuthController(authRepository: repository);
    await controller.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: HostSignInScreen(authController: controller),
      ),
    );

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

    await tester.enterText(
      find.byType(TextFormField).first,
      'host@example.test',
    );
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(
      find.text('Use the single host account for this event operation.'),
      findsOneWidget,
    );
  });
}
