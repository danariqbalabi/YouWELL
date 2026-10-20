import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/app/youwell_app.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/home/presentation/home_page.dart';

void main() {
  for (final mode in ['light', 'dark']) {
    testWidgets(
      'Enabled reduction path is discoverable and usable in $mode mode',
      (tester) async {
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
        final plan = controller.quests;
        await controller.setThemePreference(mode);
        await tester.pumpWidget(YouWellApp(controller: controller));
        await tester.pumpAndSettle();
        expect(find.text('Kurangi rokok / vape'), findsNothing);

        final profile = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Buka profil',
        );
        await tester.tap(profile);
        await tester.pumpAndSettle();
        final preference = find.widgetWithText(
          SwitchListTile,
          'Jalur kurangi rokok / vape',
        );
        await tester.ensureVisible(preference);
        await tester.tap(preference);
        await tester.pumpAndSettle();
        expect(controller.reduction, isTrue);
        controller.setNicotineProduct('cigarette');
        await tester.pumpAndSettle();
        expect(find.text('Buka Habit Swap'), findsOneWidget);
        expect(find.textContaining('Saya merokok'), findsOneWidget);
        expect(
          WellnessController(saved: controller.export()).reduction,
          isTrue,
        );
        expect(controller.quests, plan);

        await tester.pageBack();
        await tester.pumpAndSettle();
        // A cigarette-only user sees cigarette words only.
        await tester.scrollUntilVisible(find.text('Kurangi rokok'), 150);
        expect(
          find.descendant(
            of: find.byType(HomePage),
            matching: find.text('Kurangi rokok'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('vape'), findsNothing);
        await tester.ensureVisible(find.text('Saya ingin merokok'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Saya ingin merokok'));
        await tester.pumpAndSettle();

        // One-time setup: choices, not a report of anything done.
        expect(find.text('Persiapan singkat'), findsOneWidget);
        await tapIn(tester, 'Setelah makan');
        await tapIn(tester, 'Lanjut');
        await tapIn(tester, 'Jalan santai');
        await tapIn(tester, 'Lanjut');
        await tapIn(tester, 'Simpan pilihan saya');
        expect(controller.habitSwaps, isEmpty);
        expect(controller.swapSetup('cigarette')!['activities'], ['walk']);

        // The craving flow puts personal picks first; no countdown.
        expect(find.text('Coba lakukan satu kegiatan dulu'), findsOneWidget);
        expect(find.text('Mulai'), findsNothing);
        await tapIn(tester, 'Jalan santai');
        await tapIn(tester, 'Saya akan coba');
        expect(controller.activeSwapMoment, isNotNull);
        expect(controller.habitSwaps, isEmpty, reason: 'not tried yet');
        await tapIn(tester, 'Saya sudah mencoba');
        expect(controller.swapAttemptsToday, hasLength(1));
        await tapIn(tester, 'Akhirnya tetap merokok');
        await tapIn(tester, 'Simpan hasil');
        expect(controller.habitSwaps.single['outcome'], 'used');
        expect(find.textContaining('Mencoba tetap berarti'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('1 kali mencoba kegiatan pengganti hari ini'),
          150,
        );
        controller.switchPath(false);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(HomePage),
            matching: find.text('Kurangi rokok'),
          ),
          findsNothing,
        );
        expect(controller.habitDelays, isEmpty);
        expect(controller.habitSwaps, hasLength(1));
        expect(controller.quests, plan);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

/// Scrolls the visible vertical list until [text] shows, then taps it.
Future<void> tapIn(WidgetTester tester, String text) async {
  final target = find.text(text).hitTestable();
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      120,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}
