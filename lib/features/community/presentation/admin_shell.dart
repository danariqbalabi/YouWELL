import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/appearance_scope.dart';
import 'admin_moderation_page.dart';
import 'research_dashboard_page.dart';
import 'package:youwell/features/auth/presentation/account_scope.dart';

/// Admin web: Community moderation and the researcher dashboard.
/// No wellness onboarding or quests of its own.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.controller});
  final WellnessController controller;

  Widget _page(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('YouWELL Admin'),
        actions: [
          const ThemeModeButton(),
          if (AccountScope.maybeOf(context) case final account?)
            IconButton(
              onPressed: account.signOut,
              tooltip: 'Keluar',
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Moderasi'),
            Tab(text: 'Dashboard peneliti'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (_, _) =>
                _page(AdminModerationPage(controller: controller)),
          ),
          _page(const ResearchDashboardPage()),
        ],
      ),
    ),
  );
}
