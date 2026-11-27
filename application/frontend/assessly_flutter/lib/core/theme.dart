import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'theme/app_colors.dart';
export 'theme/app_spacing.dart';
export 'theme/app_theme.dart';

/// Holds the chosen ThemeMode and remembers it in browser storage.
class ThemeCubit extends Cubit<ThemeMode> {
  static const _key = 'assessly_theme_mode';
  ThemeCubit() : super(ThemeMode.system);

  Future<void> load() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(_key);
      emit(v == 'dark' ? ThemeMode.dark : (v == 'light' ? ThemeMode.light : ThemeMode.system));
    } catch (_) {}
  }

  Future<void> set(ThemeMode mode) async {
    emit(mode);
    try {
      await (await SharedPreferences.getInstance())
          .setString(_key, mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system'));
    } catch (_) {}
  }
}

/// Sun/moon button.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      key: const Key('theme-toggle'),
      tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => context.read<ThemeCubit>().set(dark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}
