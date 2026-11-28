import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../auth/auth_state.dart';
import 'admin_api.dart';

void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<String?> _prompt(BuildContext context, String title, List<String> labels, {List<String>? initial}) {
  final ctrls = [for (var i = 0; i < labels.length; i++) TextEditingController(text: initial?[i] ?? '')];
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: TextField(key: Key('f$i'), controller: ctrls[i], decoration: InputDecoration(labelText: labels[i])),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(
          key: const Key('prompt-ok'),
          onPressed: () => Navigator.pop(c, ctrls.map((x) => x.text.trim()).join('\u0001')),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  late final AdminApi _api = AdminApi(context.read<ApiClient>());

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          actions: [
            const ThemeToggleButton(),
            IconButton(tooltip: 'Sign out', onPressed: auth.logout, icon: const Icon(Icons.logout_rounded)),
            const SizedBox(width: AppSpacing.sm),
          ],
          bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Departments'),
            Tab(text: 'Courses'),
            Tab(text: 'Batches'),
            Tab(text: 'Faculty'),
          ]),
        ),
        body: TabBarView(children: [
          _Overview(api: _api, name: auth.user!.fullName),
          _Departments(api: _api),
          _Courses(api: _api),
          _Batches(api: _api),
          _Faculty(api: _api),
        ]),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final Widget child;
  const _Page({required this.child});
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(padding: const EdgeInsets.all(AppSpacing.pagePadding), children: [child]),
        ),
      );
}

class _Overview extends StatelessWidget {
  final AdminApi api;
  final String name;
  const _Overview({required this.api, required this.name});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: api.stats(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text(snap.error.toString()));
        final s = snap.data!;
        Widget tile(String label, String key) => SizedBox(
              width: 220,
              child: AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s[key]}', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(label, style: TextStyle(color: context.colors.textSecondary)),
                ]),
              ),
            );
        return _Page(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PageHeader(title: 'Welcome, $name', subtitle: 'Platform overview'),
            const SizedBox(height: AppSpacing.lg),
            Wrap(spacing: AppSpacing.gridGap, runSpacing: AppSpacing.gridGap, children: [
              tile('Students', 'students'),
              tile('Faculty', 'faculty'),
              tile('Departments', 'departments'),
              tile('Courses', 'courses'),
              tile('Batches', 'batches'),
              tile('Assessments', 'assessments'),
              tile('Active assessments', 'activeAssessments'),
              tile('Submissions', 'submissions'),
            ]),
          ]),
        );
      },
    );
  }
}

/// Shared list tab: loads items, shows rows, and offers add/delete.
class _Departments extends StatefulWidget {
  final AdminApi api;
  const _Departments({required this.api});
  @override
  State<_Departments> createState() => _DepartmentsState();
}

class _DepartmentsState extends State<_Departments> {
  late Future<List<Map<String, dynamic>>> _f = widget.api.departments();
  void _reload() => setState(() { _f = widget.api.departments(); });

  Future<void> _add() async {
    final v = await _prompt(context, 'Add department', ['Name', 'Code']);
    if (v == null) return;
    final p = v.split('\u0001');
    try {
      await widget.api.addDepartment(p[0], p[1]);
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await widget.api.deleteDepartment(id);
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final list = snap.data!;
          return _Page(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PageHeader(
                title: 'Departments',
                subtitle: '${list.length} total',
                trailing: FilledButton.icon(
                    key: const Key('add-department'), onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add department')),
              ),
              const SizedBox(height: AppSpacing.md),
              if (list.isEmpty) const AppCard(child: Text('No departments yet.')),
              for (final d in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: Row(children: [
                      Expanded(child: Text('${d['name']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      AppBadge('${d['code']}'),
                      const SizedBox(width: AppSpacing.sm),
                      Text('${d['courseCount']} courses', style: TextStyle(color: context.colors.textSecondary)),
                      IconButton(
                          tooltip: 'Delete', onPressed: () => _delete(d['id'] as String),
                          icon: Icon(Icons.delete_outline, color: context.colors.danger)),
                    ]),
                  ),
                ),
            ]),
          );
        },
      );
}

class _Courses extends StatefulWidget {
  final AdminApi api;
  const _Courses({required this.api});
  @override
  State<_Courses> createState() => _CoursesState();
}

class _CoursesState extends State<_Courses> {
  late Future<List<Map<String, dynamic>>> _f = widget.api.courses();
  void _reload() => setState(() { _f = widget.api.courses(); });

  Future<void> _add() async {
    final depts = await widget.api.departments();
    if (!mounted) return;
    if (depts.isEmpty) return _snack(context, 'Create a department first');
    final v = await _prompt(context, 'Add course', ['Department code (e.g. ${depts.first['code']})', 'Name', 'Code', 'Semester (1-12)']);
    if (v == null) return;
    final p = v.split('\u0001');
    final dept = depts.where((d) => '${d['code']}'.toUpperCase() == p[0].toUpperCase()).toList();
    final sem = int.tryParse(p[3]);
    if (dept.isEmpty || sem == null) {
      if (mounted) _snack(context, 'Unknown department code or invalid semester');
      return;
    }
    try {
      await widget.api.addCourse({'departmentId': dept.first['id'], 'name': p[1], 'code': p[2], 'semester': sem});
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await widget.api.deleteCourse(id);
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final list = snap.data!;
          return _Page(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PageHeader(
                title: 'Courses',
                subtitle: '${list.length} total',
                trailing: FilledButton.icon(
                    key: const Key('add-course'), onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add course')),
              ),
              const SizedBox(height: AppSpacing.md),
              if (list.isEmpty) const AppCard(child: Text('No courses yet.')),
              for (final c in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${c['departmentName']}', style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                        ]),
                      ),
                      AppBadge('${c['code']}'),
                      const SizedBox(width: AppSpacing.sm),
                      AppBadge('Sem ${c['semester']}'),
                      IconButton(
                          tooltip: 'Delete', onPressed: () => _delete(c['id'] as String),
                          icon: Icon(Icons.delete_outline, color: context.colors.danger)),
                    ]),
                  ),
                ),
            ]),
          );
        },
      );
}

