import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../teacher/assessment_page.dart';
import '../teacher/teacher_api.dart';
import '../teacher/teacher_home.dart';
import 'admin_api.dart';

void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

/// Lets the admin choose one batch. Returns its id, or null.
Future<String?> pickBatch(BuildContext context, AdminApi api) async {
  final batches = await api.batches();
  if (!context.mounted) return null;
  if (batches.isEmpty) {
    _snack(context, 'Create a batch first');
    return null;
  }
  return showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(title: const Text('Choose a batch'), children: [
      for (final b in batches)
        SimpleDialogOption(
          key: Key('pick-batch-${b['id']}'),
          onPressed: () => Navigator.pop(c, b['id'] as String),
          child: Text('${b['name']} - ${b['section']}  (${b['courseName']}, ${b['year']})'),
        ),
    ]),
  );
}

class _Page extends StatelessWidget {
  final List<Widget> children;
  const _Page({required this.children});
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(padding: const EdgeInsets.all(AppSpacing.pagePadding), children: children),
        ),
      );
}

// ------------------------------------------------------------------ Students

class AdminStudentsTab extends StatefulWidget {
  final AdminApi api;
  const AdminStudentsTab({super.key, required this.api});
  @override
  State<AdminStudentsTab> createState() => _AdminStudentsTabState();
}

class _AdminStudentsTabState extends State<AdminStudentsTab> {
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _f = widget.api.students('');
  final Set<String> _selected = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() { _f = widget.api.students(_search.text.trim()); });

  Future<void> _enroll() async {
    final batchId = await pickBatch(context, widget.api);
    if (batchId == null || !mounted) return;
    try {
      final r = await widget.api.enroll(batchId, _selected.toList());
      if (!mounted) return;
      _snack(context, 'Enrolled ${r['enrolled']} new students');
      setState(_selected.clear);
      _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  Future<void> _attendance(Map<String, dynamic> s) async {
    final c = TextEditingController(text: '${s['attendancePct']}');
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Attendance - ${s['fullName']}'),
        content: TextField(key: const Key('att-field'), controller: c, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Attendance %')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(key: const Key('att-save'), onPressed: () => Navigator.pop(d, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (v == null || !mounted) return;
    final pct = double.tryParse(v.trim());
    if (pct == null || pct < 0 || pct > 100) {
      _snack(context, 'Enter a number from 0 to 100');
      return;
    }
    try {
      await widget.api.setAttendance(s['id'] as String, pct);
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text(snap.error.toString()));
        final list = (snap.data!['students'] as List).cast<Map<String, dynamic>>();
        final c = context.colors;
        return _Page(children: [
          PageHeader(
            title: 'Students',
            subtitle: '${snap.data!['total']} students',
            trailing: FilledButton.icon(
              key: const Key('enroll-selected'),
              onPressed: _selected.isEmpty ? null : _enroll,
              icon: const Icon(Icons.group_add_outlined),
              label: Text('Enroll ${_selected.length} in batch'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('student-search'),
            controller: _search,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name, email or roll number'),
            onSubmitted: (_) => _reload(),
          ),
          const SizedBox(height: AppSpacing.md),
          if (list.isEmpty) const AppCard(child: Text('No students found.')),
          for (final s in list)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                child: Row(children: [
                  Checkbox(
                    key: Key('sel-${s['id']}'),
                    value: _selected.contains(s['id']),
                    onChanged: (v) => setState(() => v == true ? _selected.add(s['id'] as String) : _selected.remove(s['id'])),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${s['fullName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${s['rollNumber'] ?? '-'}  |  ${s['email']}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                    ]),
                  ),
                  AppBadge('${s['batchCount']} batches'),
                  const SizedBox(width: AppSpacing.sm),
                  AppBadge('${s['attendancePct']}%', tone: (s['attendancePct'] as num) < 75 ? BadgeTone.warning : BadgeTone.success),
                  IconButton(
                    key: Key('att-${s['id']}'),
                    tooltip: 'Edit attendance',
                    onPressed: () => _attendance(s),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

// --------------------------------------------------------------- Assessments

class AdminAssessmentsTab extends StatefulWidget {
  final AdminApi api;
  const AdminAssessmentsTab({super.key, required this.api});
  @override
  State<AdminAssessmentsTab> createState() => _AdminAssessmentsTabState();
}

class _AdminAssessmentsTabState extends State<AdminAssessmentsTab> {
  late final TeacherApi _t = TeacherApi(context.read<ApiClient>());
  late Future<List<Map<String, dynamic>>> _f = _t.assessments();

  void _reload() => setState(() { _f = _t.assessments(); });

  Future<void> _create() async {
    final body = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const NewAssessmentDialog());
    if (body == null) return;
    try {
      await _t.createAssessment(body);
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  Future<void> _manage(Map<String, dynamic> a) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AssessmentDetailPage(assessment: a)));
    if (mounted) _reload();
  }

  Future<void> _assignBatch(Map<String, dynamic> a) async {
    final batchId = await pickBatch(context, widget.api);
    if (batchId == null || !mounted) return;
    try {
      final r = await widget.api.assignBatch(a['id'] as String, batchId);
      if (mounted) {
        _snack(context, 'Assigned ${r['assigned']} new students');
        _reload();
      }
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text(snap.error.toString()));
        final list = snap.data!;
        final c = context.colors;
        return _Page(children: [
          PageHeader(
            title: 'Assessments',
            subtitle: '${list.length} total, from all faculty',
            trailing: FilledButton.icon(
                key: const Key('admin-new-assessment'), onPressed: _create, icon: const Icon(Icons.add), label: const Text('New assessment')),
          ),
          const SizedBox(height: AppSpacing.md),
          if (list.isEmpty) const AppCard(child: Text('No assessments yet.')),
          for (final a in list)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(
                    width: 320,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${a['title']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${a['durationMinutes']} min  |  ${a['questionCount'] ?? 0} questions  |  ${a['assignedCount'] ?? 0} assigned  |  ${a['submittedCount'] ?? 0} submitted',
                          style: TextStyle(color: c.textSecondary, fontSize: 12)),
                    ]),
                  ),
                  AppBadge(a['isPublished'] == true ? 'Published' : 'Draft', tone: a['isPublished'] == true ? BadgeTone.success : BadgeTone.neutral),
                  OutlinedButton(key: Key('manage-${a['id']}'), onPressed: () => _manage(a), child: const Text('Manage')),
                  OutlinedButton(key: Key('assign-batch-${a['id']}'), onPressed: () => _assignBatch(a), child: const Text('Assign batch')),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}
