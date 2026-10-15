import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

/// Trigger -> chosen action -> honest outcome. No countdown or time lock.
class HabitSwapPanel extends StatefulWidget {
  const HabitSwapPanel({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<HabitSwapPanel> createState() => _HabitSwapPanelState();
}

class _HabitSwapPanelState extends State<HabitSwapPanel> {
  String? _product, _trigger, _activity, _outcome, _error;
  String _eventId = 'swap-${DateTime.now().microsecondsSinceEpoch}';
  WellnessController get c => widget.controller;
  String? get product =>
      _product ??
      (productsFor(c.nicotineProduct).length == 1
          ? productsFor(c.nicotineProduct).single
          : null);

  void _submit() {
    if (product == null ||
        _trigger == null ||
        _outcome == null ||
        (_outcome != 'not_tried' && _activity == null)) {
      setState(
        () => _error =
            'Lengkapi jenis penggunaan, pemicu, dan hasil. Pilih aktivitas jika sudah mencoba.',
      );
      return;
    }
    final saved = c.recordHabitSwap(
      eventId: _eventId,
      product: product!,
      trigger: _trigger!,
      activity: _activity ?? '',
      outcome: _outcome!,
    );
    if (!saved) {
      setState(
        () => _error =
            'Catatan belum ditambahkan. Periksa periode atau catatan yang sudah tersimpan.',
      );
      return;
    }
    setState(() {
      _trigger = _activity = _outcome = _error = null;
      _eventId = 'swap-${DateTime.now().microsecondsSinceEpoch}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Catatan tersimpan. Terima kasih sudah mencatat dengan jujur.',
        ),
      ),
    );
  }

  Widget _choices(
    String title,
    Map<String, String> labels,
    String? selected,
    ValueChanged<String> onSelect,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in labels.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: selected == entry.key,
                onSelected: (_) => setState(() {
                  onSelect(entry.key);
                  _error = null;
                }),
              ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (c.uatProgramComplete) {
      return const Padding(
        padding: EdgeInsets.all(22),
        child: Text(
          'Perjalanan 28 hari selesai. Catatan dan rekap tetap tersedia di Progres.',
        ),
      );
    }
    final activities = suggestedSwaps(
      lowImpact: c.profile?['lowImpact'] == true,
      product: product ?? '',
      trigger: _trigger ?? '',
      history: c.habitSwaps.where((row) {
        final day = row['day']?.toString() ?? '';
        final from = c.now
            .subtract(const Duration(days: 6))
            .toIso8601String()
            .substring(0, 10);
        return day.compareTo(from) >= 0 && day.compareTo(c.today) <= 0;
      }).toList(),
    );
    final plan = product == null ? null : c.swapPlan(product!);
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          'Kenali momenmu',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Catat setelah momen berlalu. Hasil apa pun boleh dicatat. '
          'Mencoba aktivitas pengganti menyelesaikan misi latihan harian sekali.',
          style: TextStyle(color: context.colors.muted),
        ),
        const SizedBox(height: 20),
        if (productsFor(c.nicotineProduct).length != 1)
          _choices(
            'Jenis penggunaan pada momen ini',
            const {'cigarette': 'Rokok', 'vape': 'Vape'},
            product,
            (value) {
              _product = value;
              _trigger = _activity = _outcome = null;
            },
          ),
        if (plan != null) ...[
          GameCard(
            child: Text(
              'Rencanamu: ${reductionTriggerLabels[plan['trigger']]} → '
              '${swapActivityLabels[plan['activity']]}',
            ),
          ),
          const SizedBox(height: 18),
        ],
        _choices(
          '1. Apa pemicunya?',
          {
            for (final key in triggersFor(product ?? 'cigarette'))
              key: reductionTriggerLabels[key]!,
          },
          _trigger,
          (value) => _trigger = value,
        ),
        _choices(
          '2. Aktivitas yang kamu coba',
          {for (final key in activities) key: swapActivityLabels[key]!},
          _activity,
          (value) => _activity = value,
        ),
        Text(
          c.profile?['lowImpact'] == true
              ? 'Gerak sambil duduk tersedia. Pilih yang terasa nyaman.'
              : 'Gerak ringan menjadi pilihan awal. Urutan juga mengikuti laporanmu pada pemicu yang sama. Pilih yang cocok.',
          style: TextStyle(color: context.colors.muted),
        ),
        TextButton(
          onPressed:
              c.reduction &&
                  product != null &&
                  _trigger != null &&
                  _activity != null
              ? () {
                  final saved = c.setSwapPlan(product!, _trigger!, _activity!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        saved
                            ? 'Rencana disimpan.'
                            : 'Periode UAT sudah selesai. Rencana tidak ditambahkan.',
                      ),
                    ),
                  );
                }
              : null,
          child: const Text('Simpan sebagai rencana untuk momen berikutnya'),
        ),
        const SizedBox(height: 12),
        _choices(
          '3. Bagaimana hasilnya?',
          {
            'skipped': product == 'vape'
                ? 'Melewatkan vape pada momen ini'
                : product == 'cigarette'
                ? 'Melewatkan rokok pada momen ini'
                : swapOutcomeLabels['skipped']!,
            'used': product == 'vape'
                ? 'Sudah mencoba, tetap vape'
                : product == 'cigarette'
                ? 'Sudah mencoba, tetap merokok'
                : swapOutcomeLabels['used']!,
            'not_tried': swapOutcomeLabels['not_tried']!,
          },
          _outcome,
          (value) => _outcome = value,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: context.colors.reduction),
            ),
          ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Simpan catatan momen'),
        ),
        const SizedBox(height: 12),
        Text(
          '${c.habitSwapsToday} catatan momen hari ini · '
          '${c.swapAttemptsToday.length} aktivitas dicoba',
        ),
        const SizedBox(height: 8),
        const Text(
          'Melewatkan satu momen tidak otomatis berarti jumlah konsumsi harian turun. '
          'Lengkapi Catatan harian untuk melihat polanya.',
        ),
      ],
    );
  }
}
