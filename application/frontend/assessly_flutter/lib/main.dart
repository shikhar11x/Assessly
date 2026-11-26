import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/api_client.dart';
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
  const AssesslyApp({super.key, required this.auth});
  @override
  State<AssesslyApp> createState() => _AssesslyAppState();
}

class _AssesslyAppState extends State<AssesslyApp> {
  @override
  void initState() {
    super.initState();
    widget.auth.restore();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: widget.auth.api),
        ChangeNotifierProvider<AuthState>.value(value: widget.auth),
      ],
      child: MaterialApp(
        title: 'Assessly',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF3F51B5), useMaterial3: true),
        home: const _Gate(),
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
