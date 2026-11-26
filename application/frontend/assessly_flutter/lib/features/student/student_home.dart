import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_state.dart';

/// Placeholder home (replaced in 2f-2).
class StudentHome extends StatelessWidget {
  const StudentHome({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Student dashboard'), actions: [
        TextButton(onPressed: auth.logout, child: const Text('Sign out')),
      ]),
      body: Center(child: Text('Welcome, ${auth.user!.fullName}')),
    );
  }
}
