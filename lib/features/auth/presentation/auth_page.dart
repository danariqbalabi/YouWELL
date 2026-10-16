import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youwell/application/app_auth_controller.dart';
import '../domain/auth_gateway.dart';

/// Small, scrollable auth screens. No user data or raw OAuth errors in messages.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    required this.message,
    this.busy = false,
    this.actions = const [],
  });
  final String title, message;
  final bool busy;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.eco_rounded, size: 64),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (busy) const Center(child: CircularProgressIndicator()),
                for (final action in actions) ...[
                  const SizedBox(height: 12),
                  action,
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthStagePage extends StatelessWidget {
  const AuthStagePage({super.key, required this.auth});
  final AppAuthController auth;
  @override
  Widget build(BuildContext context) => switch (auth.stage) {
    AuthStage.loading => const AuthPage(
      title: 'Menyiapkan akun',
      message: 'Membuka progres pada perangkat ini.',
      busy: true,
    ),
    AuthStage.importChoice => AuthPage(
      title: 'Lanjutkan progresmu?',
      message:
          'Ada progres tamu di perangkat ini. Hubungkan ke akun Google ini, atau mulai baru. Salinan lama tidak dihapus. Progres belum disinkronkan ke cloud.',
      actions: [
        FilledButton(
          onPressed: () => auth.chooseLegacy(import: true),
          child: const Text('Gunakan progres tamu'),
        ),
        OutlinedButton(
          onPressed: () => auth.chooseLegacy(import: false),
          child: const Text('Mulai baru di akun ini'),
        ),
        TextButton(onPressed: auth.signOut, child: const Text('Ganti akun')),
      ],
    ),
    AuthStage.denied => AuthPage(
      title: 'Akses admin terbatas',
      message:
          'Akun ini belum terdaftar sebagai moderator. Daftar admin diperiksa di server, bukan dari alamat halaman.',
      actions: [
        FilledButton(onPressed: auth.retry, child: const Text('Periksa lagi')),
        OutlinedButton(
          onPressed: auth.signOut,
          child: const Text('Keluar / ganti akun'),
        ),
      ],
    ),
    AuthStage.mfa => AdminMfaPage(auth: auth),
    AuthStage.signingIn => AuthPage(
      title: 'Lanjutkan di Google',
      message:
          'Pilih akun di browser. Jika dibatalkan, kamu bisa mencoba lagi.',
      busy: true,
      actions: [
        TextButton(
          onPressed: auth.signOut,
          child: const Text('Batalkan login'),
        ),
      ],
    ),
    _ => AuthPage(
      title: 'Selamat datang di YouWELL',
      message:
          auth.error ??
          'Masuk untuk memakai akunmu. Komunitas tetap menggunakan alias, bukan nama Google. Pada tahap ini progres masih tersimpan di perangkat.',
      actions: [
        FilledButton.icon(
          onPressed: auth.signIn,
          icon: const Icon(Icons.login_rounded),
          label: const Text('Masuk dengan Google'),
        ),
        if (auth.stage == AuthStage.error) ...[
          OutlinedButton(
            onPressed: auth.retry,
            child: const Text('Coba buka sesi lagi'),
          ),
          TextButton(
            onPressed: auth.signOut,
            child: const Text('Keluar dari sesi'),
          ),
        ],
      ],
    ),
  };
}

class AdminMfaPage extends StatefulWidget {
  const AdminMfaPage({super.key, required this.auth});
  final AppAuthController auth;
  @override
  State<AdminMfaPage> createState() => _AdminMfaPageState();
}

class _AdminMfaPageState extends State<AdminMfaPage> {
  final _code = TextEditingController();
  MfaSetup? _setup;
  bool _busy = false;
  String? _error;

  Future<void> _prepare() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final setup = await widget.auth.gateway.prepareMfa().timeout(
        widget.auth.timeout,
      );
      if (mounted) setState(() => _setup = setup);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Authenticator belum dapat disiapkan. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_setup == null || !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _error = 'Masukkan kode 6 digit dari authenticator.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.gateway
          .verifyMfa(_setup!.factorId, _code.text.trim())
          .timeout(widget.auth.timeout);
      await widget.auth.retry();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Kode belum valid atau koneksi terputus. Coba kode terbaru.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthPage(
    title: 'Verifikasi admin',
    message:
        _error ??
        'Selain Google Login, moderator wajib menggunakan authenticator (TOTP).',
    busy: _busy,
    actions: [
      if (_setup == null)
        FilledButton(
          onPressed: _busy ? null : _prepare,
          child: const Text('Siapkan authenticator'),
        )
      else ...[
        if (_setup!.secret != null) ...[
          const Text(
            'Tambahkan akun TOTP di aplikasi authenticator dengan kunci ini. Jangan bagikan kunci ini.',
          ),
          SelectableText(_setup!.secret!, textAlign: TextAlign.center),
        ],
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(labelText: 'Kode 6 digit'),
          onSubmitted: (_) {
            if (!_busy) _verify();
          },
        ),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: const Text('Verifikasi'),
        ),
      ],
      TextButton(onPressed: widget.auth.signOut, child: const Text('Keluar')),
    ],
  );
}
