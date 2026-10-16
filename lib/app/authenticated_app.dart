import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youwell/application/app_auth_controller.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/core/config/app_mode.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/features/auth/data/account_cache.dart';
import 'package:youwell/features/auth/data/supabase_auth_gateway.dart';
import 'package:youwell/features/auth/presentation/account_scope.dart';
import 'package:youwell/features/auth/presentation/auth_page.dart';
import 'youwell_app.dart';

class AuthenticatedApp extends StatefulWidget {
  const AuthenticatedApp({super.key, required this.preferences});
  final SharedPreferences preferences;
  @override
  State<AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<AuthenticatedApp> {
  AppAuthController? _auth;
  Future<Supabase>? _initialization;
  String? _error;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  Future<void> _connect() async {
    final attempt = ++_attempt;
    setState(() => _error = null);
    try {
      final url = Uri.tryParse(AppEnvironment.supabaseUrl);
      if (url == null ||
          url.scheme != 'https' ||
          url.host.isEmpty ||
          !AppEnvironment.supabasePublishableKey.startsWith(
            'sb_publishable_',
          )) {
        throw StateError('Missing public Supabase configuration');
      }
      // Retain an in-flight initializer on timeout; never initialize twice.
      final initialization = _initialization ??= Supabase.initialize(
        url: url.toString(),
        publishableKey: AppEnvironment.supabasePublishableKey,
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      final sdk = await initialization.timeout(const Duration(seconds: 12));
      if (!mounted || attempt != _attempt) return;
      final auth = AppAuthController(
        gateway: SupabaseAuthGateway(sdk.client),
        cache: AccountCache(
          widget.preferences,
          baseKey: AppEnvironment.storageKey,
          projectHost: url.host,
          surface: appSurface,
        ),
        surface: appSurface,
      );
      setState(() => _auth = auth);
      auth.start();
    } catch (error) {
      if (error is! TimeoutException) _initialization = null;
      if (mounted && attempt == _attempt) {
        setState(
          () => _error =
              'Login belum siap. Periksa SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY pada konfigurasi build, lalu coba lagi.',
        );
      }
    }
  }

  @override
  void dispose() {
    ++_attempt;
    _auth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = _auth;
    if (auth == null) {
      return _frame(
        AuthPage(
          title: 'YouWELL',
          message: _error ?? 'Menyiapkan koneksi akun.',
          busy: _error == null,
          actions: [
            if (_error != null)
              FilledButton(onPressed: _connect, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    return AnimatedBuilder(
      animation: auth,
      builder: (_, _) {
        if (auth.stage == AuthStage.ready && auth.wellness != null) {
          return AccountScope(
            auth: auth,
            child: YouWellApp(
              key: ObjectKey(auth.wellness),
              controller: auth.wellness!,
            ),
          );
        }
        return _frame(AuthStagePage(auth: auth));
      },
    );
  }

  Widget _frame(Widget home) => MaterialApp(
    title: 'YouWELL',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.mobileLight,
    darkTheme: AppTheme.mobileDark,
    home: home,
  );
}
