import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../auth/auth_state.dart';
import 'exam_page.dart';
import 'student_api.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});
  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  late final StudentApi _api;
  Future<DashboardData>? _future;

  @override
  void initState() {
    super.initState();
    _api = StudentApi(context.read<ApiClient>());
    _future = _api.dashboard();
  }

  void _reload() => setState(() => _future = _api.dashboard());

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _open(AssessmentItem a) async {
    try {
      String attemptId;
      if (a.inProgress && a.attemptId != null) {
        attemptId = a.attemptId!;
      } else {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text('Start "${a.title}"?'),
            content: Text('The ${a.durationMinutes}-minute timer starts immediately and cannot be paused. '
                'You get ${a.questionsPerAttempt} randomly chosen questions and only one attempt.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              FilledButton(key: const Key('confirm-start'), onPressed: () => Navigator.pop(c, true), child: const Text('Start now')),
            ],
          ),
        );
        if (ok != true) return;
        attemptId = await _api.start(a.id);
      }
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExamPage(attemptId: attemptId)));
      if (mounted) _reload();
    } on ApiException catch (e) {
      _snack(e.message);
      if (mounted) _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student dashboard'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh)),
          TextButton.icon(onPressed: auth.logout, icon: const Icon(Icons.logout), label: const Text('Sign out')),
        ],
      ),
      body: FutureBuilder<DashboardData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(snap.error.toString()),
                const SizedBox(height: 12),
                FilledButton(onPressed: _reload, child: const Text('Retry')),
              ]),
            );
          }
          final data = snap.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Welcome, ${auth.user!.fullName}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    color: scheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.event_available),
                      title: const Text('Your attendance'),
                      trailing: Text('${data.attendancePct.toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Your assessments', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (data.assessments.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No assessments assigned yet.'))),
                  for (final a in data.assessments) _AssessmentCard(item: a, attendance: data.attendancePct, onOpen: () => _open(a)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  final AssessmentItem item;
  final double attendance;
  final VoidCallback onOpen;
  const _AssessmentCard({required this.item, required this.attendance, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = item;
    Widget action;
    if (a.closed) {
      final s = a.score != null && a.maxScore != null
          ? '${a.score!.toStringAsFixed(a.score! % 1 == 0 ? 0 : 2)} / ${a.maxScore!.toStringAsFixed(0)}'
          : 'Submitted';
      action = Chip(avatar: const Icon(Icons.check_circle, size: 18), label: Text('Completed: $s'));
    } else if (a.inProgress) {
      action = FilledButton(key: Key('action-${a.id}'), onPressed: onOpen, child: const Text('Resume'));
    } else if (!a.eligible) {
      action = const FilledButton(onPressed: null, child: Text('Not eligible'));
    } else {
      action = FilledButton(key: Key('action-${a.id}'), onPressed: onOpen, child: const Text('Start'));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          if (a.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(a.description)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 4, children: [
            Chip(avatar: const Icon(Icons.timer_outlined, size: 18), label: Text('${a.durationMinutes} min')),
            Chip(avatar: const Icon(Icons.quiz_outlined, size: 18), label: Text('${a.questionsPerAttempt} questions')),
            Chip(avatar: const Icon(Icons.event_available, size: 18), label: Text('Min attendance ${a.minAttendancePct.toStringAsFixed(0)}%')),
          ]),
          if (!a.eligible && !a.closed && !a.inProgress)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Attendance ${attendance.toStringAsFixed(0)}% is below the required ${a.minAttendancePct.toStringAsFixed(0)}%.',
                style: TextStyle(color: scheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: action),
        ]),
      ),
    );
  }
}
