import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../state/theme_controller.dart';

/// Kept for a later Firebase release. Lite hides these actions.
const bool kShowLegacyAuthLinks = false;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _secret = TextEditingController();
  bool _create = false;
  bool _hidePassword = true;
  bool _hideSecret = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _secret.dispose();
    super.dispose();
  }

  bool _registering(AuthController auth) {
    if (kShowLegacyAuthLinks) return _create;
    if (auth.firebaseActive) return false;
    return !auth.hasLocalAccount;
  }

  Future<void> _submit(AuthController auth) async {
    if (_registering(auth)) {
      await auth.signUp(_email.text, _password.text, secretKey: _secret.text);
    } else {
      await auth.signIn(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final theme = context.watch<ThemeController>();
    final scheme = Theme.of(context).colorScheme;
    final registering = _registering(auth);
    final askSecret = registering && !auth.firebaseActive;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.calendar_month, size: 56, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'StockCalendar Lite',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Plan the stocks you want to buy on market days.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    onSubmitted: (_) => _submit(auth),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _hidePassword,
                    keyboardType: auth.firebaseActive
                        ? TextInputType.visiblePassword
                        : TextInputType.number,
                    maxLength: auth.firebaseActive ? null : 4,
                    inputFormatters: auth.firebaseActive
                        ? const <TextInputFormatter>[]
                        : [FilteringTextInputFormatter.digitsOnly],
                    autofillHints: registering
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: auth.firebaseActive ? 'Password' : 'PIN',
                      counterText: '',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    onSubmitted: (_) => _submit(auth),
                  ),
                  if (askSecret) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _secret,
                      obscureText: _hideSecret,
                      decoration: InputDecoration(
                        labelText: 'Secret Key',
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hideSecret = !_hideSecret),
                          icon: Icon(_hideSecret ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      onSubmitted: (_) => _submit(auth),
                    ),
                  ],
                  if (auth.error != null) ...[
                    const SizedBox(height: 12),
                    Text(auth.error!, style: TextStyle(color: scheme.error)),
                  ],
                  if (auth.notice != null) ...[
                    const SizedBox(height: 12),
                    Text(auth.notice!, style: TextStyle(color: scheme.primary)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: auth.busy ? null : () => _submit(auth),
                    child: auth.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(registering ? 'Registration' : 'Sign In'),
                  ),
                  if (kShowLegacyAuthLinks) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: auth.busy
                          ? null
                          : () => setState(() {
                              _create = !_create;
                            }),
                      child: Text(_create ? 'Have an account? Sign in' : 'Create an account'),
                    ),
                    if (!_create)
                      TextButton(
                        onPressed: auth.busy ? null : () => auth.sendReset(_email.text),
                        child: const Text('Forgot password'),
                      ),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dark theme'),
                    value: theme.mode == ThemeMode.dark,
                    onChanged: theme.setDark,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
