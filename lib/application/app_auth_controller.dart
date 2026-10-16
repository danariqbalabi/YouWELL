import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:youwell/core/config/app_mode.dart';
import 'package:youwell/features/auth/data/account_cache.dart';
import 'package:youwell/features/auth/domain/auth_gateway.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'wellness_controller.dart';

enum AuthStage {
  signedOut,
  signingIn,
  loading,
  importChoice,
  mfa,
  denied,
  ready,
  error,
}

class AppAuthController extends ChangeNotifier {
  AppAuthController({
    required this.gateway,
    required this.cache,
    required this.surface,
    this.timeout = const Duration(seconds: 12),
  });
  final AuthGateway gateway;
  final AccountCache cache;
  final AppSurface surface;
  final Duration timeout;
  StreamSubscription<AuthIdentity?>? _subscription;
  Timer? _loginTimer;
  AuthStage stage = AuthStage.loading;
  String? error;
  WellnessController? wellness;
  String? _userId;
  int _generation = 0;
  bool _disposed = false;

  void start() {
    _subscription ??= gateway.changes.listen(
      (identity) => unawaited(_open(identity)),
      onError: (Object _) =>
          _fail('Sesi login bermasalah. Coba masuk kembali.'),
    );
    unawaited(_open(gateway.identity));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _fail(String message) {
    if (_disposed) return;
    ++_generation;
    error = message;
    stage = AuthStage.error;
    _notify();
  }

  Future<void> _open(AuthIdentity? identity, {bool force = false}) async {
    if (_disposed) return;
    if (!force &&
        identity != null &&
        identity.id == _userId &&
        (stage == AuthStage.mfa ||
            (surface != AppSurface.admin &&
                const [
                  AuthStage.ready,
                  AuthStage.importChoice,
                ].contains(stage)))) {
      return;
    }
    final generation = ++_generation;
    _loginTimer?.cancel();
    error = null;
    final sameUser = identity?.id == _userId;
    _userId = identity?.id;
    if (!sameUser || identity == null) {
      wellness?.dispose();
      wellness = null;
    }
    if (identity == null) {
      stage = AuthStage.signedOut;
      _notify();
      return;
    }
    stage = AuthStage.loading;
    _notify();
    bool current() => !_disposed && generation == _generation;
    try {
      if (surface == AppSurface.admin) {
        final access = await gateway.adminAccess().timeout(timeout);
        if (!current()) return;
        if (access != AdminAccess.allowed) {
          stage = access == AdminAccess.needsMfa
              ? AuthStage.mfa
              : AuthStage.denied;
          _notify();
          return;
        }
      }
      final saved = await cache.read(identity.id).timeout(timeout);
      if (!current()) return;
      final legacy = saved == null
          ? await cache.legacyFor(identity.id).timeout(timeout)
          : null;
      if (!current()) return;
      if (legacy != null) {
        stage = AuthStage.importChoice;
      } else {
        _activate(identity.id, saved);
      }
      if (current()) _notify();
    } catch (_) {
      if (current()) {
        _fail(
          surface == AppSurface.admin
              ? 'Akses admin belum dapat diverifikasi. Periksa koneksi dan migration database.'
              : 'Progres akun belum dapat dibuka. Coba lagi; data lokal tidak dihapus.',
        );
      }
    }
  }

  void _activate(String userId, String? saved) {
    wellness?.dispose();
    wellness = WellnessController(
      saved: saved,
      persist: (state) => cache.write(userId, state),
    );
    stage = AuthStage.ready;
  }

  Future<void> chooseLegacy({required bool import}) async {
    final userId = _userId;
    if (userId == null || stage != AuthStage.importChoice) return;
    final generation = ++_generation;
    stage = AuthStage.loading;
    _notify();
    try {
      final saved = import
          ? await cache.importLegacy(userId).timeout(timeout)
          : null;
      if (_disposed || generation != _generation) return;
      if (!import) {
        await cache
            .write(userId, jsonEncode(createEmptyWellnessState()))
            .timeout(timeout);
      }
      if (_disposed || generation != _generation) return;
      _activate(userId, saved);
      _notify();
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _fail('Progres belum dapat dihubungkan. Salinan lama tetap tersimpan.');
      }
    }
  }

  Future<void> signIn() async {
    if (stage == AuthStage.signingIn) return;
    error = null;
    stage = AuthStage.signingIn;
    _notify();
    // Cancelling the external browser must not leave a permanent spinner.
    _loginTimer?.cancel();
    _loginTimer = Timer(const Duration(seconds: 60), () {
      if (stage == AuthStage.signingIn) {
        _fail('Login belum selesai. Kamu bisa mencoba lagi.');
      }
    });
    try {
      await gateway.signInWithGoogle().timeout(timeout);
    } catch (_) {
      _loginTimer?.cancel();
      if (stage == AuthStage.signingIn) {
        _fail(
          'Google Login tidak dapat dibuka. Periksa koneksi lalu coba lagi.',
        );
      }
    }
  }

  Future<void> signOut() async {
    ++_generation;
    _loginTimer?.cancel();
    _userId = null;
    wellness?.dispose();
    wellness = null;
    stage = AuthStage.loading;
    _notify();
    try {
      await gateway.signOut().timeout(timeout);
      if (_disposed) return;
      stage = AuthStage.signedOut;
      error = null;
      _notify();
    } catch (_) {
      _fail('Keluar belum selesai. Data akun disembunyikan; coba keluar lagi.');
    }
  }

  Future<void> retry() => _open(gateway.identity, force: true);

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _loginTimer?.cancel();
    _subscription?.cancel();
    wellness?.dispose();
    super.dispose();
  }
}
