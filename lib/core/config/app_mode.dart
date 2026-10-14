import 'package:flutter/foundation.dart';

/// Phone app UI served from the web, for iPhone users who add it to the
/// home screen (no App Store build). Built with --dart-define=MOBILE_WEB=true.
const mobileWeb = kIsWeb && bool.fromEnvironment('MOBILE_WEB');

/// The phone UI inside a desktop browser frame, for local previews only.
const mobilePreview = kIsWeb && bool.fromEnvironment('MOBILE_PREVIEW');

/// A normal web build is the moderator console. Phone web builds opt in above.
const adminWeb = kIsWeb && !mobileWeb && !mobilePreview;

enum AppSurface { mobile, mobilePreview, admin }

/// Resolve the build target, independent of browser size or device detection.
AppSurface resolveAppSurface({
  required bool isWeb,
  bool phoneWeb = false,
  bool preview = false,
}) {
  if (!isWeb) return AppSurface.mobile;
  if (phoneWeb && preview) {
    throw ArgumentError(
      'MOBILE_WEB dan MOBILE_PREVIEW tidak boleh aktif bersamaan.',
    );
  }
  if (preview) return AppSurface.mobilePreview;
  return phoneWeb ? AppSurface.mobile : AppSurface.admin;
}

final appSurface = resolveAppSurface(
  isWeb: kIsWeb,
  phoneWeb: mobileWeb,
  preview: mobilePreview,
);

/// Admin fixtures and phone previews never read a participant's local profile.
String storageKeyForSurface(String base, AppSurface surface) =>
    switch (surface) {
      AppSurface.admin => '$base.admin-preview',
      AppSurface.mobilePreview => '$base.mobile-preview',
      AppSurface.mobile => base,
    };

/// Browsers stop GPS once the screen locks, so on the web walk/run quests
/// are counted from session time instead of GPS distance.
const timedWorkouts = kIsWeb;
