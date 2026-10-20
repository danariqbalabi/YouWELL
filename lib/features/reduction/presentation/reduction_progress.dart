import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

String _unit(String product) => product == 'cigarette' ? 'batang' : 'sesi';

class ReductionProgress extends StatelessWidget {
  const ReductionProgress({super.key, required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final baseline = c.consumptionWeek(1);
    final products = {
      ...productsFor(c.nicotineProduct),
      for (final product in ['cigarette', 'vape'])
        if (c.nicotineDays.any((row) => row[product] is num)) product,
    };
    final currentWeek = c.uatProgram!.week;
    final history = c.habitSwaps.reversed.toList();
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          c.studyPeriodComplete
              ? 'Rekap 28 hari'
              : 'Minggu $currentWeek · langkah kecil',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'Rata-rata memakai hari yang totalnya sudah dikonfirmasi. '
          'Perbandingan membutuhkan minimal 4 hari tercatat pada kedua minggu.'
          '${products.contains('vape') ? ' Angka sesi vape tidak mengukur dosis nikotin.' : ''}',
        ),
        const SizedBox(height: 12),
        for (var week = 1; week <= 4; week++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GameCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Minggu $week',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final product in products) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${nicotineProductLabels[product]}: '
                      '${c.consumptionWeek(week).meanFor(product)?.toStringAsFixed(1) ?? 'belum ada data'}'
                      '${c.consumptionWeek(week).meanFor(product) == null ? '' : ' ${_unit(product)}/hari'} '
                      '(${c.consumptionWeek(week).daysFor(product)}/7 hari tercatat)',
                    ),
                    if (week > 1)
                      _Change(
                        week: c.consumptionWeek(week),
                        baseline: baseline,
                        product: product,
                      ),
                    if (c.targetFor(week, product) != null)
                      Text(
                        'Batas yang dipilih: ${c.targetFor(week, product)!['limit']} ${_unit(product)}/hari',
                      ),
                  ],
                ],
              ),
            ),
          ),
        if (!c.studyPeriodComplete && currentWeek > 1) ...[
          Text(
            'Pilihan target minggu ini',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Boleh mempertahankan target atau belum memilih. Tidak ada kenaikan beban otomatis.',
          ),
          for (final product in productsFor(c.nicotineProduct))
            baseline.comparableFor(product)
                ? _TargetEditor(
                    key: ValueKey('target-$currentWeek-$product'),
                    controller: c,
                    product: product,
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${nicotineProductLabels[product]}: lengkapi minimal 4 hari minggu pertama untuk memilih target.',
                    ),
                  ),
        ],
        const SizedBox(height: 16),
        Text(
          'Catatan momen terakhir',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Hasil momen dilaporkan sendiri. Momen yang terlewati tidak '
          'otomatis berarti hari itu bebas; itu dilihat dari total harian.',
        ),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Belum ada catatan momen.'),
          ),
        for (final row in history.take(20))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${row['day']} · ${nicotineProductLabels[row['product']] ?? 'Arsip Habit Swap'}',
            ),
            subtitle: Text(_momentText(row)),
          ),
      ],
    );
  }
}

/// Trigger, activities and outcome of one moment, old rows included. A
/// missing outcome is shown as such, never guessed.
String _momentText(Map row) {
  final product = row['product']?.toString() ?? 'cigarette';
  final names = activityNames(row);
  final outcome = row['outcome'];
  final result = outcome == null
      ? (awaitingOutcome(row) ? 'Hasil belum diisi' : 'Hasil belum dicatat')
      : outcome == 'not_tried'
      ? swapOutcomeLabels['not_tried']!
      : outcomeLabel(outcome.toString(), product);
  final used = row['usedProduct'] is String
      ? ' (${nicotineProductLabels[row['usedProduct']]?.toLowerCase()})'
      : '';
  return [
    triggerText(row) ?? 'Pemicu tidak dicatat',
    names.isEmpty
        ? (row['swap']?.toString() ?? 'Belum mencoba')
        : names.join(', '),
    '$result$used',
  ].join('\n');
}

class _Change extends StatelessWidget {
  const _Change({
    required this.week,
    required this.baseline,
    required this.product,
  });
  final ConsumptionWeek week, baseline;
  final String product;
  @override
  Widget build(BuildContext context) {
    final change = week.changeFrom(baseline, product);
    return Text(
      change == null
          ? (week.comparableFor(product) &&
                    baseline.comparableFor(product) &&
                    baseline.meanFor(product) == 0
                ? 'Rata-rata awal 0; persentase perubahan tidak dihitung.'
                : 'Belum cukup data untuk membandingkan persentase dengan minggu 1.')
          : change == 0
          ? 'Rata-rata sama dengan minggu 1.'
          : 'Rata-rata ${change.abs().toStringAsFixed(0)}% lebih ${change < 0 ? 'rendah' : 'tinggi'} dari minggu 1.',
      style: TextStyle(color: context.colors.muted),
    );
  }
}

class _TargetEditor extends StatefulWidget {
  const _TargetEditor({
    super.key,
    required this.controller,
    required this.product,
  });
  final WellnessController controller;
  final String product;
  @override
  State<_TargetEditor> createState() => _TargetEditorState();
}

class _TargetEditorState extends State<_TargetEditor> {
  late final _limit = TextEditingController(
    text:
        widget.controller
            .targetFor(
              widget.controller.uatProgram!.week,
              widget.product,
            )?['limit']
            ?.toString() ??
        '',
  );
  String? _error;
  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, product = widget.product;
    final max = c.consumptionWeek(1).meanFor(product)!.ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _limit,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText:
                  'Batas pilihan ${nicotineProductLabels[product]} per hari',
              helperText:
                  '0–$max ${_unit(product)}. Kosongkan untuk menghapus target.',
            ),
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: context.colors.reduction)),
          TextButton(
            onPressed: () {
              final text = _limit.text.trim();
              final limit = int.tryParse(text);
              if ((text.isNotEmpty && limit == null) ||
                  !c.setReductionTarget(product, limit)) {
                setState(
                  () => _error = 'Isi angka bulat dalam rentang pilihan.',
                );
                return;
              }
              setState(() => _error = null);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pilihan target disimpan.')),
              );
            },
            child: Text('Simpan pilihan ${nicotineProductLabels[product]}'),
          ),
        ],
      ),
    );
  }
}
