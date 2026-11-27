import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:assessly_flutter/core/api_client.dart';
import 'package:assessly_flutter/features/student/exam_page.dart';

http.Response _json(Map<String, dynamic> b, [int status = 200]) =>
    http.Response(jsonEncode(b), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> _attempt({int remaining = 1800, String status = 'in_progress', num? score, num? max}) => {
      'id': 'att1', 'status': status, 'remainingSeconds': remaining, 'tabSwitches': 0,
      'score': score, 'maxScore': max,
    };

List<Map<String, dynamic>> _questions() => [
      {'id': 'q1', 'type': 'mcq', 'prompt': 'What is CI?', 'options': ['A1', 'B1', 'C1', 'D1'], 'marks': 1, 'sampleCases': []},
      {'id': 'q2', 'type': 'mcq', 'prompt': 'What is CD?', 'options': ['A2', 'B2', 'C2', 'D2'], 'marks': 1, 'sampleCases': []},
      {
        'id': 'q3', 'type': 'coding', 'prompt': 'Add two numbers', 'options': null, 'marks': 2,
        'sampleCases': [{'input': '2\n3\n', 'expectedOutput': '5'}],
      },
    ];

MockClient _client(List<http.Request> log, {int remaining = 1800}) => MockClient((req) async {
      log.add(req);
      final p = req.url.path;
      if (req.method == 'GET' && p == '/api/student/attempts/att1') {
        return _json({'attempt': _attempt(remaining: remaining), 'questions': _questions(), 'answers': []});
      }
      if (req.method == 'PUT') return _json({'saved': true, 'remainingSeconds': remaining});
      if (p.endsWith('/submit')) return _json({'attempt': _attempt(status: 'submitted', score: 3, max: 5)});
      if (p.endsWith('/tab-switch')) return _json({'tabSwitches': 1});
      return _json({'error': 'not found'}, 404);
    });

// The exam has a running ticker, so we pump fixed durations instead of pumpAndSettle.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _open(WidgetTester t, MockClient client, {DateTime Function()? now}) async {
  final api = ApiClient(client: client);
  await t.pumpWidget(MultiProvider(
    providers: [Provider<ApiClient>.value(value: api)],
    child: MaterialApp(home: ExamPage(attemptId: 'att1', now: now)),
  ));
  await _settle(t);
}

Future<void> _close(WidgetTester t) => t.pumpWidget(const SizedBox());

void main() {
  testWidgets('loads the attempt: first question, timer and navigation', (t) async {
    await _open(t, _client([]));
    expect(find.text('Question 1 of 3'), findsOneWidget);
    expect(find.text('What is CI?'), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget);
    await _close(t);
  });

  testWidgets('selecting an option autosaves the full answer state', (t) async {
    final log = <http.Request>[];
    await _open(t, _client(log));
    await t.tap(find.byKey(const Key('opt-1')));
    await _settle(t);
    final put = log.firstWhere((r) => r.method == 'PUT');
    expect(put.url.path, endsWith('/answers/q1'));
    final body = jsonDecode(put.body) as Map<String, dynamic>;
    expect(body['selectedOption'], 1);
    expect(body['markedForReview'], false);
    await _close(t);
  });

  testWidgets('mark for review is saved and shown', (t) async {
    final log = <http.Request>[];
    await _open(t, _client(log));
    await t.tap(find.byKey(const Key('mark')));
    await _settle(t);
    final body = jsonDecode(log.firstWhere((r) => r.method == 'PUT').body) as Map<String, dynamic>;
    expect(body['markedForReview'], true);
    expect(find.text('Marked'), findsOneWidget);
    await _close(t);
  });

  testWidgets('Next and the question palette move between questions', (t) async {
    await _open(t, _client([]));
    await t.tap(find.byKey(const Key('next')));
    await _settle(t);
    expect(find.text('Question 2 of 3'), findsOneWidget);
    await t.tap(find.byKey(const Key('nav-2')));
    await _settle(t);
    expect(find.text('Question 3 of 3'), findsOneWidget);
    expect(find.text('Coding question'), findsOneWidget);
    expect(find.byKey(const Key('finish')), findsOneWidget);
    await _close(t);
  });

  testWidgets('submit asks for confirmation, then shows the score', (t) async {
    final log = <http.Request>[];
    await _open(t, _client(log));
    await t.tap(find.byKey(const Key('opt-0')));
    await _settle(t);
    await t.tap(find.byKey(const Key('submit-exam')));
    await _settle(t);
    expect(find.text('Submit your exam?'), findsOneWidget);
    expect(find.textContaining('2 of 3 questions are unanswered'), findsOneWidget);
    await t.tap(find.byKey(const Key('confirm-submit')));
    await _settle(t);
    expect(log.any((r) => r.method == 'POST' && r.url.path.endsWith('/submit')), isTrue);
    expect(find.text('Exam submitted'), findsOneWidget);
    expect(find.text('3 / 5'), findsOneWidget);
    await _close(t);
  });

  testWidgets('submits automatically when the time runs out', (t) async {
    final log = <http.Request>[];
    var clock = DateTime(2026, 1, 1, 10);
    await _open(t, _client(log, remaining: 3), now: () => clock);
    clock = clock.add(const Duration(seconds: 5)); // the deadline has passed
    await t.pump(const Duration(seconds: 1));
    await _settle(t);
    expect(log.any((r) => r.method == 'POST' && r.url.path.endsWith('/submit')), isTrue);
    expect(find.text("Time's up"), findsOneWidget);
    await _close(t);
  });

  testWidgets('records a tab switch and warns when the student comes back', (t) async {
    final log = <http.Request>[];
    await _open(t, _client(log));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await _settle(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(t);
    expect(log.any((r) => r.url.path.endsWith('/tab-switch')), isTrue);
    expect(find.text('Tab switch detected'), findsOneWidget);
    await t.tap(find.byKey(const Key('warn-ok')));
    await _settle(t);
    expect(find.text('Tab switch detected'), findsNothing);
    await _close(t);
  });
}
