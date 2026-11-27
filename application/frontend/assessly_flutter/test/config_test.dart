import 'package:flutter_test/flutter_test.dart';
import 'package:assessly_flutter/core/config.dart';

void main() {
  test('same-origin means an empty prefix (relative /api calls)', () {
    expect(AppConfig.resolve('same-origin'), '');
  });

  test('any other value is used as the API base URL', () {
    expect(AppConfig.resolve('http://localhost:3000'), 'http://localhost:3000');
  });
}
