import 'package:equatable/equatable.dart';

enum LoginStatus { idle, validated }

class LoginState extends Equatable {
  const LoginState({
    this.obscurePassword = true,
    this.emailError,
    this.passwordError,
    this.status = LoginStatus.idle,
  });

  final bool obscurePassword;
  final String? emailError;
  final String? passwordError;

  /// [LoginStatus.validated] is emitted once when the form passes validation.
  final LoginStatus status;

  LoginState copyWith({
    bool? obscurePassword,
    String? emailError,
    String? passwordError,
    bool clearEmailError = false,
    bool clearPasswordError = false,
    LoginStatus? status,
  }) {
    return LoginState(
      obscurePassword: obscurePassword ?? this.obscurePassword,
      emailError: clearEmailError ? null : (emailError ?? this.emailError),
      passwordError:
          clearPasswordError ? null : (passwordError ?? this.passwordError),
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props =>
      [obscurePassword, emailError, passwordError, status];
}