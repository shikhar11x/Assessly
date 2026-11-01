import 'package:assessly/app.dart';
import 'package:assessly/core/di/injection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Splash ke baad login screen dikhti hai', (tester) async {
    await setupDependencies();
    await tester.pumpWidget(const AssesslyApp());

    expect(find.text('Assessly'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}