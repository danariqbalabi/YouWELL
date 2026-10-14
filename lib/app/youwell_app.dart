import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youwell/app/app_shell.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/core/config/app_mode.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/core/theme/appearance_scope.dart';
import 'package:youwell/features/onboarding/presentation/onboarding_page.dart';
import 'package:youwell/features/web/presentation/public_recap_page.dart';
import 'package:youwell/features/web/presentation/web_landing_page.dart';
import 'package:youwell/features/web/presentation/web_workspace_page.dart';

const _mobilePreview = mobilePreview;
const _webWorkspace = kIsWeb && !mobilePreview && !mobileWeb;

/// Local-first application root for the current web design phase.
class YouWellApp extends StatelessWidget {
  const YouWellApp({super.key, required this.controller});

  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final app = AppearanceScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, _) => _buildApp(),
      ),
    );
    if (!_mobilePreview) return app;

    // Keep the navigator and its dialogs inside a portrait phone viewport.
    const screenSize = Size(393, 852);
    return ColoredBox(
      color: const Color(0xff25262b),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FittedBox(
            fit: BoxFit.contain,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: SizedBox(
                width: screenSize.width,
                height: screenSize.height,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: screenSize,
                    padding: const EdgeInsets.only(top: 47, bottom: 34),
                    viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
                    viewInsets: EdgeInsets.zero,
                  ),
                  child: app,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApp() => MaterialApp(
    title: '${AppEnvironment.appName} • Little steps, better days',
    debugShowCheckedModeBanner: false,
    // The web workspace keeps its own look; the phone app gets the
    // reward-focused mobile theme.
    theme: _webWorkspace
        ? AppTheme.light
        : _mobilePreview
        ? AppTheme.mobileLight.copyWith(platform: TargetPlatform.iOS)
        : AppTheme.mobileLight,
    darkTheme: _webWorkspace
        ? AppTheme.dark
        : _mobilePreview
        ? AppTheme.mobileDark.copyWith(platform: TargetPlatform.iOS)
        : AppTheme.mobileDark,
    themeMode: switch (controller.themePreference) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
    routes: {
      '/app': (_) => _LocalAppEntry(controller: controller),
      '/recap': (_) => PublicRecapPage(controller: controller),
      '/admin': (_) => _LocalAppEntry(controller: controller, isAdmin: true),
    },
    home: _webWorkspace
        ? _WebLandingEntry(controller: controller)
        : _LocalAppEntry(controller: controller),
  );
}

class _WebLandingEntry extends StatelessWidget {
  const _WebLandingEntry({required this.controller});

  final WellnessController controller;

  @override
  Widget build(BuildContext context) =>
      WebLandingPage(onJoin: () async => Navigator.pushNamed(context, '/app'));
}

class _LocalAppEntry extends StatelessWidget {
  const _LocalAppEntry({required this.controller, this.isAdmin = false});

  final WellnessController controller;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.profile == null) {
        return OnboardingPage(controller: controller);
      }
      return _webWorkspace
          ? WebWorkspacePage(controller: controller, isAdmin: isAdmin)
          : AppShell(controller: controller);
    },
  );
}
