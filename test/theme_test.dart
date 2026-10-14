import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/app/youwell_app.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/core/theme/appearance_scope.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/community/presentation/admin_shell.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + .05) / (math.min(first, second) + .05);
}

void main() {
  test('Both palettes keep text and controls readable', () {
    for (final c in [AppColors.light, AppColors.dark]) {
      for (final background in [c.canvas, c.surface, c.raised, c.selected]) {
        for (final foreground in [c.text, c.muted, c.accent]) {
          expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
        }
      }
    }
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(theme.colorScheme.primary, brandOrange);
      expect(
        contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test(
    'Appearance persists before onboarding and restores older state',
    () async {
      String? stored;
      final controller = WellnessController(
        persist: (value) async {
          stored = value;
        },
      );
      await controller.setThemePreference('dark');
      expect(WellnessController(saved: stored).themePreference, 'dark');
      await controller.setThemePreference('light');
      expect(WellnessController(saved: stored).themePreference, 'light');
      final oldState = createEmptyWellnessState()..remove('themeMode');
      expect(
        WellnessController(saved: jsonEncode(oldState)).themePreference,
        'system',
      );
      expect(
        () => controller.setThemePreference('invalid'),
        throwsArgumentError,
      );
    },
  );

  testWidgets('Onboarding switches light and dark without losing its step', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = WellnessController();
    await controller.setThemePreference('light');
    await tester.pumpWidget(YouWellApp(controller: controller));
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih rentang usiamu dulu.'), findsOneWidget);
    await tester.tap(find.text('18–22 tahun'));
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Berhenti rokok / vape'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Mau mulai sesantai apa?'), findsOneWidget);
    await tester.scrollUntilVisible(find.byTooltip('Ganti ke dark mode'), -200);
    await tester.tap(find.byTooltip('Ganti ke dark mode'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
    expect(find.text('Mau mulai sesantai apa?'), findsOneWidget);
    await tester.tap(find.byTooltip('Ganti ke light mode'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['light', 'dark']) {
    testWidgets('Moderator console renders in $mode mode without onboarding', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = WellnessController();
      await controller.setThemePreference(mode);
      await tester.pumpWidget(
        AppearanceScope(
          controller: controller,
          child: MaterialApp(
            theme: mode == 'light' ? AppTheme.light : AppTheme.dark,
            home: AdminShell(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Moderasi komunitas'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(controller.profile, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('Mobile navigation and profile work in $mode mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = WellnessController();
      controller.setReduceMotion(true);
      await controller.setup({
        'alias': 'preview',
        'path': 'wellness',
        'pace': 1,
        'companion': 'plant',
      });
      controller.selectDailyCard(
        controller.dailyDrawCards.first['id'].toString(),
      );
      controller.commitDailyCardPack();
      await controller.setThemePreference(mode);
      await tester.pumpWidget(YouWellApp(controller: controller));
      await tester.pumpAndSettle();
      for (var index = 0; index < 4; index++) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Buka profil',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tampilan'), findsOneWidget);
      await tester.tap(find.text(mode == 'light' ? 'Gelap' : 'Terang'));
      await tester.pumpAndSettle();
      expect(controller.themePreference, mode == 'light' ? 'dark' : 'light');
      expect(tester.takeException(), isNull);
    });
  }
}
