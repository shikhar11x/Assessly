import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_state.dart';

/// Sign in, or register (students only; teacher accounts are created by seed/admin).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _roll = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _roll.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    try {
      if (_register) {
        await auth.register(_name.text, _email.text, _password.text, _roll.text);
      } else {
        await auth.login(_email.text, _password.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Assessly', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(_register ? 'Create a student account' : 'Sign in to continue',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      if (_register) ...[
                        TextFormField(
                          key: const Key('name'),
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'Full name'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                        ),
                        TextFormField(
                          key: const Key('roll'),
                          controller: _roll,
                          decoration: const InputDecoration(labelText: 'Roll number (optional)'),
                        ),
                      ],
                      TextFormField(
                        key: const Key('email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                      ),
                      TextFormField(
                        key: const Key('password'),
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter your password';
                          if (_register && v.length < 8) return 'Use at least 8 characters';
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ),
                      const SizedBox(height: 20),
                      FilledButton(
                        key: const Key('submit'),
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_register ? 'Register' : 'Sign in'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => setState(() {
                          _register = !_register;
                          _error = null;
                        }),
                        child: Text(_register ? 'I already have an account' : 'New student? Register'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
