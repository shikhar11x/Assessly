import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:assessly_flutter/core/api_client.dart';
import 'package:assessly_flutter/features/auth/auth_state.dart';
import 'package:assessly_flutter/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('theme toggle switches light and dark and remembers the choice', (t) async {
    final auth = AuthState(ApiClient(client: MockClient((_) async => http.Response('{}', 401))));
    await t.pumpWidget(AssesslyApp(auth: auth));
    await t.pumpAndSettle();
    Brightness current() => Theme.of(t.element(find.byKey(const Key('email')))).brightness;

    expect(current(), Brightness.light);
    await t.tap(find.byKey(const Key('theme-toggle')));
    await t.pumpAndSettle();
    expect(current(), Brightness.dark);
    expect((await SharedPreferences.getInstance()).getString('assessly_theme_mode'), 'dark');

    await t.tap(find.byKey(const Key('theme-toggle')));
    await t.pumpAndSettle();
    expect(current(), Brightness.light);
  });
}
