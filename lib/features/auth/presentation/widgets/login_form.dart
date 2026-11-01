import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/gradient_button.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<LoginCubit>().submit(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<LoginCubit, LoginState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == LoginStatus.validated,
      listener: (context, state) {
        _showMessage(
          'Details look good. Server sign-in will be connected in Phase 2.',
        );
      },
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome back',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to continue to Assessly',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => context.read<LoginCubit>().emailChanged(),
              decoration: InputDecoration(
                labelText: 'Email address',
                prefixIcon: const Icon(Icons.mail_outline_rounded),
                errorText: state.emailError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: state.obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) => context.read<LoginCubit>().passwordChanged(),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                errorText: state.passwordError,
                suffixIcon: IconButton(
                  tooltip: state.obscurePassword
                      ? 'Show password'
                      : 'Hide password',
                  icon: Icon(
                    state.obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      context.read<LoginCubit>().togglePasswordVisibility(),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showMessage(
                  'Password reset will be available in a later phase.',
                ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 8),
            GradientButton(label: 'Sign in', onPressed: _submit),
            const SizedBox(height: 28),
            Text(
              'Accounts are created by your college administrator.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 450.ms).slideY(
              begin: 0.05,
              end: 0,
              curve: Curves.easeOut,
            );
      },
    );
  }
}