import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:assessly_flutter/core/api_client.dart';
import 'package:assessly_flutter/core/theme.dart';
import 'package:assessly_flutter/features/admin/admin_home.dart';
import 'package:assessly_flutter/features/auth/auth_state.dart';

http.Response _json(Object b, [int s = 200]) =>
    http.Response(jsonEncode(b), s, headers: {'content-type': 'application/json'});

Widget _app(MockClient c) {
  final api = ApiClient(client: c);
  final auth = AuthState(api)..user = AppUser(id: '1', email: 'a@x.com', fullName: 'Ada Admin', role: 'admin');
  return MultiProvider(
    providers: [Provider<ApiClient>.value(value: api), ChangeNotifierProvider<AuthState>.value(value: auth)],
    child: MaterialApp(theme: AppTheme.light(), home: const AdminHome()),
  );
}

MockClient _mock(List<http.Request> log) => MockClient((req) async {
      log.add(req);
      final p = req.url.path;
      if (p == '/api/admin/stats') {
        return _json({'students': 12, 'faculty': 3, 'departments': 2, 'courses': 5, 'batches': 4,
          'assessments': 7, 'activeAssessments': 2, 'submissions': 40});
      }
      if (p == '/api/admin/departments' && req.method == 'GET') {
        return _json({'departments': [{'id': 'd1', 'name': 'Computer Science', 'code': 'CSE', 'courseCount': 3}]});
      }
      if (p == '/api/admin/departments' && req.method == 'POST') return _json({'department': {}}, 201);
      return _json({});
    });

void main() {
  testWidgets('overview shows the platform numbers', (t) async {
    t.view.physicalSize = const Size(1200, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(_mock([])));
    await t.pumpAndSettle();
    expect(find.text('Welcome, Ada Admin'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Active assessments'), findsOneWidget);
  });

  testWidgets('departments tab lists and adds a department', (t) async {
    t.view.physicalSize = const Size(1200, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final log = <http.Request>[];
    await t.pumpWidget(_app(_mock(log)));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(TabBar), matching: find.text('Departments')));
    await t.pumpAndSettle();
    expect(find.text('Computer Science'), findsOneWidget);
    await t.tap(find.byKey(const Key('add-department')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('f0')), 'Physics');
    await t.enterText(find.byKey(const Key('f1')), 'phy');
    await t.tap(find.byKey(const Key('prompt-ok')));
    await t.pumpAndSettle();
    final post = log.firstWhere((r) => r.method == 'POST');
    expect(jsonDecode(post.body), {'name': 'Physics', 'code': 'phy'});
  });
}
