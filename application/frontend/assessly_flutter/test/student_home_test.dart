import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:assessly_flutter/core/api_client.dart';
import 'package:assessly_flutter/features/auth/auth_state.dart';
import 'package:assessly_flutter/features/student/student_home.dart';

Map<String, dynamic> _item(String id, String title,
        {bool eligible = true, String status = 'not_started', double? score, double? max}) =>
    {
      'id': id, 'title': title, 'description': 'desc $title', 'durationMinutes': 30,
      'questionsPerAttempt': 5, 'minAttendancePct': 75, 'eligible': eligible,
      'attemptId': status == 'not_started' ? null : 'att-$id', 'attemptStatus': status,
      'score': score, 'maxScore': max,
    };

Widget _app(List<Map<String, dynamic>> items, {double attendance = 92}) {
  final client = MockClient((req) async => http.Response(
      jsonEncode({'attendancePct': attendance, 'assessments': items}), 200,
      headers: {'content-type': 'application/json'}));
  final api = ApiClient(client: client);
  final auth = AuthState(api)
    ..user = AppUser(id: '1', email: 's@x.com', fullName: 'Asha Verma', role: 'student');
  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthState>.value(value: auth),
    ],
    child: const MaterialApp(home: StudentHome()),
  );
}

void main() {
  testWidgets('shows attendance and a Start button for an eligible assessment', (t) async {
    await t.pumpWidget(_app([_item('a1', 'DevOps Quiz')]));
    await t.pumpAndSettle();
    expect(find.text('Welcome, Asha Verma'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('DevOps Quiz'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('blocks a student below the attendance minimum', (t) async {
    await t.pumpWidget(_app([_item('a1', 'DevOps Quiz', eligible: false)], attendance: 60));
    await t.pumpAndSettle();
    expect(find.text('Not eligible'), findsOneWidget);
    expect(find.textContaining('below the required 75%'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
  });

  testWidgets('shows Resume for in-progress and the score when completed', (t) async {
    await t.pumpWidget(_app([
      _item('a1', 'Quiz One', status: 'in_progress'),
      _item('a2', 'Quiz Two', status: 'submitted', score: 4, max: 5),
    ]));
    await t.pumpAndSettle();
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Completed: 4 / 5'), findsOneWidget);
  });

  testWidgets('asks for confirmation before starting', (t) async {
    await t.pumpWidget(_app([_item('a1', 'DevOps Quiz')]));
    await t.pumpAndSettle();
    await t.tap(find.text('Start'));
    await t.pumpAndSettle();
    expect(find.textContaining('timer starts immediately'), findsOneWidget);
  });
}
