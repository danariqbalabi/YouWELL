import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youwell/features/auth/data/account_cache.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';
import 'package:youwell/core/types/json_map.dart';

enum SyncStage { idle, syncing, offline, conflict, stopped }

/// Local-first snapshot sync with compare-and-swap, not last-writer-wins.
/// Only one request is issued at a time; gameplay never waits for the network.
class ProgressSyncController extends ChangeNotifier {
  ProgressSyncController({
    required this.userId,
    required this.cache,
    required this.remote,
    required this.onApplied,
    this.timeout = const Duration(seconds: 12),
    this.debounce = const Duration(seconds: 2),
  });
  final String userId;
  final AccountCache cache;
  final ProgressCloudStore remote;
  final void Function(String raw) onApplied;
  final Duration timeout, debounce;
  SyncStage stage = SyncStage.idle;
  String? error;
  DateTime? lastSyncedAt;
  CloudProgressSnapshot? conflict;
  bool _missingConflict = false;
  int _revision = 0;
  String? _base;
  String? _raw;
  bool _busy = false, _disposed = false;
  Timer? _debouncer;

  bool get pending =>
      _raw != null &&
      CloudProgress.canonical(CloudProgress.project(_raw!)) != _base;
  bool get hasConflict => stage == SyncStage.conflict;
  String? get recovery => cache.recoveryFor(userId);
  String? get cloudRecovery => cache.cloudRecoveryFor(userId);
  bool get _hasProfile =>
      _raw != null && CloudProgress.project(_raw!)['profile'] is Map;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _set(SyncStage value, [String? message]) {
    if (_disposed) return;
    stage = value;
    error = message;
    _notify();
  }

  Future<String?> open(String? local) async {
    _raw = local;
    try {
      final meta = await cache.readSyncMeta(userId);
      _revision = (meta?['revision'] as num?)?.toInt() ?? 0;
      _base = meta?['base'] as String?;
      lastSyncedAt = DateTime.tryParse(meta?['syncedAt']?.toString() ?? '');
      await _exchange(initial: true);
    } catch (_) {
      _set(
        SyncStage.offline,
        'Cloud belum terhubung. Progres tetap tersimpan di perangkat.',
      );
    }
    return _raw;
  }

  Future<void> write(String raw) async {
    // Retain raw paths/notes only in the device cache.
    await cache.write(userId, raw);
    if (_disposed) return;
    _raw = raw;
    _notify();
    if (!hasConflict) {
      _debouncer?.cancel();
      if (pending) _debouncer = Timer(debounce, () => unawaited(syncNow()));
    }
  }

  Future<void> _ack(CloudProgressSnapshot value) async {
    _revision = value.revision;
    _base = CloudProgress.canonical(value.payload);
    lastSyncedAt = value.updatedAt;
    await cache.writeSyncMeta(userId, {
      'revision': _revision,
      'base': _base,
      'syncedAt': lastSyncedAt!.toIso8601String(),
    });
  }

  void _conflict(CloudProgressSnapshot? value) {
    conflict = value;
    _missingConflict = value == null;
    _set(
      SyncStage.conflict,
      'Ada perbedaan progres lokal dan cloud. Pilih salinan yang ingin dilanjutkan; tidak digabung otomatis.',
    );
  }

  Future<void> _adopt(
    CloudProgressSnapshot value, {
    required bool notifyApp,
  }) async {
    final previous = _raw;
    if (previous != null) await cache.backup(userId, previous);
    final raw = CloudProgress.apply(value.payload, previous);
    await cache.write(userId, raw);
    if (_disposed) return;
    _raw = raw;
    await _ack(value);
    if (_disposed) return;
    conflict = null;
    _set(SyncStage.idle);
    if (notifyApp) onApplied(raw);
  }

  Future<void> _exchange({required bool initial}) async {
    if (_busy || _disposed) return;
    _busy = true;
    _set(SyncStage.syncing);
    try {
      final cloud = await remote.read().timeout(timeout);
      if (_disposed) return;
      final local = _raw == null ? null : CloudProgress.project(_raw!);
      final localKey = local == null ? null : CloudProgress.canonical(local);
      final cloudKey = cloud == null
          ? null
          : CloudProgress.canonical(cloud.payload);
      if (cloud == null) {
        if (_revision > 0) {
          _conflict(null);
          return;
        }
        if (_hasProfile) {
          await _upload();
        } else {
          _base = localKey;
          _set(SyncStage.idle);
        }
      } else if (localKey == cloudKey) {
        await _ack(cloud);
        _set(SyncStage.idle);
      } else if (initial &&
          (local == null ||
              (_base == null && !_hasProfile) ||
              localKey == _base)) {
        await _adopt(cloud, notifyApp: false);
      } else if (_revision == cloud.revision && _base == cloudKey) {
        await _upload();
      } else {
        // Runtime pulls never replace a running timer or an open draw dialog.
        _conflict(cloud);
      }
    } catch (_) {
      _set(
        SyncStage.offline,
        'Belum tersinkron. Periksa koneksi atau jalankan migration progres, lalu coba lagi.',
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _upload() async {
    final raw = _raw;
    if (raw == null || _disposed) return;
    final result = await remote
        .save(CloudProgress.project(raw), expectedRevision: _revision)
        .timeout(timeout);
    if (_disposed) return;
    if (!result.saved) {
      _conflict(result.snapshot);
      return;
    }
    if (result.snapshot == null) {
      throw const FormatException('Missing saved snapshot');
    }
    await _ack(result.snapshot!);
    _set(SyncStage.idle);
    // Changes made while uploading remain dirty and get their own CAS write.
    if (pending && !_disposed) {
      _debouncer?.cancel();
      _debouncer = Timer(debounce, () => unawaited(syncNow()));
    }
  }

  Future<void> syncNow() async {
    _debouncer?.cancel();
    if (hasConflict || _disposed) return;
    await _exchange(initial: false);
  }

  Future<void> resolve({required bool useCloud}) async {
    if (!hasConflict || _busy || _disposed) return;
    _busy = true;
    final expected = conflict?.revision;
    _set(SyncStage.syncing);
    try {
      // Check again: an older dialog cannot authorize overwriting newer data.
      final current = await remote.read().timeout(timeout);
      if (_disposed) return;
      if (current?.revision != expected ||
          (current == null && !_missingConflict)) {
        _conflict(current);
        return;
      }
      if (useCloud) {
        if (current == null) {
          _conflict(null);
          error =
              'Salinan cloud tidak tersedia. Ekspor cadangan lokal atau pilih progres lokal.';
          _notify();
          return;
        }
        await _adopt(current, notifyApp: true);
      } else {
        if (_raw != null) await cache.backup(userId, _raw!);
        if (current != null) {
          await cache.backupCloud(
            userId,
            CloudProgress.apply(current.payload, null),
          );
        }
        _revision = current?.revision ?? 0;
        await _upload();
        if (stage == SyncStage.idle) conflict = null;
      }
    } catch (_) {
      // Keep the decision and latest local state when connectivity drops.
      _conflict(conflict);
      error = 'Pilihan belum tersimpan. Periksa koneksi lalu coba lagi.';
      _notify();
    } finally {
      _busy = false;
    }
  }

  JsonMap? get localSummary =>
      _raw == null ? null : CloudProgress.project(_raw!);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stage = SyncStage.stopped;
    _debouncer?.cancel();
    super.dispose();
  }
}
