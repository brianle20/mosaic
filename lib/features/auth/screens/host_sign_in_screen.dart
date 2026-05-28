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
  late final TextEditingController _codeController;
  bool _showValidation = false;

  HostSignInDraft get _draft => HostSignInDraft(
        email: _emailController.text,
        password: _passwordController.text,
        code: _codeController.text,
      );

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
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

  Future<void> _sendCode() async {
    final draft = _draft;
    if (draft.emailError != null) {
      setState(() {
        _showValidation = true;
      });
      return;
    }

    setState(() {
      _showValidation = false;
    });
    await widget.authController.sendEmailOtp(email: draft.email.trim());
  }

  Future<void> _verifyCode() async {
    final draft = _draft;
    if (draft.codeError != null) {
      setState(() {
        _showValidation = true;
      });
      return;
    }

    await widget.authController.verifyEmailOtp(
      email: widget.authController.pendingOtpEmail ?? draft.email.trim(),
      code: draft.code.trim(),
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
                      'Mosaic Sign In',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to manage Mosaic events.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use an email code, or switch to password sign-in.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<AuthSignInMode>(
                      segments: const [
                        ButtonSegment(
                          value: AuthSignInMode.emailCode,
                          label: Text('Email Code'),
                        ),
                        ButtonSegment(
                          value: AuthSignInMode.password,
                          label: Text('Password'),
                        ),
                      ],
                      selected: {widget.authController.signInMode},
                      onSelectionChanged: widget.authController.isSendingCode ||
                              widget.authController.isVerifyingCode ||
                              widget.authController.isSigningIn
                          ? null
                          : (selection) {
                              setState(() {
                                _showValidation = false;
                              });
                              widget.authController
                                  .setSignInMode(selection.single);
                            },
                    ),
                    if (widget.authController.signInMode ==
                        AuthSignInMode.emailCode)
                      ..._buildEmailCodeFields(context, draft)
                    else
                      ..._buildPasswordFields(context, draft),
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildEmailCodeFields(
    BuildContext context,
    HostSignInDraft draft,
  ) {
    if (widget.authController.emailOtpStep == EmailOtpStep.enterCode) {
      final email = widget.authController.pendingOtpEmail ?? draft.email.trim();
      return [
        const SizedBox(height: 24),
        Text(
          'Enter the code sent to $email.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          decoration: InputDecoration(
            labelText: 'Code',
            errorText: _showValidation ? draft.codeError : null,
          ),
          onChanged: (_) => setState(() {}),
          onFieldSubmitted: (_) => _verifyCode(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: widget.authController.isVerifyingCode ? null : _verifyCode,
          child: Text(
            widget.authController.isVerifyingCode
                ? 'Verifying...'
                : 'Verify Code',
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed:
              widget.authController.isSendingCode ? null : () => _sendCode(),
          child: const Text('Resend Code'),
        ),
        TextButton(
          onPressed: widget.authController.isVerifyingCode
              ? null
              : () {
                  _codeController.clear();
                  setState(() {
                    _showValidation = false;
                  });
                  widget.authController.resetEmailOtp();
                },
          child: const Text('Use a different email'),
        ),
      ];
    }

    return [
      const SizedBox(height: 24),
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.email],
        decoration: InputDecoration(
          labelText: 'Email',
          errorText: _showValidation ? draft.emailError : null,
        ),
        onChanged: (_) => setState(() {}),
        onFieldSubmitted: (_) => _sendCode(),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: widget.authController.isSendingCode ? null : _sendCode,
        child: Text(
          widget.authController.isSendingCode ? 'Sending Code...' : 'Send Code',
        ),
      ),
    ];
  }

  List<Widget> _buildPasswordFields(
    BuildContext context,
    HostSignInDraft draft,
  ) {
    return [
      const SizedBox(height: 24),
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.email],
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
        enableInteractiveSelection: true,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.password],
        decoration: InputDecoration(
          labelText: 'Password',
          errorText: _showValidation ? draft.passwordError : null,
        ),
        onChanged: (_) => setState(() {}),
        onFieldSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: widget.authController.isSigningIn ? null : _submit,
        child: Text(
          widget.authController.isSigningIn ? 'Signing In...' : 'Sign In',
        ),
      ),
    ];
  }
}
