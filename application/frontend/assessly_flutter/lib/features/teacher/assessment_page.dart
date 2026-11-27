import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'teacher_api.dart';

void _snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

String _num(num n) => n % 1 == 0 ? n.toStringAsFixed(0) : n.toStringAsFixed(2);

class AssessmentDetailPage extends StatefulWidget {
  final Map<String, dynamic> assessment;
  const AssessmentDetailPage({super.key, required this.assessment});
  @override
  State<AssessmentDetailPage> createState() => _AssessmentDetailPageState();
}

class _AssessmentDetailPageState extends State<AssessmentDetailPage> {
  late final TeacherApi _api;
  late bool _published = widget.assessment['isPublished'] == true;
  bool _busy = false;

  String get _id => widget.assessment['id'] as String;

  @override
  void initState() {
    super.initState();
    _api = TeacherApi(context.read<ApiClient>());
  }

  Future<void> _togglePublish() async {
    setState(() => _busy = true);
    try {
      final r = _published ? await _api.unpublish(_id) : await _api.publish(_id);
      final a = r['assessment'] as Map<String, dynamic>;
      if (mounted) setState(() => _published = a['isPublished'] == true);
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.assessment['title']}'),
          actions: [
            const ThemeToggleButton(),
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: FilledButton.tonalIcon(
                key: const Key('toggle-publish'),
                onPressed: _busy ? null : _togglePublish,
                icon: Icon(_published ? Icons.visibility_off_outlined : Icons.publish_rounded, size: 18),
                label: Text(_published ? 'Unpublish' : 'Publish'),
              ),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.quiz_outlined), text: 'Questions'),
            Tab(icon: Icon(Icons.group_outlined), text: 'Students'),
            Tab(icon: Icon(Icons.insights_outlined), text: 'Results'),
          ]),
        ),
        body: TabBarView(children: [
          _QuestionsTab(api: _api, id: _id),
          _StudentsTab(api: _api, id: _id),
          _ResultsTab(api: _api, id: _id),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- Questions

class _QuestionsTab extends StatefulWidget {
  final TeacherApi api;
  final String id;
  const _QuestionsTab({required this.api, required this.id});
  @override
  State<_QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<_QuestionsTab> {
  late Future<List<Map<String, dynamic>>> _future = widget.api.questions(widget.id);

  void _reload() => setState(() { _future = widget.api.questions(widget.id); });

  Future<void> _add() async {
    final body = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _QuestionDialog());
    if (body == null) return;
    try {
      await widget.api.addQuestion(widget.id, body);
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  Future<void> _delete(String qid) async {
    try {
      await widget.api.deleteQuestion(widget.id, qid);
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  Widget _card(Map<String, dynamic> q, ColorScheme s) {
    final mcq = q['type'] == 'mcq';
    final opts = (q['options'] as List?) ?? const [];
    final cases = (q['testCases'] as List?) ?? const [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Chip(label: Text(mcq ? 'MCQ' : 'Coding'), visualDensity: VisualDensity.compact),
            const SizedBox(width: 8),
            Text('${q['marks']} marks', style: TextStyle(color: s.onSurfaceVariant)),
            const Spacer(),
            IconButton(
              tooltip: 'Delete question',
              onPressed: () => _delete(q['id'] as String),
              icon: Icon(Icons.delete_outline_rounded, color: s.error),
            ),
          ]),
          Text('${q['prompt']}', style: Theme.of(context).textTheme.titleMedium),
          if (mcq)
            for (var i = 0; i < opts.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Icon(i == q['correctOption'] ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size: 18, color: i == q['correctOption'] ? Colors.green.shade600 : s.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${opts[i]}')),
                  if (i == q['correctOption'])
                    Text('Correct', style: TextStyle(color: Colors.green.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${cases.length} test cases (${cases.where((c) => (c as Map)['isSample'] == true).length} sample)',
                  style: TextStyle(color: s.onSurfaceVariant)),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text(snap.error.toString()));
        final list = snap.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Row(children: [
                Text('${list.length} questions in the bank',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                FilledButton.icon(
                  key: const Key('add-question'),
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add question'),
                ),
              ]),
              const SizedBox(height: 14),
              if (list.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No questions yet.')))),
              for (final q in list) _card(q, s),
            ]),
          ),
        );
      },
    );
  }
}

class _CaseForm {
  final input = TextEditingController();
  final expected = TextEditingController();
  bool sample;
  _CaseForm({this.sample = false});
  void dispose() {
    input.dispose();
    expected.dispose();
  }
}

class _QuestionDialog extends StatefulWidget {
  const _QuestionDialog();
  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  String _type = 'mcq';
  final _prompt = TextEditingController();
  final _marks = TextEditingController(text: '1');
  final _starter = TextEditingController();
  final _opts = List.generate(4, (_) => TextEditingController());
  int _correct = 0;
  final List<_CaseForm> _cases = [_CaseForm(sample: true)];
  String? _error;

  @override
  void dispose() {
    _prompt.dispose();
    _marks.dispose();
    _starter.dispose();
    for (final o in _opts) {
      o.dispose();
    }
    for (final c in _cases) {
      c.dispose();
    }
    super.dispose();
  }

  void _fail(String m) => setState(() => _error = m);

  void _save() {
    final prompt = _prompt.text.trim();
    final marks = int.tryParse(_marks.text.trim());
    if (prompt.isEmpty) return _fail('Enter the question text');
    if (marks == null || marks < 1) return _fail('Marks must be at least 1');

    if (_type == 'mcq') {
      final opts = <String>[];
      int? correct;
      for (var i = 0; i < _opts.length; i++) {
        final t = _opts[i].text.trim();
        if (t.isEmpty) continue;
        if (i == _correct) correct = opts.length;
        opts.add(t);
      }
      if (opts.length < 2) return _fail('Give at least two options');
      if (correct == null) return _fail('The option marked correct is empty');
      Navigator.pop(context, {'type': 'mcq', 'prompt': prompt, 'options': opts, 'correctOption': correct, 'marks': marks});
      return;
    }

    final cases = <Map<String, dynamic>>[];
    for (final c in _cases) {
      final expected = c.expected.text.trim();
      if (expected.isEmpty) continue;
      var input = c.input.text;
      if (input.isNotEmpty && !input.endsWith('\n')) input = '$input\n';
      cases.add({'input': input, 'expectedOutput': expected, 'isSample': c.sample});
    }
    if (cases.isEmpty) return _fail('Add at least one test case with an expected output');
    if (!cases.any((c) => c['isSample'] == true)) return _fail('Mark at least one case as sample (used by Run)');
    Navigator.pop(context, {
      'type': 'coding',
      'prompt': prompt,
      'starterCode': _starter.text,
      'marks': marks,
      'testCases': cases,
    });
  }

  InputDecoration _d(String l) => InputDecoration(labelText: l, border: const OutlineInputBorder());

  Widget _mcqFields(ColorScheme s) => Column(children: [
        for (var i = 0; i < _opts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              IconButton(
                key: Key('correct-$i'),
                tooltip: 'Mark as correct',
                onPressed: () => setState(() => _correct = i),
                icon: Icon(_correct == i ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: _correct == i ? Colors.green.shade600 : s.onSurfaceVariant),
              ),
              Expanded(child: TextField(key: Key('opt-$i'), controller: _opts[i], decoration: _d('Option ${String.fromCharCode(65 + i)}'))),
            ]),
          ),
        Text('Tap the circle to choose the correct option.', style: TextStyle(color: s.onSurfaceVariant, fontSize: 12)),
      ]);

  Widget _codingFields(ColorScheme s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _starter, decoration: _d('Starter code (optional)'), minLines: 2, maxLines: 5,
            style: const TextStyle(fontFamily: 'monospace')),
        const SizedBox(height: 14),
        Text('Test cases (Python 3, read with input())', style: Theme.of(context).textTheme.titleSmall),
        for (var i = 0; i < _cases.length; i++)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: s.outlineVariant), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              TextField(key: Key('case-in-$i'), controller: _cases[i].input, decoration: _d('Input (one value per line)'), minLines: 1, maxLines: 4),
              const SizedBox(height: 8),
              TextField(key: Key('case-out-$i'), controller: _cases[i].expected, decoration: _d('Expected output'), minLines: 1, maxLines: 4),
              Row(children: [
                Checkbox(value: _cases[i].sample, onChanged: (v) => setState(() => _cases[i].sample = v ?? false)),
                const Expanded(child: Text('Sample (visible to students)')),
                if (_cases.length > 1)
                  IconButton(
                    tooltip: 'Remove case',
                    onPressed: () => setState(() => _cases.removeAt(i).dispose()),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ]),
            ]),
          ),
        TextButton.icon(
          onPressed: () => setState(() => _cases.add(_CaseForm())),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add test case'),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Add question'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'mcq', label: Text('Multiple choice'), icon: Icon(Icons.checklist_rounded)),
                ButtonSegment(value: 'coding', label: Text('Coding'), icon: Icon(Icons.code_rounded)),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() {
                _type = v.first;
                _marks.text = _type == 'mcq' ? '1' : '2';
                _error = null;
              }),
            ),
            const SizedBox(height: 14),
            TextField(key: const Key('q-prompt'), controller: _prompt, decoration: _d('Question'), minLines: 2, maxLines: 5),
            const SizedBox(height: 12),
            TextField(key: const Key('q-marks'), controller: _marks, decoration: _d('Marks'), keyboardType: TextInputType.number),
            const SizedBox(height: 14),
            if (_type == 'mcq') _mcqFields(s) else _codingFields(s),
            if (_error != null)
              Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: s.error))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const Key('save-question'), onPressed: _save, child: const Text('Save question')),
      ],
    );
  }
}

