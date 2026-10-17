import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/app/youwell_app.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/home/presentation/home_page.dart';
import 'package:youwell/features/reduction/presentation/habit_swap_panel.dart';

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
        expect(find.text('Buka Habit Swap'), findsOneWidget);
        expect(
          WellnessController(saved: controller.export()).reduction,
          isTrue,
        );
        expect(controller.quests, plan);

        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Kurangi rokok / vape'), 150);
        expect(find.text('Kurangi rokok / vape'), findsOneWidget);
        // The reduction card sits after today's quests on Home.
        expect(
          find.descendant(
            of: find.byType(HomePage),
            matching: find.text('Kurangi rokok / vape'),
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Buka Habit Swap'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buka Habit Swap'));
        await tester.pumpAndSettle();
        expect(find.text('Rokok / vape'), findsOneWidget);
        expect(find.text('Mulai'), findsNothing);
        expect(find.text('02:00'), findsNothing);
        await tester.tap(find.text('Setelah makan'));
        await tester.scrollUntilVisible(
          find.text('Jalan santai'),
          150,
          scrollable: find
              .descendant(
                of: find.byType(HabitSwapPanel),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Jalan santai'));
        await tester.scrollUntilVisible(
          find.text('Sudah coba, tetap merokok'),
          150,
          scrollable: find
              .descendant(
                of: find.byType(HabitSwapPanel),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sudah coba, tetap merokok'));
        await tester.scrollUntilVisible(
          find.text('Simpan momen'),
          150,
          scrollable: find
              .descendant(
                of: find.byType(HabitSwapPanel),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Simpan momen'));
        await tester.pumpAndSettle();
        expect(controller.habitSwapsToday, 1);
        expect(
          find.text('Momen tercatat. Terima kasih sudah jujur!'),
          findsOneWidget,
        );

        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('aktivitas dicoba hari ini'),
          150,
        );
        expect(find.text('aktivitas dicoba hari ini'), findsOneWidget);
        controller.switchPath(false);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(HomePage),
            matching: find.text('Kurangi rokok / vape'),
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
