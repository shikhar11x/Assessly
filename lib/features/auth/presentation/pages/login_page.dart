import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/brand_logo.dart';
import '../cubit/login_cubit.dart';
import '../widgets/brand_panel.dart';
import '../widgets/login_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  /// Minimum width at which the brand panel is shown beside the form.
  static const double _wideBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(),
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _wideBreakpoint;
            return Row(
              children: [
                if (isWide) const Expanded(flex: 5, child: BrandPanel()),
                Expanded(flex: 4, child: _FormSide(showLogo: !isWide)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FormSide extends StatelessWidget {
  const _FormSide({required this.showLogo});

  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showLogo) ...[
                  const Align(child: BrandLogo()),
                  const SizedBox(height: 40),
                ],
                const LoginForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}