// ----------------------------------------------------------------- Students

class _StudentsTab extends StatefulWidget {
  final TeacherApi api;
  final String id;
  const _StudentsTab({required this.api, required this.id});
  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  late Future<List<Map<String, dynamic>>> _future = widget.api.assignments(widget.id);
  bool _busy = false;

  void _reload() => setState(() { _future = widget.api.assignments(widget.id); });

  Future<void> _import() async {
    final csv = await showDialog<String>(context: context, builder: (_) => const _ImportDialog());
    if (csv == null) return;
    setState(() => _busy = true);
    try {
      final r = await widget.api.importStudents(csv);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => _ImportResultDialog(result: r));
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign() async {
    setState(() => _busy = true);
    try {
      final r = await widget.api.assignAllEligible(widget.id);
      if (mounted) {
        _snack(context, 'Assigned ${r['assigned']} new students');
        _reload();
      }
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text(snap.error.toString()));
        final list = snap.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                OutlinedButton.icon(
                  key: const Key('import-students'),
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Import students (CSV)'),
                ),
                FilledButton.icon(
                  key: const Key('assign-eligible'),
                  onPressed: _busy ? null : _assign,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Assign all eligible'),
                ),
                Text('${list.length} assigned', style: TextStyle(color: s.onSurfaceVariant)),
              ]),
              const SizedBox(height: 14),
              if (list.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No students assigned yet.')))),
              for (final a in list)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${a['fullName']}'.isEmpty ? '?' : '${a['fullName']}'[0])),
                    title: Text('${a['fullName']}'),
                    subtitle: Text('${a['rollNumber'] ?? '-'}  |  ${a['email']}  |  attendance ${a['attendancePct']}%'),
                    trailing: Wrap(spacing: 6, children: [
                      Chip(
                        label: Text(a['eligible'] == true ? 'Eligible' : 'Not eligible'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: a['eligible'] == true ? s.primaryContainer : s.errorContainer,
                      ),
                      Chip(label: Text('${a['attemptStatus']}'.replaceAll('_', ' ')), visualDensity: VisualDensity.compact),
                    ]),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();
  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _c = TextEditingController(text: 'email,full_name,roll_number,attendance_pct\n');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import students'),
      content: SizedBox(
        width: 580,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Paste CSV rows below (header line first). Existing students are updated by email.'),
          const SizedBox(height: 10),
          TextField(
            key: const Key('csv-field'),
            controller: _c,
            minLines: 8,
            maxLines: 14,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const Key('csv-import'), onPressed: () => Navigator.pop(context, _c.text), child: const Text('Import')),
      ],
    );
  }
}

