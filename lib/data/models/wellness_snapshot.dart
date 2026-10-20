import 'dart:convert';

import 'package:youwell/core/types/json_map.dart';

/// Local-only product state while the experience is being validated.
/// Version 3 remains backward-compatible with new local activity collections.
JsonMap createEmptyWellnessState() => {
  'version': 3,
  'dayOffset': 0,
  'themeMode': 'system',
  'mobileRewards': <String, dynamic>{},
  'achievements': <String, dynamic>{},
  'activityDays': <dynamic>[],
  'reduceMotion': false,
  'haptics': true,
  'researchParticipation': null,
  'companionAccessory': 'none',
  'companionBackground': 'natural',
  'profile': null,
  'days': <String, dynamic>{},
  'focusSessions': <dynamic>[],
  'habitDelays': <dynamic>[],
  'habitSwaps': <dynamic>[],
  'reductionSettings': <String, dynamic>{},
  'nicotineDays': <dynamic>[],
  'reductionTargets': <dynamic>[],
  'reductionPlans': <String, dynamic>{},
  'reductionSetup': <String, dynamic>{},
  'openedDays': <dynamic>[],
  'capacity': <String, dynamic>{},
  'workoutSessions': <dynamic>[],
  'mealCheckIns': <dynamic>[],
  'communityPosts': <dynamic>[],
  'communityReactions': <dynamic>[],
  'communityReports': <dynamic>[],
  'squad': null,
  'buddy': null,
};

JsonMap restoreWellnessState(String serialized) {
  final decoded = jsonDecode(serialized);
  if (decoded is! Map<String, dynamic> || decoded['version'] != 3) {
    throw const FormatException('Unsupported local state format');
  }
  return {...createEmptyWellnessState(), ...decoded};
}

bool canRestoreWellnessState(String serialized) {
  try {
    restoreWellnessState(serialized);
    return true;
  } catch (_) {
    return false;
  }
}

/// Shown once after storage set aside a snapshot this version cannot read.
const unreadableStateNotice =
    'Data lokal tidak bisa dibaca, jadi aplikasi mulai baru. '
    'Salinan lamanya tetap disimpan terpisah di perangkat ini.';
