import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:assessly_flutter/core/api_client.dart';
import 'package:assessly_flutter/core/theme.dart';
import 'package:assessly_flutter/features/admin/admin_api.dart';
import 'package:assessly_flutter/features/admin/admin_people.dart';

http.Response _json(Object b, [int s = 200]) =>
    http.Response(jsonEncode(b), s, headers: {'content-type': 'application/json'});

void main() {
  testWidgets('admin selects a student and enrolls them in a batch', (t) async {
    t.view.physicalSize = const Size(1200, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final log = <http.Request>[];
    final client = MockClient((req) async {
      log.add(req);
      final p = req.url.path;
      if (p == '/api/admin/students') {
        return _json({'total': 1, 'students': [
          {'id': 's1', 'fullName': 'Asha Verma', 'email': 'asha@x.com', 'rollNumber': 'R1', 'attendancePct': 92, 'batchCount': 0}]});
      }
      if (p == '/api/admin/batches') {
        return _json({'batches': [
          {'id': 'b1', 'courseId': 'c1', 'courseName': 'Data Structures', 'courseCode': 'CS201', 'name': 'CSE 2026', 'section': 'A', 'year': 2026, 'studentCount': 0}]});
      }
      if (p == '/api/admin/batches/b1/enroll') return _json({'enrolled': 1});
      return _json({});
    });
    final api = ApiClient(client: client);
    await t.pumpWidget(Provider<ApiClient>.value(
      value: api,
      child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: AdminStudentsTab(api: AdminApi(api)))),
    ));
    await t.pumpAndSettle();
    expect(find.text('Asha Verma'), findsOneWidget);
    await t.tap(find.byKey(const Key('sel-s1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('enroll-selected')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('pick-batch-b1')));
    await t.pumpAndSettle();
    final post = log.firstWhere((r) => r.method == 'POST');
    expect(jsonDecode(post.body), {'studentIds': ['s1']});
  });
}
