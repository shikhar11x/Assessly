import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/auth_state.dart';
import 'app_sidebar.dart';

enum AppRole { faculty, student }

const _facultyItems = [
  NavItem(Icons.dashboard_outlined, 'Dashboard', enabled: true),
  NavItem(Icons.assignment_outlined, 'Assessments'),
  NavItem(Icons.library_books_outlined, 'Question Bank'),
  NavItem(Icons.code_rounded, 'Coding Tests'),
  NavItem(Icons.inbox_outlined, 'Submissions'),
  NavItem(Icons.groups_outlined, 'Students & Batches'),
  NavItem(Icons.insights_outlined, 'Analytics'),
  NavItem(Icons.calendar_month_outlined, 'Calendar'),
  NavItem(Icons.notifications_none_rounded, 'Notifications'),
  NavItem(Icons.settings_outlined, 'Settings'),
];

const _studentItems = [
  NavItem(Icons.dashboard_outlined, 'Dashboard', enabled: true),
  NavItem(Icons.assignment_outlined, 'My Assessments'),
  NavItem(Icons.bar_chart_rounded, 'Results'),
  NavItem(Icons.emoji_events_outlined, 'Leaderboard'),
  NavItem(Icons.calendar_month_outlined, 'Calendar'),
  NavItem(Icons.notifications_none_rounded, 'Notifications'),
  NavItem(Icons.settings_outlined, 'Settings'),
];

/// Scaffold with a permanent sidebar on wide screens (>= 900px) and a drawer on narrow ones.
/// It takes the same appBar / body / floatingActionButton a Scaffold would.
class AppShell extends StatelessWidget {
  final AppRole role;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  const AppShell({super.key, required this.role, this.appBar, required this.body, this.floatingActionButton});

  static const double wideBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final name = context.read<AuthState>().user?.fullName ?? '';
    final sidebar = AppSidebar(
      items: role == AppRole.faculty ? _facultyItems : _studentItems,
      workspace: role == AppRole.faculty ? 'Faculty workspace' : 'Student workspace',
      userName: name,
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= wideBreakpoint) {
        return Scaffold(
          body: Row(children: [
            sidebar,
            Expanded(child: Scaffold(appBar: appBar, body: body, floatingActionButton: floatingActionButton)),
          ]),
        );
      }
      return Scaffold(
        appBar: appBar,
        drawer: Drawer(width: 240, child: sidebar),
        body: body,
        floatingActionButton: floatingActionButton,
      );
    });
  }
}
