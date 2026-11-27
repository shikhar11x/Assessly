import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:assessly_flutter/core/api_client.dart';
import 'package:assessly_flutter/core/theme.dart';
import 'package:assessly_flutter/core/widgets/app_shell.dart';
import 'package:assessly_flutter/core/widgets/app_widgets.dart';
import 'package:assessly_flutter/features/auth/auth_state.dart';

Widget _app(AppRole role) {
  final auth = AuthState(ApiClient())
    ..user = AppUser(id: '1', email: 'a@x.com', fullName: 'Tina Teacher', role: 'teacher');
  return ChangeNotifierProvider<AuthState>.value(
    value: auth,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: AppShell(role: role, appBar: AppBar(title: const Text('Page')), body: const Text('content')),
    ),
  );
}

void main() {
  testWidgets('wide screens show the faculty sidebar permanently', (t) async {
    t.view.physicalSize = const Size(1200, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(AppRole.faculty));
    expect(find.text('Faculty workspace'), findsOneWidget);
    expect(find.text('Question Bank'), findsOneWidget);
    expect(find.text('Tina Teacher'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('narrow screens hide the sidebar in a drawer', (t) async {
    await t.pumpWidget(_app(AppRole.student));
    expect(find.text('Leaderboard'), findsNothing);
    await t.tap(find.byIcon(Icons.menu));
    await t.pumpAndSettle();
    expect(find.text('Student workspace'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
  });

  testWidgets('AppBadge and PageHeader render their text', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: const Scaffold(
        body: Column(children: [
          AppBadge('Published', tone: BadgeTone.success),
          PageHeader(title: 'Dashboard', subtitle: 'Overview'),
        ]),
      ),
    ));
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
  });
}
