import 'package:flutter/material.dart';
import 'package:mosaic/features/auth/controllers/auth_controller.dart';
import 'package:mosaic/features/auth/models/host_sign_in_draft.dart';

class HostSignInScreen extends StatefulWidget {
  const HostSignInScreen({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  State<HostSignInScreen> createState() => _HostSignInScreenState();
}

class _HostSignInScreenState extends State<HostSignInScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _showValidation = false;

  HostSignInDraft get _draft => HostSignInDraft(
        email: _emailController.text,
        password: _passwordController.text,
      );

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final draft = _draft;
    if (!draft.isValid) {
      setState(() {
        _showValidation = true;
      });
      return;
    }

    setState(() {
      _showValidation = true;
    });
    await widget.authController.signIn(
      email: draft.email.trim(),
      password: draft.password,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, _) {
        final draft = _draft;

        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Host Sign In',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Run live Mahjong events from one phone.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sign in with the host account to manage check-in, sessions, scoring, and prizes.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the single host account for this event operation.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        errorText: _showValidation ? draft.emailError : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        errorText: _showValidation ? draft.passwordError : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (widget.authController.submitError != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.authController.submitError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed:
                          widget.authController.isSigningIn ? null : _submit,
                      child: Text(
                        widget.authController.isSigningIn
                            ? 'Signing In...'
                            : 'Sign In',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
