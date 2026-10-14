import 'package:flutter/foundation.dart';

/// Phone app UI served from the web, for iPhone users who add it to the
/// home screen (no App Store build). Built with --dart-define=MOBILE_WEB=true.
const mobileWeb = kIsWeb && bool.fromEnvironment('MOBILE_WEB');

/// The phone UI inside a desktop browser frame, for local previews only.
const mobilePreview = kIsWeb && bool.fromEnvironment('MOBILE_PREVIEW');

/// Browsers stop GPS once the screen locks, so on the web walk/run quests
/// are counted from session time instead of GPS distance.
const timedWorkouts = kIsWeb;
