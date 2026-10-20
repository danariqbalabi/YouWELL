import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/theme/appearance_scope.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';
import 'package:youwell/features/companion/presentation/mobile_companion.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/features/auth/presentation/account_scope.dart';

/// Conversational onboarding: the companion asks one question per screen.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  int _pace = 1;
  String _path = 'wellness';
  String _companion = 'plant';
  bool _lowImpact = false;
  String? _ageGroup;
  String? _nicotineProduct;
  String? _error;
  final _alias = TextEditingController();

  static const _lastStep = 3;

  /// 18–22 spans the PP 28/2024 age-21 line, so it gets quit framing too.
  bool get _quitFraming => _ageGroup == 'under18' || _ageGroup == '18-22';

  /// Blocks "Lanjut" until the current step has what the rules require.
  String? _stepError() => switch (_step) {
    0 when _ageGroup == null => 'Pilih rentang usiamu dulu.',
    1 when _path == 'reduction' && _nicotineProduct == null =>
      'Pilih jenis penggunaanmu dulu.',
    _ => null,
  };

  @override
  void dispose() {
    _alias.dispose();
    super.dispose();
  }

  void _pick(VoidCallback change) => setState(() {
    change();
    _error = null;
  });

  Future<void> _next() async {
    final blocked = _stepError();
    if (blocked != null) {
      setState(() => _error = blocked);
      return;
    }
    if (_step < _lastStep) {
      setState(() {
        _step++;
        _error = null;
      });
      return;
    }
    try {
      await widget.controller.setup({
        'alias': _alias.text,
        'path': _path,
        'pace': _pace,
        'lowImpact': _lowImpact,
        'companion': _companion,
        'ageGroup': _ageGroup,
        if (_path == 'reduction') 'nicotineProduct': _nicotineProduct,
      });
    } on ArgumentError {
      if (mounted) {
        setState(
          () => _error = 'Alias 3–20 karakter, diawali huruf (huruf/angka/_).',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Profil belum tersimpan di perangkat. Coba lagi.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (question, helper) = switch (_step) {
      0 => ('Hai! Aku $companionName, teman tumbuhmu. Umurmu berapa?', ''),
      1 => (
        'Oke! Kamu mau fokus ke mana dulu?',
        'Bisa diganti kapan saja di Profil.',
      ),
      2 => (
        'Mau mulai sesantai apa?',
        'Tenang, misinya naik pelan-pelan ketika kamu siap.',
      ),
      _ => (
        'Terakhir! Pilih warna $companionName, lalu kasih tahu mau dipanggil apa.',
        'Alias ini yang tampil di Community, bukan nama asli.',
      ),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Kembali',
                        onPressed: _step == 0
                            ? null
                            : () => setState(() {
                                _step--;
                                _error = null;
                              }),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: _step == 0 ? Colors.transparent : c.muted,
                        ),
                      ),
                      Expanded(
                        child: XpBar(value: (_step + 1) / (_lastStep + 1)),
                      ),
                      const SizedBox(width: 4),
                      const ThemeModeButton(),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          CompanionPreview(
                            kind: _companion,
                            stage: 2,
                            size: 92,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _Bubble(question)),
                        ],
                      ),
                      if (helper.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          helper,
                          style: TextStyle(
                            color: c.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      ..._stepContent(context),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.reduction,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ChunkyButton(
                        label: _step == _lastStep ? 'Mulai' : 'Lanjut',
                        onPressed: _next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _stepContent(BuildContext context) => switch (_step) {
    0 => [
      for (final (value, title, icon) in const [
        ('22plus', 'Di atas 22 tahun', Icons.work_outline_rounded),
        ('18-22', '18–22 tahun', Icons.school_rounded),
        ('under18', 'Di bawah 18 tahun', Icons.backpack_rounded),
      ])
        _Option(
          icon: icon,
          title: title,
          selected: _ageGroup == value,
          onTap: () => _pick(() => _ageGroup = value),
        ),
    ],
    1 => [
      _Option(
        icon: Icons.wb_sunny_rounded,
        title: 'Better Daily Rhythm',
        detail: 'Gerak, tidur, minum, dan kebiasaan kecil.',
        selected: _path == 'wellness',
        onTap: () => _pick(() => _path = 'wellness'),
      ),
      _Option(
        icon: Icons.smoke_free_rounded,
        title: _quitFraming ? 'Berhenti rokok / vape' : 'Kurangi rokok / vape',
        detail: _quitFraming
            ? 'Siapkan kegiatan pengganti dan coba saat keinginan muncul.'
            : 'Coba aktivitas pengganti saat ingin, tanpa dihakimi.',
        selected: _path == 'reduction',
        onTap: () => _pick(() => _path = 'reduction'),
      ),
      if (_path == 'reduction') ...[
        const SizedBox(height: 12),
        const Text('Apa yang kamu gunakan? Bisa diubah nanti di Profil.'),
        for (final entry in nicotineChoiceLabels.entries)
          _Option(
            icon: Icons.smoke_free_rounded,
            title: entry.value,
            selected: _nicotineProduct == entry.key,
            onTap: () => _pick(() => _nicotineProduct = entry.key),
          ),
      ],
    ],
    2 => [
      for (final (value, title, detail, icon) in const [
        (
          1,
          'Santai dulu',
          'Mulai dari jalan 400 m · kartu 3 misi',
          Icons.spa_rounded,
        ),
        (
          2,
          'Sedang',
          'Mulai dari jalan 800 m · kartu 4 misi',
          Icons.directions_walk,
        ),
        (
          3,
          'Siap gerak',
          'Mulai dari jalan cepat 1,2 km · kartu 5 misi',
          Icons.bolt_rounded,
        ),
      ])
        _Option(
          icon: icon,
          title: title,
          detail: detail,
          selected: _pace == value,
          onTap: () => _pick(() => _pace = value),
        ),
      const SizedBox(height: 6),
      GameCard(
        padding: EdgeInsets.zero,
        child: SwitchListTile(
          title: const Text(
            'Aku lebih nyaman gerakan ringan',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text('Tanpa misi lari. Bisa diubah nanti.'),
          value: _lowImpact,
          onChanged: (value) => _pick(() => _lowImpact = value),
        ),
      ),
    ],
    _ => [
      Row(
        children: [
          for (final (index, kind) in const [
            'plant',
            'cat',
            'cloud',
          ].indexed) ...[
            if (index > 0) const SizedBox(width: 10),
            Expanded(
              child: _CompanionChoice(
                kind: kind,
                name: companionColors[kind]!,
                selected: _companion == kind,
                onTap: () => _pick(() => _companion = kind),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 18),
      TextField(
        controller: _alias,
        maxLength: 20,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _next(),
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        decoration: const InputDecoration(
          labelText: 'Nama panggilan (alias)',
          hintText: 'misalnya: daunpagi',
          helperText: '3–20 karakter, diawali huruf.',
        ),
      ),
      if (AccountScope.maybeOf(context)?.progress != null) ...[
        const SizedBox(height: 8),
        const Text(
          'Profil dan progres disinkronkan ke akunmu. Foto dan catatan pribadi tetap di perangkat.',
        ),
      ],
    ],
  };
}

/// Speech bubble with a small tail pointing at the companion.
class _Bubble extends StatelessWidget {
  const _Bubble(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
        ),
        border: Border.all(color: c.border, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Big tappable answer card (one per option).
class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.detail,
  });
  final IconData icon;
  final String title;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        child: GameCard(
          onTap: onTap,
          color: selected ? c.selected : c.card,
          borderColor: selected ? c.primary : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? c.primary : c.raised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: selected ? c.onPrimary : c.text),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (detail != null)
                      Text(detail!, style: TextStyle(color: c.muted)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? c.success : c.border,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanionChoice extends StatelessWidget {
  const _CompanionChoice({
    required this.kind,
    required this.name,
    required this.selected,
    required this.onTap,
  });
  final String kind, name;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Pilih warna $name',
      child: GameCard(
        onTap: onTap,
        color: selected ? c.selected : c.card,
        borderColor: selected ? c.primary : null,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            CompanionPreview(kind: kind, stage: 2, size: 72),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
