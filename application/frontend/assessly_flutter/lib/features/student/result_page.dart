import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'exam_api.dart';
import 'student_api.dart';

/// Per-question breakdown of a closed attempt.
class ResultPage extends StatefulWidget {
  final String attemptId;
  const ResultPage({super.key, required this.attemptId});
  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late final Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = StudentApi(context.read<ApiClient>()).result(widget.attemptId);
  }

  String _num(num n) => n % 1 == 0 ? n.toStringAsFixed(0) : n.toStringAsFixed(2);

  Widget _option(String text, int i, int? correct, int? selected, ColorScheme s) {
    final isCorrect = i == correct;
    final wrongPick = i == selected && i != correct;
    final color = isCorrect ? Colors.green.shade600 : (wrongPick ? s.error : s.onSurfaceVariant);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isCorrect || wrongPick) ? color : s.outlineVariant),
        color: (isCorrect || wrongPick) ? color.withValues(alpha: 0.08) : null,
      ),
      child: Row(children: [
        Icon(isCorrect ? Icons.check_circle_rounded : (wrongPick ? Icons.cancel_rounded : Icons.circle_outlined),
            color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
        if (isCorrect) Text('Correct answer', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        if (wrongPick) Text('Your answer', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _question(int n, Map<String, dynamic> q, ColorScheme s) {
    final isMcq = q['type'] == 'mcq';
    final awarded = (q['marksAwarded'] as num?) ?? 0;
    final marks = q['marks'] as num;
    final selected = q['selectedOption'] as int?;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Question $n', style: TextStyle(color: s.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: awarded >= marks ? Colors.green.withValues(alpha: 0.15) : s.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999)),
              child: Text('${_num(awarded)} / ${_num(marks)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Text('${q['prompt']}', style: Theme.of(context).textTheme.titleMedium),
          if (isMcq) ...[
            if (selected == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('You did not answer this question.', style: TextStyle(color: s.error)),
              ),
            for (var i = 0; i < (q['options'] as List).length; i++)
              _option('${(q['options'] as List)[i]}', i, q['correctOption'] as int?, selected, s),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Icon(Icons.code_rounded, size: 18, color: s.primary),
                const SizedBox(width: 8),
                Text(q['status'] == 'graded' ? 'Graded by test cases' : 'No code was submitted for this question',
                    style: TextStyle(color: s.onSurfaceVariant)),
              ]),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Detailed result'), actions: const [ThemeToggleButton(), SizedBox(width: 8)]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final a = snap.data!['attempt'] as Map<String, dynamic>;
          final list = (snap.data!['breakdown'] as List).cast<Map<String, dynamic>>();
          final score = (a['score'] as num?) ?? 0;
          final max = (a['maxScore'] as num?) ?? 0;
          final pct = max > 0 ? (score / max).clamp(0.0, 1.0).toDouble() : 0.0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(children: [
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: Stack(fit: StackFit.expand, children: [
                          CircularProgressIndicator(value: pct, strokeWidth: 9, backgroundColor: s.surfaceContainerHighest),
                          Center(child: Text('${(pct * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
                        ]),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${_num(score)} / ${_num(max)}',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text(a['status'] == 'expired' ? 'Submitted automatically when time ran out' : 'Submitted by you',
                              style: TextStyle(color: s.onSurfaceVariant)),
                          if ((a['tabSwitches'] as int? ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('Tab switches recorded: ${a['tabSwitches']}', style: TextStyle(color: s.error)),
                            ),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < list.length; i++) _question(i + 1, list[i], s),
              ]),
            ),
          );
        },
      ),
    );
  }
}
