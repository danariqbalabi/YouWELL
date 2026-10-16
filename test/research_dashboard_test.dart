import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youwell/application/app_auth_controller.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/core/config/app_mode.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/features/auth/data/account_cache.dart';
import 'package:youwell/features/auth/presentation/account_scope.dart';
import 'package:youwell/features/community/data/community_photo.dart';
import 'package:youwell/features/community/presentation/research_dashboard_page.dart';
import 'package:youwell/features/progress/domain/research_store.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

import 'account_sync_test.dart' show FakeGateway;
import 'support/sim.dart';

class FakeResearch implements ResearchStore {
  FakeResearch(this.rows);
  final List<JsonMap> rows;
  final assigned = <String, String?>{};
  @override
  Future<List<JsonMap>> progressOverview() async => [
    for (final row in rows)
      {...row, 'code': assigned[row['account']] ?? row['code']},
  ];
  @override
  Future<void> setParticipantCode(String account, String? code) async =>
      assigned[account] = code;
}

/// The row the phase 6 RPC returns for one simulated participant.
Future<(JsonMap, DateTime)> participantRow({
  int days = 3,
  String? code,
  String account = 'acc-1',
}) async {
  final sim = Sim();
  await sim.start(path: 'reduction');
  for (var day = 0; day < days; day++) {
    sim.takeCard();
    for (final task in sim.controller.coreQuests) {
      sim.finish(task);
    }
    sim.nextDay();
  }
  return (
    {
      'account': account,
      'code': code,
      'alias': 'daunpagi',
      'updated_at': '2026-10-27T08:00:00+00:00',
      'payload': CloudProgress.project(sim.controller.export()),
    },
    sim.now,
  );
}

void main() {
  test('Dashboard rows use the app rules on the synced snapshot', () async {
    final (row, now) = await participantRow(code: 'P1');
    final p = ParticipantOverview.fromRow(row, now: now)!;
    expect(p.alias, 'daunpagi');
    expect(p.code, 'P1');
    expect(p.path, 'Rokok/vape');
    expect(p.dayNumber, 4);
    expect(p.questsDone, greaterThanOrEqualTo(9));
    expect(p.fullDays, 3);
    expect(p.activeWeeks, [true, null, null, null]);
    expect(p.ladder.keys, contains('Reduction'));
    expect(p.toCsvRow().keys, ParticipantOverview.csvColumns);
    final research = p.researchRows();
    expect(research.single['participant_code'], 'P1');
    expect(research.single['week'], 1);
    expect(research.single.keys, isNot(contains('alias')));
    expect(ParticipantOverview.fromRow({'payload': 'broken'}), isNull);
  });

  test('Week-4 engagement counts coded participants who reached it', () async {
    final (row, now) = await participantRow(days: 23, code: 'P2');
    final reached = ParticipantOverview.fromRow(row, now: now)!;
    final uncoded = ParticipantOverview.fromRow({
      ...row,
      'code': null,
    }, now: now)!;
    expect(reached.activeWeeks[3], isTrue);
    final result = weekFourEngagement([reached, uncoded]);
    expect(result.active, 1);
    expect(result.reached, 1);
  });

  testWidgets('Photos are re-encoded as PNG and scaled down', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 2400, 1600),
        ui.Paint()..color = const Color(0xff4e9a5e),
      );
      final image = await recorder.endRecording().toImage(2400, 1600);
      final source = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      final photo = await prepareCommunityPhoto(source);
      expect(photo.sublist(0, 4), Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]));
      final codec = await ui.instantiateImageCodec(photo);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1080);
      expect(frame.image.height, 720);
      expect(photo.length, lessThanOrEqualTo(maxCommunityPhotoBytes));
    });
    expect(randomUuid(), matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  testWidgets('Admins see every account and assign participant codes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (row, now) = await participantRow();
    final store = FakeResearch([row]);
    SharedPreferences.setMockInitialValues({});
    final auth = AppAuthController(
      gateway: FakeGateway(null),
      cache: AccountCache(
        await SharedPreferences.getInstance(),
        baseKey: 'youwell.local.v3',
        projectHost: 'test.supabase.co',
        surface: AppSurface.admin,
      ),
      surface: AppSurface.admin,
      researchStore: store,
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      AccountScope(
        auth: auth,
        child: MaterialApp(
          theme: AppTheme.mobileLight,
          home: Scaffold(body: ResearchDashboardPage(now: now)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('daunpagi'), findsOneWidget);
    expect(find.text('Rokok/vape'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('P3').last);
    await tester.pumpAndSettle();
    expect(store.assigned['acc-1'], 'P3');
    expect(find.text('P3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
