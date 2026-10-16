import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youwell/core/config/app_mode.dart';

/// Device-only cache. It deliberately does not upload snapshots or photo paths.
class AccountCache {
  AccountCache(
    this.preferences, {
    required this.baseKey,
    required this.projectHost,
    required this.surface,
  });
  final SharedPreferences preferences;
  final String baseKey, projectHost;
  final AppSurface surface;

  String keyFor(String userId) =>
      '${storageKeyForSurface(baseKey, surface)}.account.$projectHost.$userId';
  String get _legacyKey => storageKeyForSurface(baseKey, surface);
  String get _claimKey => '$_legacyKey.claimed-by';
  String _owner(String userId) => '$projectHost/$userId';

  Future<String?> read(String userId) async =>
      preferences.getString(keyFor(userId));
  Future<void> write(String userId, String state) async {
    if (!await preferences.setString(keyFor(userId), state)) {
      throw StateError('Progres akun belum tersimpan di perangkat.');
    }
  }

  Future<Map<String, dynamic>?> readSyncMeta(String userId) async {
    final raw = preferences.getString('${keyFor(userId)}.sync');
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> writeSyncMeta(String userId, Map<String, dynamic> value) async {
    if (!await preferences.setString(
      '${keyFor(userId)}.sync',
      jsonEncode(value),
    )) {
      throw StateError('Status sinkron belum tersimpan.');
    }
  }

  Future<void> backup(String userId, String raw) async {
    if (!await preferences.setString('${keyFor(userId)}.before-cloud', raw)) {
      throw StateError('Salinan pemulihan belum tersimpan.');
    }
  }

  String? recoveryFor(String userId) =>
      preferences.getString('${keyFor(userId)}.before-cloud');

  Future<void> backupCloud(String userId, String raw) async {
    if (!await preferences.setString('${keyFor(userId)}.replaced-cloud', raw)) {
      throw StateError('Cadangan cloud belum tersimpan.');
    }
  }

  String? cloudRecoveryFor(String userId) =>
      preferences.getString('${keyFor(userId)}.replaced-cloud');

  Future<String?> legacyFor(String userId) async {
    if (surface == AppSurface.admin) return null;
    final owner = preferences.getString(_claimKey);
    if (owner != null && owner != _owner(userId)) return null;
    final saved = preferences.getString(_legacyKey);
    if (saved == null) return null;
    try {
      final data = jsonDecode(saved);
      return data is Map && data['version'] == 3 && data['profile'] is Map
          ? saved
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<String> importLegacy(String userId) async {
    // Never overwrite an account that already has its own cache.
    final existing = await read(userId);
    if (existing != null) return existing;
    final saved = await legacyFor(userId);
    if (saved == null) throw StateError('Progres tamu tidak tersedia.');
    if (!await preferences.setString(_claimKey, _owner(userId))) {
      throw StateError('Progres tamu belum dapat dihubungkan.');
    }
    await write(userId, saved);
    // Keep the original as a backup; no automatic deletion or cloud import.
    return saved;
  }
}
