import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/appearance_scope.dart';
import 'admin_moderation_page.dart';

/// Moderator UI only: no wellness onboarding, quests, or personal progress.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('YouWELL Admin'),
      actions: [const ThemeModeButton()],
    ),
    body: AnimatedBuilder(
      animation: controller,
      builder: (_, _) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: AdminModerationPage(controller: controller),
        ),
      ),
    ),
  );
}
