/// Public build-time configuration loaded with --dart-define-from-file.
/// Values are injected with --dart-define-from-file at build time.
abstract final class AppEnvironment {
  static const appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'YouWELL',
  );
  static const name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const storageKey = String.fromEnvironment(
    'LOCAL_STORAGE_KEY',
    defaultValue: 'youwell.local.v3',
  );
  static const showPreviewTools = bool.fromEnvironment(
    'SHOW_PREVIEW_TOOLS',
    defaultValue: true,
  );
  static const playStoreUrl = String.fromEnvironment('PLAY_STORE_URL');
  static const appStoreUrl = String.fromEnvironment('APP_STORE_URL');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  // Local UI previews must opt out explicitly. Missing credentials must never
  // silently bypass authentication in a release build.
  static const authEnabled = bool.fromEnvironment(
    'AUTH_ENABLED',
    defaultValue: true,
  );
  static const authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'com.youwell.app://login-callback/',
  );
}
