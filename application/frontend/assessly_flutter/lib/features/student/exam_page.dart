import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'code_panel.dart';
import 'exam_api.dart';
import 'result_page.dart';
import 'student_api.dart';

class ExamQuestion {
  final String id;
  final String type;
  final String prompt;
  final List<String> options;
  final int marks;
  final List<Map<String, String>> samples;
  final String starter;
  int? selected;
  String? code;
  bool marked;

  ExamQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    required this.options,
    required this.marks,
    required this.samples,
    this.starter = '',
    this.selected,
    this.code,
    this.marked = false,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> j, Map<String, dynamic>? a) => ExamQuestion(
        id: j['id'] as String,
        type: j['type'] as String,
        prompt: j['prompt'] as String,
        options: ((j['options'] as List?) ?? const []).map((e) => e.toString()).toList(),
        marks: j['marks'] as int,
        starter: (j['starterCode'] ?? '') as String,
        samples: ((j['sampleCases'] as List?) ?? const []).map((e) {
          final m = e as Map<String, dynamic>;
          return {'input': '${m['input']}', 'expected': '${m['expectedOutput']}'};
        }).toList(),
        selected: a?['selectedOption'] as int?,
        code: a?['code'] as String?,
        marked: (a?['markedForReview'] as bool?) ?? false,
      );

  bool get isMcq => type == 'mcq';
  bool get answered => isMcq ? selected != null : (code != null && code!.trim().isNotEmpty);
}

class ExamPage extends StatefulWidget {
  final String attemptId;

  /// Clock override, used by tests to simulate the deadline passing.
  final DateTime Function()? now;
  const ExamPage({super.key, required this.attemptId, this.now});
  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> with WidgetsBindingObserver {
  late final StudentApi _api;
  List<ExamQuestion> _qs = [];
  int _index = 0;
  bool _loading = true;
  String? _error;
  String? _saveError;

  DateTime _deadline = DateTime.now();
  int _remaining = 0;
  Timer? _ticker;

  bool _submitting = false;
  bool _closed = false;
  bool _autoSubmitted = false;
  Map<String, dynamic>? _result;

  int _tabSwitches = 0;
  bool _wasHidden = false;
  bool _warningOpen = false;

  Future<void> _saveQueue = Future.value();

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = StudentApi(context.read<ApiClient>());
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  // ---------- loading and timer ----------

  void _setRemaining(int seconds) {
    _remaining = seconds;
    _deadline = _now().add(Duration(seconds: seconds));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.attempt(widget.attemptId);
      final attempt = res['attempt'] as Map<String, dynamic>;
      final answers = <String, Map<String, dynamic>>{};
      for (final a in res['answers'] as List) {
        final m = a as Map<String, dynamic>;
        answers[m['questionId'] as String] = m;
      }
      _qs = (res['questions'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return ExamQuestion.fromJson(m, answers[m['id']]);
      }).toList();
      _tabSwitches = (attempt['tabSwitches'] as int?) ?? 0;
      if (attempt['status'] != 'in_progress') {
        _closed = true;
        _result = attempt;
      } else {
        _setRemaining(attempt['remainingSeconds'] as int);
        _ticker?.cancel();
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      }
      if (mounted) setState(() => _loading = false);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  void _tick() {
    if (!mounted || _closed) return;
    final ms = _deadline.difference(_now()).inMilliseconds;
    final left = ms <= 0 ? 0 : (ms / 1000).ceil();
    setState(() => _remaining = left);
    if (left <= 0 && !_submitting) _submit(auto: true);
  }

  String _fmt(int s) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }

  String _num(num n) => n % 1 == 0 ? n.toStringAsFixed(0) : n.toStringAsFixed(2);

  // ---------- saving ----------

  void _queueSave(ExamQuestion q) {
    _saveQueue = _saveQueue.then((_) => _doSave(q));
  }

  Future<void> _doSave(ExamQuestion q) async {
    try {
      final r = await _api.saveAnswer(widget.attemptId, q.id,
          selectedOption: q.selected, code: q.code, marked: q.marked);
      final rs = r['remainingSeconds'];
      if (rs is int && !_closed) _setRemaining(rs);
      if (mounted && _saveError != null) setState(() => _saveError = null);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 409) {
        await _refreshClosed();
      } else {
        setState(() => _saveError = 'Could not save your last change (${e.message}). It will retry on your next action.');
      }
    }
  }

