import 'package:flutter/material.dart';
import 'package:youwell/core/utils/date_key.dart';
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
  String? _product, _outcome, _error;
  final _triggers = <String>[];
  final _activities = <String>[];
  String _eventId = 'swap-${DateTime.now().microsecondsSinceEpoch}';
  WellnessController get c => widget.controller;
  String? get product =>
      _product ??
      (productsFor(c.nicotineProduct).length == 1
          ? productsFor(c.nicotineProduct).single
          : null);

  void _submit() {
    // Name the one missing step instead of listing every rule.
    final missing = product == null
        ? 'Pilih rokok atau vape dulu.'
        : _triggers.isEmpty
        ? 'Pilih minimal satu pemicu.'
        : _outcome == null
        ? 'Pilih hasilnya.'
        : _outcome != 'not_tried' && _activities.isEmpty
        ? 'Pilih aktivitas yang kamu coba.'
        : null;
    if (missing != null) {
      setState(() => _error = missing);
      return;
    }
    final saved = c.recordHabitSwap(
      eventId: _eventId,
      product: product!,
      triggers: _triggers,
      activities: _activities,
      outcome: _outcome!,
    );
    if (!saved) {
      setState(
        () => _error = 'Belum tersimpan. Momen ini mungkin sudah dicatat.',
      );
      return;
    }
    setState(() {
      _outcome = _error = null;
      _triggers.clear();
      _activities.clear();
      _eventId = 'swap-${DateTime.now().microsecondsSinceEpoch}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Momen tercatat. Terima kasih sudah jujur!'),
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

  /// Chips where several picks are allowed, kept in tap order.
  Widget _multiChoices(
    String title,
    Map<String, String> labels,
    List<String> selected,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 2),
      Text(
        'Boleh pilih lebih dari satu.',
        style: TextStyle(color: context.colors.muted, fontSize: 13),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in labels.entries)
            FilterChip(
              label: Text(entry.value),
              selected: selected.contains(entry.key),
              onSelected: (on) => setState(() {
                on ? selected.add(entry.key) : selected.remove(entry.key);
                _error = null;
              }),
            ),
        ],
      ),
    ],
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
      triggers: _triggers,
      history: c.habitSwaps.where((row) {
        final day = row['day']?.toString() ?? '';
        final from = shiftDayKey(c.today, -6);
        return day.compareTo(from) >= 0 && day.compareTo(c.today) <= 0;
      }).toList(),
    );
    final plan = product == null ? null : c.swapPlan(product!);
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          'Catat satu momen',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Isi setelah momennya lewat. Hasil apa pun boleh.',
          style: TextStyle(color: context.colors.muted),
        ),
        const SizedBox(height: 20),
        if (productsFor(c.nicotineProduct).length != 1)
          _choices(
            'Rokok atau vape?',
            const {'cigarette': 'Rokok', 'vape': 'Vape'},
            product,
            (value) {
              _product = value;
              _outcome = null;
              _triggers.clear();
              _activities.clear();
            },
          ),
        if (plan != null) ...[
          GameCard(
            child: Text(
              'Rencanamu: ${triggerText(plan)} → '
              '${swapActivityLabels[plan['activity']]}',
            ),
          ),
          const SizedBox(height: 18),
        ],
        _multiChoices(
          '1. Apa pemicunya?',
          {
            for (final key in triggersFor(product ?? 'cigarette'))
              key: reductionTriggerLabels[key]!,
          },
          _triggers,
        ),
        const SizedBox(height: 20),
        _multiChoices('2. Aktivitas yang kamu coba', {
          for (final key in activities) key: swapActivityLabels[key]!,
        }, _activities),
        TextButton.icon(
          onPressed:
              c.reduction &&
                  product != null &&
                  _triggers.isNotEmpty &&
                  _activities.isNotEmpty
              ? () {
                  final saved = c.setSwapPlan(
                    product!,
                    [..._triggers],
                    _activities.first,
                  );
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
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Jadikan rencana'),
        ),
        const SizedBox(height: 12),
        _choices(
          '3. Bagaimana hasilnya?',
          {
            'skipped': product == 'vape'
                ? 'Tidak jadi vape'
                : product == 'cigarette'
                ? 'Tidak jadi merokok'
                : swapOutcomeLabels['skipped']!,
            'used': product == 'vape'
                ? 'Sudah coba, tetap vape'
                : product == 'cigarette'
                ? 'Sudah coba, tetap merokok'
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
        FilledButton(onPressed: _submit, child: const Text('Simpan momen')),
        const SizedBox(height: 12),
        Text(
          'Hari ini: ${c.habitSwapsToday} momen · '
          '${c.swapAttemptsToday.length} aktivitas dicoba',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.muted, fontSize: 13),
        ),
      ],
    );
  }
}
