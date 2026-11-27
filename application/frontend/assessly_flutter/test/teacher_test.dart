import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:assessly_flutter/core/api_client.dart';
import 'package:assessly_flutter/features/auth/auth_state.dart';
import 'package:assessly_flutter/features/teacher/assessment_page.dart';
import 'package:assessly_flutter/features/teacher/teacher_home.dart';

http.Response _json(Object b, [int status = 200]) =>
    http.Response(jsonEncode(b), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> _assessment({bool published = false}) => {
      'id': 'a1', 'title': 'DevOps Quiz', 'description': '', 'durationMinutes': 30,
      'questionsPerAttempt': 5, 'minAttendancePct': 75, 'isPublished': published,
      'questionCount': 10, 'assignedCount': 3, 'submittedCount': 2,
    };

void _bigScreen(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 2200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

Widget _wrap(MockClient c, Widget home) {
  final api = ApiClient(client: c);
  final auth = AuthState(api)..user = AppUser(id: 't1', email: 't@x.com', fullName: 'Tina Teacher', role: 'teacher');
  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthState>.value(value: auth),
    ],
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('dashboard lists assessments with badges and stats', (t) async {
    _bigScreen(t);
    await t.pumpWidget(_wrap(
        MockClient((_) async => _json({'assessments': [_assessment(published: true)]})), const TeacherHome()));
    await t.pumpAndSettle();
    expect(find.text('Welcome, Tina Teacher'), findsOneWidget);
    expect(find.text('DevOps Quiz'), findsOneWidget);
    expect(find.text('Published'), findsWidgets);
    expect(find.textContaining('3 assigned'), findsOneWidget);
  });

  testWidgets('empty state is shown when there are no assessments', (t) async {
    _bigScreen(t);
    await t.pumpWidget(_wrap(MockClient((_) async => _json({'assessments': []})), const TeacherHome()));
    await t.pumpAndSettle();
    expect(find.textContaining('No assessments yet'), findsOneWidget);
  });

  testWidgets('new assessment dialog validates, then posts the form', (t) async {
    _bigScreen(t);
    final log = <http.Request>[];
    await t.pumpWidget(_wrap(MockClient((req) async {
      log.add(req);
      if (req.method == 'POST') return _json({'assessment': _assessment()}, 201);
      return _json({'assessments': []});
    }), const TeacherHome()));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('new-assessment')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('na-save')));
    await t.pumpAndSettle();
    expect(find.text('Enter a title'), findsOneWidget);
    expect(log.where((r) => r.method == 'POST'), isEmpty);

    await t.enterText(find.byKey(const Key('na-title')), 'Unit Test Quiz');
    await t.tap(find.byKey(const Key('na-save')));
    await t.pumpAndSettle();
    final post = log.firstWhere((r) => r.method == 'POST');
    final body = jsonDecode(post.body) as Map<String, dynamic>;
    expect(body['title'], 'Unit Test Quiz');
    expect(body['durationMinutes'], 30);
    expect(body['questionsPerAttempt'], 5);
  });

  MockClient detailMock(List<http.Request> log) => MockClient((req) async {
        log.add(req);
        final p = req.url.path;
        if (p.endsWith('/questions') && req.method == 'GET') {
          return _json({
            'questions': [
              {'id': 'q1', 'type': 'mcq', 'prompt': 'What is CI?', 'options': ['Yes', 'No'], 'correctOption': 0,
               'marks': 1, 'starterCode': null, 'testCases': []},
            ],
          });
        }
        if (p.endsWith('/questions') && req.method == 'POST') return _json({'id': 'new'}, 201);
        if (p.endsWith('/publish')) {
          return _json({'error': 'Add at least 5 questions before publishing (currently 1)'}, 409);
        }
        if (p.endsWith('/analytics')) {
          return _json({
            'summary': {'attempts': 2, 'average': 3.5, 'highest': 5, 'lowest': 2, 'passRate': 100},
            'perQuestion': [
              {'questionId': 'q1', 'prompt': 'What is CI?', 'answered': 2, 'correct': 1, 'accuracyPct': 50},
            ],
          });
        }
        if (p.endsWith('/submissions')) {
          return _json({
            'submissions': [
              {'attemptId': 'x', 'status': 'submitted', 'fullName': 'Asha Verma', 'rollNumber': 'ROLL001',
               'score': 4, 'maxScore': 5, 'tabSwitches': 2},
            ],
          });
        }
        return _json({'assignments': []});
      });

  testWidgets('questions tab shows the bank and marks the correct option', (t) async {
    _bigScreen(t);
    await t.pumpWidget(_wrap(detailMock([]), AssessmentDetailPage(assessment: _assessment())));
    await t.pumpAndSettle();
    expect(find.text('1 questions in the bank'), findsOneWidget);
    expect(find.text('What is CI?'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
  });

  testWidgets('adding an MCQ posts the options and the correct index', (t) async {
    _bigScreen(t);
    final log = <http.Request>[];
    await t.pumpWidget(_wrap(detailMock(log), AssessmentDetailPage(assessment: _assessment())));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('add-question')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('save-question')));
    await t.pumpAndSettle();
    expect(find.text('Enter the question text'), findsOneWidget);

    await t.enterText(find.byKey(const Key('q-prompt')), 'Which tool scans images?');
    await t.enterText(find.byKey(const Key('opt-0')), 'Terraform');
    await t.enterText(find.byKey(const Key('opt-1')), 'Trivy');
    await t.tap(find.byKey(const Key('correct-1')));
    await t.pump();
    await t.tap(find.byKey(const Key('save-question')));
    await t.pumpAndSettle();
    final post = log.firstWhere((r) => r.method == 'POST');
    final body = jsonDecode(post.body) as Map<String, dynamic>;
    expect(body['type'], 'mcq');
    expect(body['options'], ['Terraform', 'Trivy']);
    expect(body['correctOption'], 1);
  });

  testWidgets('publish failure shows the server message', (t) async {
    _bigScreen(t);
    await t.pumpWidget(_wrap(detailMock([]), AssessmentDetailPage(assessment: _assessment())));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('toggle-publish')));
    await t.pumpAndSettle();
    expect(find.textContaining('Add at least 5 questions'), findsOneWidget);
    expect(find.text('Publish'), findsOneWidget);
  });

  testWidgets('results tab shows summary, submissions and tab switches', (t) async {
    _bigScreen(t);
    await t.pumpWidget(_wrap(detailMock([]), AssessmentDetailPage(assessment: _assessment())));
    await t.pumpAndSettle();
    await t.tap(find.text('Results'));
    await t.pumpAndSettle();
    expect(find.text('Pass rate'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Asha Verma'), findsOneWidget);
    expect(find.text('4 / 5'), findsOneWidget);
    expect(find.text('2 tab switches'), findsOneWidget);
    expect(find.textContaining('50% (1/2)'), findsOneWidget);
  });
}
