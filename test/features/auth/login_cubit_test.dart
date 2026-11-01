import 'package:assessly/features/auth/presentation/cubit/login_cubit.dart';
import 'package:assessly/features/auth/presentation/cubit/login_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginCubit', () {
    blocTest<LoginCubit, LoginState>(
      'emits required errors when both fields are empty',
      build: LoginCubit.new,
      act: (cubit) => cubit.submit(email: '', password: ''),
      expect: () => [
        isA<LoginState>()
            .having((s) => s.emailError, 'emailError', 'Email is required')
            .having(
              (s) => s.passwordError,
              'passwordError',
              'Password is required',
            ),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'emits an invalid email error for a malformed email',
      build: LoginCubit.new,
      act: (cubit) => cubit.submit(email: 'abc', password: 'secret123'),
      expect: () => [
        isA<LoginState>().having(
          (s) => s.emailError,
          'emailError',
          'Enter a valid email address',
        ),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'emits validated then idle when the form is valid',
      build: LoginCubit.new,
      act: (cubit) =>
          cubit.submit(email: 'student@college.edu', password: 'secret123'),
      expect: () => [
        isA<LoginState>()
            .having((s) => s.status, 'status', LoginStatus.validated),
        isA<LoginState>().having((s) => s.status, 'status', LoginStatus.idle),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'toggles password visibility',
      build: LoginCubit.new,
      act: (cubit) => cubit.togglePasswordVisibility(),
      expect: () => [
        isA<LoginState>().having((s) => s.obscurePassword, 'obscure', false),
      ],
    );
  });
}