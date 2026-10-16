import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youwell/application/app_auth_controller.dart';
import 'package:youwell/application/progress_sync_controller.dart';
import 'package:youwell/core/config/app_mode.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/auth/data/account_cache.dart';
import 'package:youwell/features/auth/domain/auth_gateway.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

String state(String alias, {String theme = 'system'}) => jsonEncode({
  ...createEmptyWellnessState(),
  'themeMode': theme,
  'profile': {'alias': alias, 'path': 'wellness', 'started': '2026-10-24'},
});

class FakeGateway implements AuthGateway {
  FakeGateway(String? userId)
    : identity = userId == null ? null : AuthIdentity(userId);
  @override
  AuthIdentity? identity;
  final _changes = StreamController<AuthIdentity?>.broadcast();
  bool failDelete = false, deleted = false;

  @override
  Stream<AuthIdentity?> get changes => _changes.stream;
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signOut() async {
    identity = null;
    _changes.add(null);
  }

  @override
  Future<AdminAccess> adminAccess() async => AdminAccess.denied;
  @override
  Future<MfaSetup> prepareMfa() => throw UnimplementedError();
  @override
  Future<void> verifyMfa(String factorId, String code) async {}
  @override
  Future<void> deleteAccount() async {
    if (failDelete) throw StateError('offline');
    deleted = true;
  }
}

/// In-memory compare-and-swap store; can commit a save and lose its reply.
class FakeCloud implements ProgressCloudStore {
  CloudProgressSnapshot? snapshot;
  bool dropNextReply = false;

  @override
  Future<CloudProgressSnapshot?> read() async => snapshot;

  @override
  Future<ProgressSaveResult> save(
    JsonMap payload, {
    required int expectedRevision,
  }) async {
    if ((snapshot?.revision ?? 0) != expectedRevision) {
      return ProgressSaveResult(saved: false, snapshot: snapshot);
    }
    snapshot = CloudProgressSnapshot(
      revision: expectedRevision + 1,
      payload: jsonDecode(jsonEncode(payload)) as JsonMap,
      updatedAt: DateTime(2026, 10, 24),
    );
    if (dropNextReply) {
      dropNextReply = false;
      throw TimeoutException('reply lost');
    }
    return ProgressSaveResult(saved: true, snapshot: snapshot);
  }
}

Future<AccountCache> newCache([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return AccountCache(
    await SharedPreferences.getInstance(),
    baseKey: 'youwell.local.v3',
    projectHost: 'test.supabase.co',
    surface: AppSurface.mobile,
  );
}

void main() {
  test('An unreadable account snapshot is kept aside, not overwritten', () async {
    final cache = await newCache();
    final key = cache.keyFor('u1');
    await cache.preferences.setString(key, '{"version": 99}');
    expect(await cache.read('u1'), isNull);
    expect(cache.preferences.getString('$key.unreadable'), '{"version": 99}');
    expect(cache.preferences.getString(key), isNull);
    expect(cache.takeRecovered('u1'), isTrue);
    expect(cache.takeRecovered('u1'), isFalse, reason: 'reported once');
  });

  test('Declined guest progress is never offered to another account', () async {
    final cache = await newCache({'youwell.local.v3': state('tamu')});
    expect(await cache.legacyFor('a'), isNotNull);
    await cache.declineLegacy('a');
    expect(await cache.legacyFor('b'), isNull);
  });

  test('Reset drops recovery copies; deletion wipes the account', () async {
    final cache = await newCache({'youwell.local.v3': state('tamu')});
    await cache.importLegacy('a');
    final key = cache.keyFor('a');
    await cache.backup('a', state('lama'));
    await cache.backupCloud('a', state('cloud'));
    await cache.writeSyncMeta('a', {'revision': 3});
    await cache.write('b', state('lain'));

    await cache.clearBackups('a');
    expect(cache.recoveryFor('a'), isNull);
    expect(cache.cloudRecoveryFor('a'), isNull);
    expect(await cache.readSyncMeta('a'), {'revision': 3});

    await cache.wipe('a');
    final left = cache.preferences.getKeys();
    expect(left.where((k) => k.startsWith(key)), isEmpty);
    expect(left, isNot(contains('youwell.local.v3')), reason: 'claimed guest');
    expect(await cache.read('b'), isNotNull, reason: 'other accounts stay');
  });

  test('A lost save reply is acknowledged, not shown as a conflict', () async {
    final cache = await newCache();
    final cloud = FakeCloud();
    final sync = ProgressSyncController(
      userId: 'u1',
      cache: cache,
      remote: cloud,
      onApplied: (_) {},
      debounce: const Duration(hours: 1),
    );
    addTearDown(sync.dispose);
    await sync.open(state('satu'));
    expect(cloud.snapshot?.revision, 1);

    cloud.dropNextReply = true;
    await sync.write(state('satu', theme: 'dark'));
    await sync.syncNow();
    expect(sync.stage, SyncStage.offline);
    expect(sync.errorDetail, contains('reply lost'));
    expect(cloud.snapshot?.revision, 2, reason: 'committed despite the error');

    await sync.write(state('satu', theme: 'light'));
    await sync.syncNow();
    expect(sync.stage, SyncStage.idle);
    expect(sync.hasConflict, isFalse);
    expect(cloud.snapshot?.revision, 3);
    expect(cloud.snapshot?.payload['themeMode'], 'light');
  });

  test('Account deletion only clears local data after the server', () async {
    final cache = await newCache();
    await cache.write('u1', state('peserta'));
    await cache.backup('u1', state('lama'));
    final gateway = FakeGateway('u1');
    final auth = AppAuthController(
      gateway: gateway,
      cache: cache,
      surface: AppSurface.mobile,
    );
    addTearDown(auth.dispose);
    auth.start();
    for (var i = 0; i < 20 && auth.stage != AuthStage.ready; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(auth.stage, AuthStage.ready);

    var filesDeleted = false;
    gateway.failDelete = true;
    await expectLater(
      auth.deleteAccount(deleteLocalFiles: () async => filesDeleted = true),
      throwsStateError,
    );
    expect(auth.stage, AuthStage.ready);
    expect(filesDeleted, isFalse);
    expect(await cache.read('u1'), isNotNull);

    gateway.failDelete = false;
    await auth.deleteAccount(
      deleteLocalFiles: () async => filesDeleted = true,
    );
    expect(gateway.deleted, isTrue);
    expect(filesDeleted, isTrue);
    expect(auth.stage, AuthStage.signedOut);
    expect(
      cache.preferences.getKeys().where((k) => k.contains('.account.')),
      isEmpty,
    );
  });
}
