import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:assessly_flutter/core/api_client.dart';
import 'package:assessly_flutter/features/auth/auth_state.dart';
import 'package:assessly_flutter/main.dart';

http.Response _json(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

AuthState _auth(MockClient client) => AuthState(ApiClient(client: client));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the login form first', (tester) async {
    final auth = _auth(MockClient((_) async => _json(200, {})));
    await tester.pumpWidget(AssesslyApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.byKey(const Key('email')), findsOneWidget);
  });

  testWidgets('validates empty input without calling the API', (tester) async {
    var calls = 0;
    final auth = _auth(MockClient((_) async {
      calls++;
      return _json(200, {});
    }));
    await tester.pumpWidget(AssesslyApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('a teacher login lands on the teacher dashboard', (tester) async {
    final auth = _auth(MockClient((req) async {
      if (req.url.path == '/api/auth/login') {
        return _json(200, {
          'token': 't',
          'user': {'id': '1', 'email': 'teacher@x.com', 'fullName': 'Tina Teacher', 'role': 'teacher'},
        });
      }
      return _json(404, {'error': 'nope'});
    }));
    await tester.pumpWidget(AssesslyApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email')), 'teacher@x.com');
    await tester.enterText(find.byKey(const Key('password')), 'secret123');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('Teacher dashboard'), findsOneWidget);
    expect(find.text('Welcome, Tina Teacher'), findsOneWidget);
  });

  testWidgets('a student login lands on the student dashboard', (tester) async {
    final auth = _auth(MockClient((req) async => _json(200, {
          'token': 't',
          'user': {'id': '2', 'email': 's@x.com', 'fullName': 'Sam Student', 'role': 'student'},
        })));
    await tester.pumpWidget(AssesslyApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email')), 's@x.com');
    await tester.enterText(find.byKey(const Key('password')), 'secret123');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('Student dashboard'), findsOneWidget);
  });

  testWidgets('shows the server error on a wrong password', (tester) async {
    final auth = _auth(MockClient((_) async => _json(401, {'error': 'Invalid email or password'})));
    await tester.pumpWidget(AssesslyApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email')), 's@x.com');
    await tester.enterText(find.byKey(const Key('password')), 'wrongpass');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(find.text('Student dashboard'), findsNothing);
  });
}