  void _select(ExamQuestion q, int? option) {
    setState(() => q.selected = option);
    _queueSave(q);
  }

  Timer? _codeDebounce;
  ExamQuestion? _pendingCode;

  /// Code is saved about a second after the student stops typing.
  void _codeChanged(ExamQuestion q, String code) {
    q.code = code;
    _pendingCode = q;
    _codeDebounce?.cancel();
    _codeDebounce = Timer(const Duration(milliseconds: 900), _flushCode);
    setState(() {});
  }

  void _flushCode() {
    _codeDebounce?.cancel();
    final q = _pendingCode;
    if (q != null) {
      _pendingCode = null;
      _queueSave(q);
    }
  }

  void _toggleMark(ExamQuestion q) {
    setState(() => q.marked = !q.marked);
    _queueSave(q);
  }

  // ---------- submit and close ----------

  Future<bool> _confirmSubmit() async {
    final unanswered = _qs.where((q) => !q.answered).length;
    final marked = _qs.where((q) => q.marked).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Submit your exam?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(unanswered == 0
              ? 'You have answered every question.'
              : '$unanswered of ${_qs.length} questions are unanswered.'),
          if (marked > 0) Text('$marked marked for review.'),
          const SizedBox(height: 8),
          const Text('You cannot change your answers after submitting.'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep working')),
          FilledButton(
              key: const Key('confirm-submit'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Submit')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting || _closed) return;
    if (!auto && !await _confirmSubmit()) return;
    if (!mounted) return;
    setState(() => _submitting = true);
    try {
      _flushCode();
      await _saveQueue; // make sure the last answers reached the server
      final res = await _api.submit(widget.attemptId);
      _ticker?.cancel();
      if (!mounted) return;
      setState(() {
        _closed = true;
        _submitting = false;
        _autoSubmitted = auto;
        _result = res['attempt'] as Map<String, dynamic>;
      });
    } on ApiException catch (e) {
      if (e.status == 409) {
        await _refreshClosed();
      } else if (mounted) {
        setState(() => _submitting = false);
        if (!auto) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// The server says the attempt is closed (time up or already submitted): show the outcome.
  Future<void> _refreshClosed() async {
    try {
      final res = await _api.attempt(widget.attemptId);
      final a = res['attempt'] as Map<String, dynamic>;
      if (a['status'] == 'in_progress') return;
      _ticker?.cancel();
      if (mounted) {
        setState(() {
          _closed = true;
          _submitting = false;
          _autoSubmitted = a['status'] == 'expired';
          _result = a;
        });
      }
    } on ApiException catch (_) {}
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave the exam?'),
        content: const Text('Your timer keeps running. You can resume from the dashboard until time runs out.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  // ---------- tab-switch detection ----------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closed || _loading) return;
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      if (!_wasHidden) {
        _wasHidden = true;
        _recordSwitch();
      }
    } else if (state == AppLifecycleState.resumed && _wasHidden) {
      _wasHidden = false;
      _showWarning();
    }
  }

  Future<void> _recordSwitch() async {
    setState(() => _tabSwitches++);
    try {
      final r = await _api.tabSwitch(widget.attemptId);
      final n = r['tabSwitches'];
      if (n is int && mounted) setState(() => _tabSwitches = n);
    } catch (_) {}
  }

  Future<void> _showWarning() async {
    if (_warningOpen || !mounted || _closed) return;
    _warningOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: Theme.of(c).colorScheme.error, size: 36),
        title: const Text('Tab switch detected'),
        content: Text('You left the exam tab. This was recorded and your teacher can see it '
            '($_tabSwitches so far). Please stay on this page until you submit.'),
        actions: [
          FilledButton(
              key: const Key('warn-ok'), onPressed: () => Navigator.pop(c), child: const Text('I understand')),
        ],
      ),
    );
    _warningOpen = false;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _closed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assessment')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }
    if (_closed) return _closedView(context);
    if (_qs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assessment')),
        body: const Center(child: Text('This assessment has no questions.')),
      );
    }
    return _examView(context);
  }

  Widget _closedView(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final r = _result;
    final score = (r?['score'] as num?)?.toDouble();
    final max = (r?['maxScore'] as num?)?.toDouble();
    final pct = (score != null && max != null && max > 0) ? (score / max).clamp(0.0, 1.0).toDouble() : 0.0;
    final timeUp = _autoSubmitted || r?['status'] == 'expired';
    return Scaffold(
      appBar: AppBar(
        title: Text('Assessment'),
        automaticallyImplyLeading: false,
        actions: [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(timeUp ? Icons.timer_off_rounded : Icons.check_circle_rounded,
                      size: 44, color: timeUp ? s.tertiary : s.primary),
                  const SizedBox(height: 12),
                  Text(timeUp ? "Time's up" : 'Exam submitted',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(timeUp ? 'Your answers were submitted automatically.' : 'Your answers have been recorded.',
                      textAlign: TextAlign.center, style: TextStyle(color: s.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(fit: StackFit.expand, children: [
                      CircularProgressIndicator(
                          value: pct, strokeWidth: 12, backgroundColor: s.surfaceContainerHighest),
                      Center(
                        child: Text(score == null ? '-' : '${(pct * 100).round()}%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Text(score != null && max != null ? '${_num(score)} / ${_num(max)}' : 'Score pending',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (_tabSwitches > 0) ...[
                    const SizedBox(height: 8),
                    Text('Tab switches recorded: $_tabSwitches', style: TextStyle(color: s.error)),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('view-result'),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ResultPage(attemptId: widget.attemptId))),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('View detailed result'),
                  ),
                  const SizedBox(height: 12),
                  Text('Multiple-choice marks are counted now. Coding marks count only for code you submitted.',
                      textAlign: TextAlign.center, style: TextStyle(color: s.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('back-dashboard'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to dashboard'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _examView(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final q = _qs[_index];

    final Color timerBg;
    final Color timerFg;
    if (_remaining <= 60) {
      timerBg = s.errorContainer;
      timerFg = s.onErrorContainer;
    } else if (_remaining <= 300) {
      timerBg = s.tertiaryContainer;
      timerFg = s.onTertiaryContainer;
    } else {
      timerBg = s.primaryContainer;
      timerFg = s.onPrimaryContainer;
    }

    return Scaffold(
      appBar: AppBar(
        title: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: timerBg, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.timer_outlined, size: 20, color: timerFg),
            const SizedBox(width: 8),
            Text(_fmt(_remaining),
                key: const Key('timer'),
                style: TextStyle(color: timerFg, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),
        actions: [
          if (_tabSwitches > 0)
            Tooltip(
              message: 'Tab switches recorded',
              child: Chip(avatar: const Icon(Icons.warning_amber_rounded, size: 18), label: Text('$_tabSwitches')),
            ),
          const ThemeToggleButton(),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: FilledButton.icon(
              key: const Key('submit-exam'),
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Submit'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final main = Column(children: [
          if (!wide) _stripNav(s),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 24 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: _questionCard(q, s),
                ),
              ),
            ),
          ),
          _bottomBar(q, s),
        ]);
        if (!wide) return main;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: main),
          SizedBox(
            width: 300,
            child: Padding(padding: const EdgeInsets.fromLTRB(0, 24, 24, 24), child: _sidePanel(s)),
          ),
        ]);
      }),
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
      );

  Widget _questionCard(ExamQuestion q, ColorScheme s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _pill('Question ${_index + 1} of ${_qs.length}', s.primaryContainer, s.onPrimaryContainer),
            const SizedBox(width: 8),
            _pill('${q.marks} ${q.marks == 1 ? 'mark' : 'marks'}', s.secondaryContainer, s.onSecondaryContainer),
            const Spacer(),
            if (q.marked) Icon(Icons.flag_rounded, color: s.tertiary),
          ]),
          const SizedBox(height: 20),
          Text(q.prompt, style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.4)),
          const SizedBox(height: 20),
          if (q.isMcq) ...[
            for (var i = 0; i < q.options.length; i++) _optionTile(q, i, s),
            if (q.selected != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('clear'),
                  onPressed: () => _select(q, null),
                  icon: const Icon(Icons.backspace_outlined, size: 18),
                  label: const Text('Clear answer'),
                ),
              ),
          ] else
            CodePanel(
              key: ValueKey(q.id),
              attemptId: widget.attemptId,
              questionId: q.id,
              initialCode: q.code ?? q.starter,
              samples: q.samples,
              onChanged: (c) => _codeChanged(q, c),
            ),
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_saveError!, style: TextStyle(color: s.error, fontSize: 13)),
            ),
        ]),
      ),
    );
  }

  Widget _optionTile(ExamQuestion q, int i, ColorScheme s) {
    final sel = q.selected == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: sel ? s.primaryContainer.withValues(alpha: 0.6) : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: sel ? s.primary : s.outlineVariant, width: sel ? 2 : 1),
        ),
        child: InkWell(
          key: Key('opt-$i'),
          onTap: () => _select(q, sel ? null : i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: sel ? s.primary : s.surfaceContainerHighest,
                foregroundColor: sel ? s.onPrimary : s.onSurfaceVariant,
                child: sel ? const Icon(Icons.check, size: 18) : Text(String.fromCharCode(65 + i)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(q.options[i], style: Theme.of(context).textTheme.bodyLarge)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _navTile(int i, ColorScheme s) {
    final q = _qs[i];
    final current = i == _index;
    Color bg = s.surfaceContainerHighest;
    Color fg = s.onSurface;
    if (q.answered) {
      bg = s.primaryContainer;
      fg = s.onPrimaryContainer;
    }
    if (q.marked) {
      bg = s.tertiaryContainer;
      fg = s.onTertiaryContainer;
    }
    if (current) {
      bg = s.primary;
      fg = s.onPrimary;
    }
    return Material(
      color: bg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: current ? Colors.transparent : s.outlineVariant),
      ),
      child: InkWell(
        key: Key('nav-$i'),
        onTap: () => setState(() => _index = i),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(alignment: Alignment.center, children: [
            Text('${i + 1}', style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
            if (q.marked)
              Positioned(top: 3, right: 3, child: Icon(Icons.flag_rounded, size: 12, color: fg)),
          ]),
        ),
      ),
    );
  }

  Widget _stripNav(ColorScheme s) => SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: _qs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => _navTile(i, s),
        ),
      );

  Widget _legend(Color c, String label, ColorScheme s) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
              color: c, borderRadius: BorderRadius.circular(4), border: Border.all(color: s.outlineVariant)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: s.onSurfaceVariant)),
      ]);

  Widget _sidePanel(ColorScheme s) {
    final answered = _qs.where((q) => q.answered).length;
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Progress', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('$answered of ${_qs.length} answered', style: TextStyle(color: s.onSurfaceVariant)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: _qs.isEmpty ? 0 : answered / _qs.length, minHeight: 8),
          ),
          const SizedBox(height: 20),
          Text('Questions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < _qs.length; i++) _navTile(i, s)]),
          const SizedBox(height: 20),
          Wrap(spacing: 14, runSpacing: 8, children: [
            _legend(s.primary, 'Current', s),
            _legend(s.primaryContainer, 'Answered', s),
            _legend(s.tertiaryContainer, 'For review', s),
            _legend(s.surfaceContainerHighest, 'Not answered', s),
          ]),
        ]),
      ),
    );
  }

  Widget _bottomBar(ExamQuestion q, ColorScheme s) {
    final last = _index == _qs.length - 1;
    return Material(
      color: Theme.of(context).cardTheme.color ?? s.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('prev'),
                  onPressed: _index == 0 ? null : () => setState(() => _index--),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Previous'),
                ),
                TextButton.icon(
                  key: const Key('mark'),
                  onPressed: () => _toggleMark(q),
                  icon: Icon(q.marked ? Icons.flag_rounded : Icons.outlined_flag_rounded),
                  label: Text(q.marked ? 'Marked' : 'Mark for review'),
                ),
                if (last)
                  FilledButton.icon(
                    key: const Key('finish'),
                    onPressed: _submitting ? null : _submit,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Finish'),
                  )
                else
                  FilledButton.icon(
                    key: const Key('next'),
                    onPressed: () => setState(() => _index++),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
