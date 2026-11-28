import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
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
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _roll.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.controlRadius)),
      );

  void _fillDemo(String email) {
    setState(() {
      _email.text = email;
      _password.text = 'Demo@12345';
      _error = null;
    });
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primaryContainer, scheme.surface, scheme.secondaryContainer],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: scheme.primary,
                          child: Icon(Icons.school_rounded, size: 32, color: scheme.onPrimary),
                        ),
                        const SizedBox(height: 14),
                        Text('Assessly',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_register ? 'Create a student account' : 'Sign in to continue',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 24),
                        if (_register) ...[
                          TextFormField(
                            key: const Key('name'),
                            controller: _name,
                            decoration: _dec('Full name', Icons.person_outline),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('roll'),
                            controller: _roll,
                            decoration: _dec('Roll number (optional)', Icons.badge_outlined),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          key: const Key('email'),
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _dec('Email', Icons.email_outlined),
                          validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('password'),
                          controller: _password,
                          obscureText: _hidePassword,
                          decoration: _dec(
                            'Password',
                            Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _hidePassword = !_hidePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter your password';
                            if (_register && v.length < 8) return 'Use at least 8 characters';
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_error != null)
                          Container(
                            margin: const EdgeInsets.only(top: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
                            ),
                            child: Row(children: [
                              Icon(Icons.error_outline, color: scheme.onErrorContainer),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer))),
                            ]),
                          ),
                        const SizedBox(height: 22),
                        FilledButton(
                          key: const Key('submit'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.controlRadius)),
                          ),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(_register ? 'Register' : 'Sign in'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _register = !_register;
                                    _error = null;
                                  }),
                          child: Text(_register ? 'I already have an account' : 'New student? Register'),
                        ),
                        if (!_register) ...[
                          const Divider(height: 28),
                          Text('Demo accounts', textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: [
                              for (final d in const [
                                (
                                  'Teacher',
                                  Icons.co_present_outlined,
                                  'teacher@assessly.local',
                                ),
                                (
                                  'Student',
                                  Icons.person_outline,
                                  'asha@assessly.local',
                                ),
                                (
                                  'Admin',
                                  Icons.admin_panel_settings_outlined,
                                  'admin@assessly.local',
                                ),
                              ])
                                ActionChip(
                                  avatar: Icon(d.$2, size: 18),
                                  label: Text(d.$1),
                                  onPressed: () => _fillDemo(d.$3),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
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
