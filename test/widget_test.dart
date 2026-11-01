import 'package:assessly/app.dart';
import 'package:assessly/core/di/injection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Splash screen navigates to the login screen', (tester) async {
    await setupDependencies();
    await tester.pumpWidget(const AssesslyApp());

    expect(find.text('Assessly'), findsOneWidget);

    // Move past the splash delay, then let the route transition finish.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}