class _Batches extends StatefulWidget {
  final AdminApi api;
  const _Batches({required this.api});
  @override
  State<_Batches> createState() => _BatchesState();
}

class _BatchesState extends State<_Batches> {
  late Future<List<Map<String, dynamic>>> _f = widget.api.batches();
  void _reload() => setState(() { _f = widget.api.batches(); });

  Future<void> _add() async {
    final courses = await widget.api.courses();
    if (!mounted) return;
    if (courses.isEmpty) return _snack(context, 'Create a course first');
    final v = await _prompt(context, 'Add batch',
        ['Course code (e.g. ${courses.first['code']})', 'Batch name', 'Section', 'Year'], initial: ['', '', 'A', '${DateTime.now().year}']);
    if (v == null) return;
    final p = v.split('\u0001');
    final course = courses.where((c) => '${c['code']}'.toUpperCase() == p[0].toUpperCase()).toList();
    final year = int.tryParse(p[3]);
    if (course.isEmpty || year == null) {
      if (mounted) _snack(context, 'Unknown course code or invalid year');
      return;
    }
    try {
      await widget.api.addBatch({'courseId': course.first['id'], 'name': p[1], 'section': p[2], 'year': year});
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  Future<void> _import(Map<String, dynamic> b) async {
    final ctrl = TextEditingController(text: 'email,full_name,roll_number,attendance_pct\n');
    final csv = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Import students into ${b['name']}'),
        content: SizedBox(
          width: 560,
          child: TextField(
              key: const Key('batch-csv'), controller: ctrl, minLines: 8, maxLines: 14,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(key: const Key('batch-import-ok'), onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Import')),
        ],
      ),
    );
    ctrl.dispose();
    if (csv == null) return;
    try {
      final r = await widget.api.importToBatch(b['id'] as String, csv);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Import finished'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Created ${r['created']}, updated ${r['updated']}, enrolled ${r['enrolled']}, rejected ${(r['errors'] as List).length}'),
            if (r['temporaryPassword'] != null) ...[
              const SizedBox(height: AppSpacing.md),
              const Text('Temporary password for new students (shown once):'),
              SelectableText('${r['temporaryPassword']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
            ],
            for (final e in (r['errors'] as List)) Text('Line ${(e as Map)['line']}: ${e['error']}'),
          ]),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))],
        ),
      );
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  Future<void> _viewStudents(Map<String, dynamic> b) async {
    try {
      final list = await widget.api.batchStudents(b['id'] as String);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('${b['name']} students (${list.length})'),
          content: SizedBox(
            width: 480,
            child: list.isEmpty
                ? const Text('No students enrolled.')
                : ListView(shrinkWrap: true, children: [
                    for (final s in list)
                      ListTile(dense: true, title: Text('${s['fullName']}'), subtitle: Text('${s['rollNumber'] ?? '-'}  |  ${s['email']}')),
                  ]),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await widget.api.deleteBatch(id);
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final list = snap.data!;
          return _Page(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PageHeader(
                title: 'Batches',
                subtitle: '${list.length} total',
                trailing: FilledButton.icon(
                    key: const Key('add-batch'), onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add batch')),
              ),
              const SizedBox(height: AppSpacing.md),
              if (list.isEmpty) const AppCard(child: Text('No batches yet.')),
              for (final b in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      SizedBox(
                        width: 260,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${b['name']} - ${b['section']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${b['courseName']} (${b['year']})', style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                        ]),
                      ),
                      AppBadge('${b['studentCount']} students'),
                      OutlinedButton(onPressed: () => _viewStudents(b), child: const Text('Students')),
                      OutlinedButton(key: Key('import-${b['id']}'), onPressed: () => _import(b), child: const Text('Import CSV')),
                      IconButton(
                          tooltip: 'Delete', onPressed: () => _delete(b['id'] as String),
                          icon: Icon(Icons.delete_outline, color: context.colors.danger)),
                    ]),
                  ),
                ),
            ]),
          );
        },
      );
}

class _Faculty extends StatefulWidget {
  final AdminApi api;
  const _Faculty({required this.api});
  @override
  State<_Faculty> createState() => _FacultyState();
}

class _FacultyState extends State<_Faculty> {
  late Future<Map<String, dynamic>> _f = widget.api.users('teacher');
  void _reload() => setState(() { _f = widget.api.users('teacher'); });

  Future<void> _add() async {
    final v = await _prompt(context, 'Add faculty', ['Full name', 'Email']);
    if (v == null) return;
    final p = v.split('\u0001');
    try {
      final r = await widget.api.addFaculty({'fullName': p[0], 'email': p[1]});
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Faculty account created'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Temporary password (shown once):'),
            SelectableText('${r['temporaryPassword']}', key: const Key('faculty-temp'), style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
          ]),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))],
        ),
      );
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final list = (snap.data!['users'] as List).cast<Map<String, dynamic>>();
          return _Page(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PageHeader(
                title: 'Faculty',
                subtitle: '${snap.data!['total']} accounts',
                trailing: FilledButton.icon(
                    key: const Key('add-faculty'), onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add faculty')),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final u in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: Row(children: [
                      Expanded(child: Text('${u['fullName']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('${u['email']}', style: TextStyle(color: context.colors.textSecondary)),
                    ]),
                  ),
                ),
            ]),
          );
        },
      );
}
