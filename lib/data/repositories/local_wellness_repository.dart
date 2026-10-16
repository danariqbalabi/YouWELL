import 'package:shared_preferences/shared_preferences.dart';
import 'package:youwell/core/storage/wellness_repository.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';

/// Local browser/device persistence for the web preview.
class LocalWellnessRepository implements WellnessRepository {
  LocalWellnessRepository(this._preferences, {required this.storageKey});
  final SharedPreferences _preferences;
  final String storageKey;

  /// True when [read] set aside a snapshot this version cannot open.
  bool recoveredUnreadable = false;

  /// A corrupt or newer-version snapshot is moved aside, never overwritten.
  @override
  Future<String?> read() async {
    final saved = _preferences.getString(storageKey);
    if (saved == null || canRestoreWellnessState(saved)) return saved;
    if (!await _preferences.setString('$storageKey.unreadable', saved)) {
      throw StateError('Salinan data lama belum dapat diamankan.');
    }
    await _preferences.remove(storageKey);
    recoveredUnreadable = true;
    return null;
  }

  @override
  Future<void> write(String serializedState) async {
    final saved = await _preferences.setString(storageKey, serializedState);
    if (!saved) throw StateError('Penyimpanan perangkat penuh.');
  }

  /// Removes all preview data stored by YouWell on this device.
  Future<void> clear() async {
    for (final key in _preferences.getKeys().toList()) {
      if (key == storageKey || key.startsWith('$storageKey.unreadable')) {
        await _preferences.remove(key);
      }
    }
  }
}
