import 'package:flutter_bloc/flutter_bloc.dart';

import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(const LoginState());

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  void togglePasswordVisibility() {
    emit(state.copyWith(obscurePassword: !state.obscurePassword));
  }

  /// Clears the email error as soon as the user starts typing again.
  void emailChanged() {
    if (state.emailError != null) {
      emit(state.copyWith(clearEmailError: true));
    }
  }

  /// Clears the password error as soon as the user starts typing again.
  void passwordChanged() {
    if (state.passwordError != null) {
      emit(state.copyWith(clearPasswordError: true));
    }
  }

  /// Validates the form. Real authentication is added in Phase 2.
  void submit({required String email, required String password}) {
    final emailError = _validateEmail(email.trim());
    final passwordError = password.isEmpty ? 'Password is required' : null;

    if (emailError != null || passwordError != null) {
      emit(state.copyWith(
        emailError: emailError,
        passwordError: passwordError,
        clearEmailError: emailError == null,
        clearPasswordError: passwordError == null,
        status: LoginStatus.idle,
      ));
      return;
    }

    // Emit "validated" once, then reset so the next submit triggers again.
    emit(state.copyWith(
      clearEmailError: true,
      clearPasswordError: true,
      status: LoginStatus.validated,
    ));
    emit(state.copyWith(status: LoginStatus.idle));
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) return 'Email is required';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }
}