class _ImportResultDialog extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ImportResultDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final errors = (result['errors'] as List?) ?? const [];
    final temp = result['temporaryPassword'] as String?;
    return AlertDialog(
      title: const Text('Import finished'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Created: ${result['created']}   Updated: ${result['updated']}   Rejected rows: ${errors.length}'),
            if (temp != null) ...[
              const SizedBox(height: 14),
              const Text('Temporary password for the new students (shown only once):'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: s.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: SelectableText(temp, key: const Key('temp-password'), style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
              ),
              const SizedBox(height: 6),
              Text('Share it with the students and ask them to change it.', style: TextStyle(color: s.onSurfaceVariant, fontSize: 12)),
            ],
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Rows that were skipped:', style: TextStyle(color: s.error, fontWeight: FontWeight.w600)),
              for (final e in errors) Text('Line ${(e as Map)['line']}: ${e['error']}'),
            ],
            const SizedBox(height: 14),
            const Text('Next: use "Assign all eligible" to give them this assessment.'),
          ]),
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
    );
  }
}

// ------------------------------------------------------------------ Results

class _ResultsTab extends StatefulWidget {
  final TeacherApi api;
  final String id;
  const _ResultsTab({required this.api, required this.id});
  @override
  State<_ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends State<_ResultsTab> {
  late final Future<List<Object>> _future = Future.wait<Object>([
    widget.api.analytics(widget.id),
    widget.api.submissions(widget.id),
  ]);

  Widget _tile(String label, String value, IconData icon, ColorScheme s) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Icon(icon, color: s.primary),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(color: s.onSurfaceVariant, fontSize: 12)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return FutureBuilder<List<Object>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text(snap.error.toString()));
        final an = snap.data![0] as Map<String, dynamic>;
        final subs = snap.data![1] as List<Map<String, dynamic>>;
        final sum = an['summary'] as Map<String, dynamic>;
        final per = (an['perQuestion'] as List).cast<Map<String, dynamic>>();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Row(children: [
                _tile('Submitted', '${sum['attempts']}', Icons.task_alt_rounded, s),
                _tile('Average', _num(sum['average'] as num), Icons.functions_rounded, s),
                _tile('Highest', _num(sum['highest'] as num), Icons.arrow_upward_rounded, s),
                _tile('Lowest', _num(sum['lowest'] as num), Icons.arrow_downward_rounded, s),
                _tile('Pass rate', '${_num(sum['passRate'] as num)}%', Icons.verified_outlined, s),
              ]),
              const SizedBox(height: 20),
              Text('Submissions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (subs.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No attempts yet.')))),
              for (final r in subs)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${r['fullName']}'),
                    subtitle: Text('${r['rollNumber'] ?? '-'}  |  ${r['status']}'.replaceAll('_', ' ')),
                    trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      if ((r['tabSwitches'] as int? ?? 0) > 0)
                        Chip(
                          avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                          label: Text('${r['tabSwitches']} tab switches'),
                          visualDensity: VisualDensity.compact,
                        ),
                      Text(r['score'] == null ? '-' : '${_num(r['score'] as num)} / ${_num(r['maxScore'] as num)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              const SizedBox(height: 20),
              Text('Multiple-choice accuracy', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (per.isEmpty) const Text('No data yet.'),
              for (final q in per)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${q['prompt']}'),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: ((q['accuracyPct'] as num?) ?? 0) / 100, minHeight: 8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(q['accuracyPct'] == null ? 'no answers' : '${_num(q['accuracyPct'] as num)}% (${q['correct']}/${q['answered']})'),
                      ]),
                    ]),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}
