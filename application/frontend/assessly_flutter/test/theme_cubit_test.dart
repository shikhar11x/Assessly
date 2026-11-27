import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:assessly_flutter/core/theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ThemeCubit starts on system and saves the chosen mode', () async {
    final cubit = ThemeCubit();
    expect(cubit.state, ThemeMode.system);
    await cubit.set(ThemeMode.dark);
    expect(cubit.state, ThemeMode.dark);
    expect((await SharedPreferences.getInstance()).getString('assessly_theme_mode'), 'dark');
    await cubit.close();
  });

  test('ThemeCubit restores a saved mode', () async {
    SharedPreferences.setMockInitialValues({'assessly_theme_mode': 'light'});
    final cubit = ThemeCubit();
    await cubit.load();
    expect(cubit.state, ThemeMode.light);
    await cubit.close();
  });

  test('themes use the design-system colours', () {
    expect(AppTheme.light().scaffoldBackgroundColor, const Color(0xFFFAFAF9));
    expect(AppTheme.dark().scaffoldBackgroundColor, const Color(0xFF0D1117));
    expect(AppTheme.light().extension<AppColors>()!.success, const Color(0xFF16A34A));
  });
}
