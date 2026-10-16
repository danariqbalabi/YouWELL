import 'dart:collection';
import 'dart:convert';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';

/// Explicit cloud boundary. Never send a raw controller export to the server.
abstract final class CloudProgress {
  static const _shared = [
    'days',
    'capacity',
    'mobileRewards',
    'achievements',
    'openedDays',
    'activityDays',
    'levelFloor',
    'themeMode',
    'reduceMotion',
    'haptics',
    'companionAccessory',
    'companionBackground',
  ];
  static const _privateKeys = {
    'photoPath',
    'photo',
    'image',
    'bytes',
    'base64',
    'latitude',
    'longitude',
    'coordinates',
    'route',
    'note',
    'noteEditedAt',
    'email',
    'user_id',
    'researchParticipation',
    'participant_code',
    'access_token',
    'refresh_token',
  };

  static JsonMap _pick(Map source, List<String> keys) => {
    for (final key in keys)
      if (source.containsKey(key)) key: source[key],
  };

  static Object? _strip(Object? value) => switch (value) {
    Map() => {
      for (final entry in value.entries)
        if (!_privateKeys.contains(entry.key))
          entry.key.toString(): _strip(entry.value),
    },
    List() => [for (final item in value) _strip(item)],
    _ => value,
  };

  static JsonMap project(String raw) {
    final source = restoreWellnessState(raw);
    final profile = source['profile'];
    return {
      'schemaVersion': 1,
      'version': 3,
      'profile': profile is Map
          ? _pick(profile, [
              'alias',
              'path',
              'pace',
              'lowImpact',
              'companion',
              'started',
              'waterGoal',
              'ageGroup',
            ])
          : null,
      for (final key in _shared)
        if (source.containsKey(key)) key: _strip(source[key]),
      'workoutSessions': [
        for (final row in (source['workoutSessions'] as List).whereType<Map>())
          _pick(row, [
            'id',
            'day',
            'time',
            'kind',
            'seconds',
            'meters',
            'countsForQuest',
            'correctedAt',
          ]),
      ],
      'mealCheckIns': [
        for (final row in (source['mealCheckIns'] as List).whereType<Map>())
          {
            ..._pick(row, ['id', 'day', 'time']),
            'photoCaptured':
                row['photoCaptured'] == true || row['photoPath'] is String,
          },
      ],
      'habitDelays': [
        for (final row in (source['habitDelays'] as List).whereType<Map>())
          _pick(row, [
            'id',
            'day',
            'time',
            'minutes',
            'plannedMinutes',
            'completed',
          ]),
      ],
      'habitSwaps': [
        for (final row in (source['habitSwaps'] as List).whereType<Map>())
          _pick(row, ['id', 'day', 'time']),
      ],
    };
  }

  /// Overlay shared fields, keeping device-only data and local photo handles.
  static String apply(JsonMap payload, String? local) {
    if (payload['schemaVersion'] != 1 || payload['version'] != 3) {
      throw const FormatException('Unsupported cloud progress schema');
    }
    final device = local == null
        ? createEmptyWellnessState()
        : restoreWellnessState(local);
    final shared = project(
      jsonEncode({...createEmptyWellnessState(), ...payload}),
    );
    final result = {...device, ...shared}..remove('schemaVersion');
    for (final collection in [
      'mealCheckIns',
      'workoutSessions',
      'habitSwaps',
    ]) {
      final rows = (device[collection] as List).whereType<Map>();
      final originals = {for (final row in rows) row['id']: row};
      result[collection] = [
        for (final row in ((shared[collection] ?? []) as List).whereType<Map>())
          {
            ...row,
            if (collection == 'habitSwaps') 'swap': 'Aktivitas pengganti',
            if (originals[row['id']] case final original?)
              ..._pick(original, [
                'photoPath',
                'note',
                'noteEditedAt',
                if (collection == 'habitSwaps') ...[
                  'eventId',
                  'product',
                  'trigger',
                  'activity',
                  'outcome',
                  'swap',
                ],
              ]),
          },
      ];
    }
    return jsonEncode(result);
  }

  static String canonical(Object? value) {
    Object? order(Object? input) => switch (input) {
      Map() => SplayTreeMap<String, Object?>.from({
        for (final entry in input.entries)
          entry.key.toString(): order(entry.value),
      }),
      List() => input.map(order).toList(),
      num() => input == input.roundToDouble() ? input.toInt() : input,
      _ => input,
    };
    return jsonEncode(order(value));
  }
}

class CloudProgressSnapshot {
  const CloudProgressSnapshot({
    required this.revision,
    required this.payload,
    required this.updatedAt,
  });
  final int revision;
  final JsonMap payload;
  final DateTime updatedAt;
  factory CloudProgressSnapshot.fromJson(Map value) => CloudProgressSnapshot(
    revision: (value['revision'] as num).toInt(),
    payload: Map<String, dynamic>.from(value['payload'] as Map),
    updatedAt: DateTime.parse(value['updated_at'] as String),
  );
}

class ProgressSaveResult {
  const ProgressSaveResult({required this.saved, required this.snapshot});
  final bool saved;
  final CloudProgressSnapshot? snapshot;
}

abstract interface class ProgressCloudStore {
  Future<CloudProgressSnapshot?> read();
  Future<ProgressSaveResult> save(
    JsonMap payload, {
    required int expectedRevision,
  });
}
