import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/reduction/presentation/reduction_diary.dart';

import 'support/sim.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  testWidgets(
    'Daily totals require explicit values; zero and correction persist without XP',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sim = Sim();
      await sim.start(path: 'reduction');
      final c = sim.controller;
      c.setNicotineProduct('both');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ReductionDiary(controller: c)),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Simpan total harian'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Simpan total harian'));
      await tester.pump();
      expect(c.nicotineDays, isEmpty);
      await tester.scrollUntilVisible(
        field('Total batang rokok'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field('Total batang rokok'), '0');
      await tester.enterText(field('Total sesi vape'), '4');
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.tap(find.text('Simpan total harian'));
      await tester.pump();
      expect(c.nicotineDay(c.today)!['cigarette'], 0);
      expect(c.nicotineDay(c.today)!['vape'], 4);
      expect(c.xp, 0);
      await tester.scrollUntilVisible(
        field('Total batang rokok'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field('Total batang rokok'), '3');
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.tap(find.text('Simpan total harian'));
      await tester.pump();
      expect(c.nicotineDays, hasLength(1));
      expect(c.nicotineDay(c.today)!['cigarette'], 3);
      expect(c.xp, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Vape-only diary has sessions and no cigarette field', (
    tester,
  ) async {
    final sim = Sim();
    await sim.start(path: 'reduction');
    sim.controller.setNicotineProduct('vape');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReductionDiary(controller: sim.controller)),
      ),
    );
    expect(field('Total batang rokok'), findsNothing);
    expect(field('Total sesi vape'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
