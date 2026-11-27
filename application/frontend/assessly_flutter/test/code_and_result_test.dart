import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:assessly_flutter/core/api_client.dart';
import 'package:assessly_flutter/features/student/code_panel.dart';
import 'package:assessly_flutter/features/student/result_page.dart';

http.Response _json(Map<String, dynamic> b, [int status = 200]) =>
    http.Response(jsonEncode(b), status, headers: {'content-type': 'application/json'});

Future<void> _pumpPanel(WidgetTester t, MockClient c, List<String> changed) async {
  t.view.physicalSize = const Size(1000, 1800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(Provider<ApiClient>.value(
    value: ApiClient(client: c),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CodePanel(
            attemptId: 'a1',
            questionId: 'q1',
            initialCode: '# start',
            samples: const [{'input': '2\n3\n', 'expected': '5'}],
            onChanged: changed.add,
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('Run shows the sample verdict', (t) async {
    final log = <http.Request>[];
    await _pumpPanel(t, MockClient((req) async {
      log.add(req);
      return _json({
        'kind': 'run', 'passed': 1, 'total': 1,
        'results': [{'index': 1, 'isSample': true, 'passed': true, 'verdict': 'passed'}],
      });
    }), []);
    await t.tap(find.byKey(const Key('run-code')));
    await t.pumpAndSettle();
    expect(log.single.url.path, endsWith('/questions/q1/run'));
    expect(find.text('Passed 1 of 1 test cases'), findsOneWidget);
    expect(find.text('Passed'), findsOneWidget);
  });

  testWidgets('Submit shows marks, and a failing sample shows expected vs actual', (t) async {
    await _pumpPanel(t, MockClient((req) async => _json({
          'kind': 'submit', 'passed': 2, 'total': 3, 'marksAwarded': 1.33, 'maxMarks': 2,
          'results': [
            {'index': 1, 'isSample': true, 'passed': false, 'verdict': 'wrong_answer',
             'input': '2\n3\n', 'expectedOutput': '5', 'actual': '6', 'stderr': ''},
            {'index': 2, 'isSample': false, 'passed': true, 'verdict': 'passed'},
            {'index': 3, 'isSample': false, 'passed': true, 'verdict': 'passed'},
          ],
        })), []);
    await t.tap(find.byKey(const Key('submit-code')));
    await t.pumpAndSettle();
    expect(find.text('Passed 2 of 3 test cases'), findsOneWidget);
    expect(find.text('1.33 / 2 marks saved'), findsOneWidget);
    expect(find.text('Wrong answer'), findsOneWidget);
    expect(find.text('Your output'), findsOneWidget);
    expect(find.text('(hidden)', findRichText: true, skipOffstage: false), findsNothing);
  });

  testWidgets('typing reports changes and empty code is blocked', (t) async {
    final changed = <String>[];
    var calls = 0;
    await _pumpPanel(t, MockClient((_) async {
      calls++;
      return _json({});
    }), changed);
    await t.enterText(find.byKey(const Key('code-field')), 'print(1)');
    expect(changed.last, 'print(1)');
    await t.enterText(find.byKey(const Key('code-field')), '   ');
    await t.tap(find.byKey(const Key('run-code')));
    await t.pump();
    expect(find.text('Write some code first.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('result page shows score, correct and wrong options', (t) async {
    final client = MockClient((_) async => _json({
          'attempt': {'status': 'submitted', 'score': 3, 'maxScore': 5, 'tabSwitches': 0},
          'breakdown': [
            {'questionId': 'q1', 'type': 'mcq', 'prompt': 'Which tool scans images?', 'marks': 1,
             'options': ['Trivy', 'Terraform'], 'correctOption': 0, 'selectedOption': 1, 'marksAwarded': 0, 'status': 'graded'},
            {'questionId': 'q2', 'type': 'coding', 'prompt': 'Add two numbers', 'marks': 2,
             'options': null, 'correctOption': null, 'selectedOption': null, 'marksAwarded': 2, 'status': 'graded'},
          ],
        }));
    await t.pumpWidget(Provider<ApiClient>.value(
      value: ApiClient(client: client),
      child: const MaterialApp(home: ResultPage(attemptId: 'a1')),
    ));
    await t.pumpAndSettle();
    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.text('Which tool scans images?'), findsOneWidget);
    expect(find.text('Correct answer'), findsOneWidget);
    expect(find.text('Your answer'), findsOneWidget);
    expect(find.text('Graded by test cases'), findsOneWidget);
  });

  testWidgets('result page shows the server message when the attempt is still open', (t) async {
    final client = MockClient((_) async => _json({'error': 'Result is available after submission'}, 409));
    await t.pumpWidget(Provider<ApiClient>.value(
      value: ApiClient(client: client),
      child: const MaterialApp(home: ResultPage(attemptId: 'a1')),
    ));
    await t.pumpAndSettle();
    expect(find.text('Result is available after submission'), findsOneWidget);
  });
}
