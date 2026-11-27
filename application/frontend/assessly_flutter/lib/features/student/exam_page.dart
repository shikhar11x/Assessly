import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import 'student_api.dart';

/// Placeholder: loads the attempt and shows its state. The real exam screen comes in 2f-3.
class ExamPage extends StatefulWidget {
  final String attemptId;
  const ExamPage({super.key, required this.attemptId});
  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = StudentApi(context.read<ApiClient>()).attempt(widget.attemptId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final a = snap.data!['attempt'] as Map<String, dynamic>;
          final q = (snap.data!['questions'] as List).length;
          final secs = a['remainingSeconds'] as int;
          return Center(
            child: Text('Attempt loaded: $q questions, ${secs ~/ 60} min ${secs % 60} s left.\n'
                'The exam screen is built in step 2f-3.', textAlign: TextAlign.center),
          );
        },
      ),
    );
  }
}
