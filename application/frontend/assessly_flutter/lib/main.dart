import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'core/api_client.dart';
import 'core/theme.dart';
import 'features/auth/auth_state.dart';
import 'features/auth/login_page.dart';
import 'features/student/student_home.dart';
import 'features/teacher/teacher_home.dart';

void main() {
  final auth = AuthState(ApiClient());
  runApp(AssesslyApp(auth: auth));
}

class AssesslyApp extends StatefulWidget {
  final AuthState auth;
  final ThemeCubit? themeCubit;
  const AssesslyApp({super.key, required this.auth, this.themeCubit});
  @override
  State<AssesslyApp> createState() => _AssesslyAppState();
}

class _AssesslyAppState extends State<AssesslyApp> {
  late final ThemeCubit _theme = widget.themeCubit ?? ThemeCubit();

  @override
  void initState() {
    super.initState();
    widget.auth.restore();
    _theme.load();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: widget.auth.api),
        ChangeNotifierProvider<AuthState>.value(value: widget.auth),
      ],
      child: BlocProvider<ThemeCubit>.value(
        value: _theme,
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, mode) => MaterialApp(
            title: 'Assessly',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            home: const _Gate(),
          ),
        ),
      ),
    );
  }
}

/// Chooses the screen from the session state: loading, login, or the role's home.
class _Gate extends StatelessWidget {
  const _Gate();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (!auth.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!auth.signedIn) return const LoginPage();
    return auth.user!.role == 'teacher' ? const TeacherHome() : const StudentHome();
  }
}
