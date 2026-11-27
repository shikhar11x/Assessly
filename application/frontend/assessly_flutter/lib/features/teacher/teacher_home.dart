import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_state.dart';
import 'assessment_page.dart';
import 'teacher_api.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});
  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  late final TeacherApi _api;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _api = TeacherApi(context.read<ApiClient>());
    _future = _api.assessments();
  }

  void _reload() => setState(() { _future = _api.assessments(); });

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _create() async {
    final body = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => const _NewAssessmentDialog());
    if (body == null) return;
    try {
      await _api.createAssessment(body);
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _openDetail(Map<String, dynamic> a) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AssessmentDetailPage(assessment: a)));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher dashboard'),
        actions: [
          const ThemeToggleButton(),
          IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
          IconButton(tooltip: 'Sign out', onPressed: auth.logout, icon: const Icon(Icons.logout_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-assessment'),
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New assessment'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          final list = snap.data;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 96), children: [
                _Hero(name: auth.user!.fullName, list: list),
                const SizedBox(height: 28),
                Text('Your assessments',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (snap.connectionState != ConnectionState.done)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                else if (snap.hasError)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        Text(snap.error.toString()),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _reload, child: const Text('Retry')),
                      ]),
                    ),
                  )
                else if (list!.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No assessments yet. Create your first one.')),
                    ),
                  )
                else
                  for (final a in list) _AssessmentCard(a: a, onTap: () => _openDetail(a)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String name;
  final List<Map<String, dynamic>>? list;
  const _Hero({required this.name, required this.list});

  Widget _stat(BuildContext context, String label, String value, Color fg) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(color: fg, fontSize: 26, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 12)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final l = list;
    final published = l?.where((a) => a['isPublished'] == true).length;
    final submitted = l?.fold<int>(0, (n, a) => n + ((a['submittedCount'] as int?) ?? 0));
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [s.primary, Color.lerp(s.primary, s.tertiary, 0.7)!],
        ),
        boxShadow: [BoxShadow(color: s.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome, $name',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: s.onPrimary)),
        const SizedBox(height: 4),
        Text('Create assessments, manage students and track results.',
            style: TextStyle(color: s.onPrimary.withValues(alpha: 0.85))),
        const SizedBox(height: 20),
        Row(children: [
          _stat(context, 'Assessments', l == null ? '-' : '${l.length}', s.onPrimary),
          _stat(context, 'Published', published == null ? '-' : '$published', s.onPrimary),
          _stat(context, 'Submissions', submitted == null ? '-' : '$submitted', s.onPrimary),
        ]),
      ]),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  final Map<String, dynamic> a;
  final VoidCallback onTap;
  const _AssessmentCard({required this.a, required this.onTap});

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
    final published = a['isPublished'] == true;
    final bg = published ? s.primaryContainer : s.surfaceContainerHighest;
    final fg = published ? s.onPrimaryContainer : s.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('assessment-${a['id']}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${a['title']}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                child: Text(published ? 'Published' : 'Draft',
                    style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 18, runSpacing: 6, children: [
              _meta(context, Icons.timer_outlined, '${a['durationMinutes']} min'),
              _meta(context, Icons.quiz_outlined, '${a['questionCount'] ?? 0} in bank, ${a['questionsPerAttempt']} per student'),
              _meta(context, Icons.group_outlined, '${a['assignedCount'] ?? 0} assigned'),
              _meta(context, Icons.task_alt_outlined, '${a['submittedCount'] ?? 0} submitted'),
              _meta(context, Icons.event_available_outlined, 'Min attendance ${a['minAttendancePct']}%'),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _NewAssessmentDialog extends StatefulWidget {
  const _NewAssessmentDialog();
  @override
  State<_NewAssessmentDialog> createState() => _NewAssessmentDialogState();
}

class _NewAssessmentDialogState extends State<_NewAssessmentDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _duration = TextEditingController(text: '30');
  final _count = TextEditingController(text: '5');
  final _att = TextEditingController(text: '75');
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _duration.dispose();
    _count.dispose();
    _att.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final dur = int.tryParse(_duration.text.trim());
    final cnt = int.tryParse(_count.text.trim());
    final att = double.tryParse(_att.text.trim());
    if (title.isEmpty) return setState(() => _error = 'Enter a title');
    if (dur == null || dur < 1 || dur > 600) return setState(() => _error = 'Duration must be 1-600 minutes');
    if (cnt == null || cnt < 1) return setState(() => _error = 'Questions per student must be at least 1');
    if (att == null || att < 0 || att > 100) return setState(() => _error = 'Attendance must be 0-100');
    Navigator.pop(context, {
      'title': title,
      'description': _desc.text.trim(),
      'durationMinutes': dur,
      'questionsPerAttempt': cnt,
      'minAttendancePct': att,
    });
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration d(String l) => InputDecoration(labelText: l, border: const OutlineInputBorder());
    return AlertDialog(
      title: const Text('New assessment'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(key: const Key('na-title'), controller: _title, decoration: d('Title')),
            const SizedBox(height: 12),
            TextField(controller: _desc, decoration: d('Description (optional)'), maxLines: 2),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(key: const Key('na-duration'), controller: _duration, decoration: d('Minutes'), keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: TextField(key: const Key('na-count'), controller: _count, decoration: d('Questions per student'), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),
            TextField(key: const Key('na-attendance'), controller: _att, decoration: d('Minimum attendance %'), keyboardType: TextInputType.number),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const Key('na-save'), onPressed: _save, child: const Text('Create')),
      ],
    );
  }
}
