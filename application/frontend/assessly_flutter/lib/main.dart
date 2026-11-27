import 'package:flutter/material.dart';
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
  final ThemeController? themeController;
  const AssesslyApp({super.key, required this.auth, this.themeController});
  @override
  State<AssesslyApp> createState() => _AssesslyAppState();
}

class _AssesslyAppState extends State<AssesslyApp> {
  late final ThemeController _theme = widget.themeController ?? ThemeController();

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
        ChangeNotifierProvider<ThemeController>.value(value: _theme),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Assessly',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          home: const _Gate(),
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
