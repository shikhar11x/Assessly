import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import 'exam_api.dart';
import 'student_api.dart';

/// Code editor with Run (sample case) and Submit (all cases). Python 3 only.
class CodePanel extends StatefulWidget {
  final String attemptId;
  final String questionId;
  final String initialCode;
  final List<Map<String, String>> samples;
  final ValueChanged<String> onChanged;
  const CodePanel({
    super.key,
    required this.attemptId,
    required this.questionId,
    required this.initialCode,
    required this.samples,
    required this.onChanged,
  });
  @override
  State<CodePanel> createState() => _CodePanelState();
}

class _CodePanelState extends State<CodePanel> {
  late final TextEditingController _c = TextEditingController(text: widget.initialCode);
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _out;

  static const _verdicts = {
    'passed': 'Passed',
    'wrong_answer': 'Wrong answer',
    'timeout': 'Time limit exceeded',
    'runtime_error': 'Runtime error',
    'output_limit': 'Too much output',
  };

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _insertTab() {
    final sel = _c.selection;
    if (!sel.isValid) return;
    final text = _c.text.replaceRange(sel.start, sel.end, '    ');
    _c.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: sel.start + 4));
    widget.onChanged(text);
  }

  Future<void> _go({required bool submit}) async {
    final code = _c.text;
    if (code.trim().isEmpty) {
      setState(() => _error = 'Write some code first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = StudentApi(context.read<ApiClient>());
      final r = submit
          ? await api.submitCode(widget.attemptId, widget.questionId, code)
          : await api.runCode(widget.attemptId, widget.questionId, code);
      if (mounted) setState(() => _out = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _num(num n) => n % 1 == 0 ? n.toStringAsFixed(0) : n.toStringAsFixed(2);

  Widget _mono(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          SelectableText(value.isEmpty ? '(empty)' : value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        ]),
      );

  Widget _caseTile(Map<String, dynamic> r, ColorScheme s) {
    final ok = r['passed'] == true;
    final sample = r['isSample'] == true;
    final color = ok ? Colors.green.shade600 : s.error;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        color: color.withValues(alpha: 0.07),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 20),
          const SizedBox(width: 8),
          Text('Test case ${r['index']}${sample ? ' (sample)' : ' (hidden)'}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(_verdicts['${r['verdict']}'] ?? '${r['verdict']}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ]),
        if (sample && !ok) ...[
          _mono('Input', '${r['input'] ?? ''}', s.onSurfaceVariant),
          _mono('Expected output', '${r['expectedOutput'] ?? ''}', s.onSurfaceVariant),
          _mono('Your output', '${r['actual'] ?? ''}', s.onSurfaceVariant),
          if ('${r['stderr'] ?? ''}'.isNotEmpty) _mono('Error', '${r['stderr']}', s.error),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final out = _out;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.code_rounded, color: s.primary),
        const SizedBox(width: 8),
        const Text('Coding question', style: TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('Python 3', style: TextStyle(color: s.onSurfaceVariant, fontSize: 12)),
      ]),
      const SizedBox(height: 4),
      Text('Read input with input() and print the answer.',
          style: TextStyle(color: s.onSurfaceVariant, fontSize: 13)),
      for (final c in widget.samples) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: s.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _mono('Sample input', '${c['input']}', s.onSurfaceVariant),
            _mono('Expected output', '${c['expected']}', s.onSurfaceVariant),
          ]),
        ),
      ],
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(color: const Color(0xFF14141C), borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(12),
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.tab): _insertTab},
          child: TextField(
            key: const Key('code-field'),
            controller: _c,
            minLines: 10,
            maxLines: 22,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.5, color: Color(0xFFE6E6F0)),
            cursorColor: const Color(0xFF9B9BFF),
            decoration: const InputDecoration(border: InputBorder.none, hintText: '# write your solution here',
                hintStyle: TextStyle(color: Color(0xFF6B6B80))),
            onChanged: widget.onChanged,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton.icon(
          key: const Key('run-code'),
          onPressed: _busy ? null : () => _go(submit: false),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Run (sample)'),
        ),
        FilledButton.icon(
          key: const Key('submit-code'),
          onPressed: _busy ? null : () => _go(submit: true),
          icon: const Icon(Icons.task_alt_rounded),
          label: const Text('Submit code'),
        ),
        if (_busy) const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ]),
      if (_error != null)
        Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: s.error))),
      if (out != null) ...[
        const SizedBox(height: 14),
        Text('Passed ${out['passed']} of ${out['total']} test cases',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        if (out['kind'] == 'submit')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${_num(out['marksAwarded'] as num)} / ${_num(out['maxMarks'] as num)} marks saved',
                style: TextStyle(color: s.primary, fontWeight: FontWeight.w600)),
          ),
        for (final r in (out['results'] as List)) _caseTile(r as Map<String, dynamic>, s),
      ],
    ]);
  }
}
