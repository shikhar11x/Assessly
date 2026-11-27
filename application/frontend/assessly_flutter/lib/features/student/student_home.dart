import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_state.dart';
import 'exam_page.dart';
import 'result_page.dart';
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

  void _reload() => setState(() { _future = _api.dashboard(); });

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _open(AssessmentItem a) async {
    try {
      if (a.closed && a.attemptId != null) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultPage(attemptId: a.attemptId!)));
        return;
      }
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
              FilledButton(
                  key: const Key('confirm-start'),
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Start now')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student dashboard'),
        actions: [
          const ThemeToggleButton(),
          IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
          IconButton(tooltip: 'Sign out', onPressed: auth.logout, icon: const Icon(Icons.logout_rounded)),
          const SizedBox(width: 8),
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
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _Hero(name: auth.user!.fullName, attendance: data.attendancePct),
                  const SizedBox(height: 28),
                  Text('Your assessments',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (data.assessments.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No assessments assigned yet.')),
                      ),
                    ),
                  for (final a in data.assessments)
                    _AssessmentCard(item: a, attendance: data.attendancePct, onOpen: () => _open(a)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String name;
  final double attendance;
  const _Hero({required this.name, required this.attendance});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final soft = s.onPrimary.withValues(alpha: 0.85);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [s.primary, Color.lerp(s.primary, s.tertiary, 0.7)!],
        ),
        boxShadow: [
          BoxShadow(color: s.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Welcome, $name',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: s.onPrimary)),
            const SizedBox(height: 6),
            Text('Ready for your next assessment? Check your eligibility below.',
                style: TextStyle(color: soft)),
          ]),
        ),
        const SizedBox(width: 16),
        Column(children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(fit: StackFit.expand, children: [
              CircularProgressIndicator(
                value: (attendance / 100).clamp(0.0, 1.0).toDouble(),
                strokeWidth: 7,
                color: s.onPrimary,
                backgroundColor: s.onPrimary.withValues(alpha: 0.25),
              ),
              Center(
                child: Text('${attendance.toStringAsFixed(0)}%',
                    style: TextStyle(color: s.onPrimary, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Text('Attendance', style: TextStyle(color: soft, fontSize: 12)),
        ]),
      ]),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  final AssessmentItem item;
  final double attendance;
  final VoidCallback onOpen;
  const _AssessmentCard({required this.item, required this.attendance, required this.onOpen});

  Widget _meta(BuildContext context, IconData icon, String text) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: c),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(color: c, fontSize: 13)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final a = item;
    final locked = !a.eligible && !a.closed && !a.inProgress;

    final String badge;
    final Color bg;
    final Color fg;
    if (a.closed) {
      badge = 'Finished';
      bg = s.secondaryContainer;
      fg = s.onSecondaryContainer;
    } else if (a.inProgress) {
      badge = 'In progress';
      bg = s.tertiaryContainer;
      fg = s.onTertiaryContainer;
    } else if (locked) {
      badge = 'Locked';
      bg = s.errorContainer;
      fg = s.onErrorContainer;
    } else {
      badge = 'Ready';
      bg = s.primaryContainer;
      fg = s.onPrimaryContainer;
    }

    Widget action;
    if (a.closed) {
      final txt = a.score != null && a.maxScore != null
          ? '${a.score!.toStringAsFixed(a.score! % 1 == 0 ? 0 : 2)} / ${a.maxScore!.toStringAsFixed(0)}'
          : 'Submitted';
      action = FilledButton.tonalIcon(key: Key('action-${a.id}'), onPressed: onOpen, icon: const Icon(Icons.fact_check_outlined, size: 18), label: Text('Completed: $txt'));
    } else if (a.inProgress) {
      action = FilledButton(key: Key('action-${a.id}'), onPressed: onOpen, child: const Text('Resume'));
    } else if (locked) {
      action = const FilledButton(onPressed: null, child: Text('Not eligible'));
    } else {
      action = FilledButton(key: Key('action-${a.id}'), onPressed: onOpen, child: const Text('Start'));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.assignment_outlined, color: fg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (a.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(a.description, style: TextStyle(color: s.onSurfaceVariant)),
                  ),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
              child: Text(badge, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 18, runSpacing: 6, children: [
            _meta(context, Icons.timer_outlined, '${a.durationMinutes} min'),
            _meta(context, Icons.quiz_outlined, '${a.questionsPerAttempt} questions'),
            _meta(context, Icons.event_available_outlined,
                'Min attendance ${a.minAttendancePct.toStringAsFixed(0)}%'),
          ]),
          if (locked)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Attendance ${attendance.toStringAsFixed(0)}% is below the required ${a.minAttendancePct.toStringAsFixed(0)}%.',
                style: TextStyle(color: s.error),
              ),
            ),
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerRight, child: action),
        ]),
      ),
    );
  }
}
