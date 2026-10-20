import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';

class ReductionDiary extends StatefulWidget {
  const ReductionDiary({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<ReductionDiary> createState() => _ReductionDiaryState();
}

class _ReductionDiaryState extends State<ReductionDiary> {
  final _cigarettes = TextEditingController(), _vape = TextEditingController();
  String? _day, _product, _error;
  bool _confirmed = false;
  WellnessController get c => widget.controller;

  /// Every day from the start until today. The diary stays open after day
  /// 28; research summaries only read weeks 1-4.
  List<String> get dates {
    final first = dayKey(c.uatProgram!.firstDay);
    final count = daysBetweenKeys(first, c.today) + 1;
    return [for (var i = count - 1; i >= 0; i--) shiftDayKey(first, i)];
  }

  @override
  void initState() {
    super.initState();
    if (dates.isNotEmpty) _load(dates.first);
  }

  void _load(String day) {
    final row = c.nicotineDay(day);
    _day = day;
    _product = row?['product']?.toString() ?? c.nicotineProduct;
    _cigarettes.text = row?['cigarette']?.toString() ?? '';
    _vape.text = row?['vape']?.toString() ?? '';
    _confirmed = false;
    _error = null;
  }

  @override
  void dispose() {
    _cigarettes.dispose();
    _vape.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    final types = productsFor(_product);
    final cigarettes = int.tryParse(_cigarettes.text.trim());
    final vape = int.tryParse(_vape.text.trim());
    if (!_confirmed ||
        _day == null ||
        types.isEmpty ||
        (types.contains('cigarette') && cigarettes == null) ||
        (types.contains('vape') && vape == null)) {
      setState(
        () => _error =
            'Isi total harian dan konfirmasi. Jika tidak menggunakan, tulis 0.',
      );
      return;
    }
    final saved = c.saveNicotineDay(
      day: _day!,
      product: _product!,
      cigarettes: cigarettes,
      vapeSessions: vape,
    );
    if (!saved) {
      setState(
        () => _error =
            'Gunakan angka bulat 0–500 untuk tanggal yang sudah lewat.',
      );
      return;
    }
    setState(() {
      _error = null;
      _confirmed = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Total harian disimpan. Bisa dikoreksi kembali.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          'Total konsumsi harian',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Isi total sepanjang hari, misalnya menjelang tidur. '
          'Hari kosong berarti belum diketahui. Isi 0 jika memang tidak menggunakan.',
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _day,
          decoration: const InputDecoration(labelText: 'Tanggal catatan'),
          items: [
            for (final day in dates)
              DropdownMenuItem(value: day, child: Text(day)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _load(value));
          },
        ),
        const SizedBox(height: 16),
        // The product follows the user's choice; "keduanya" gets two
        // separate numbers. A day saved under another choice keeps it.
        if (_product != c.nicotineProduct)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Catatan tanggal ini disimpan sebagai: '
              '${nicotineProductLabels[_product]?.toLowerCase()}.',
              style: TextStyle(color: context.colors.muted),
            ),
          ),
        if (productsFor(_product).contains('cigarette')) ...[
          TextField(
            controller: _cigarettes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total batang rokok',
              helperText:
                  'Batang sepanjang hari; termasuk yang belum dicatat sebelumnya.',
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (productsFor(_product).contains('vape')) ...[
          TextField(
            controller: _vape,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Total sesi vape'),
          ),
          const SizedBox(height: 8),
          Text(
            'Satu sesi = satu momen memakai vape, sampai alat disimpan dan '
            'kamu beralih aktivitas. Pakai definisi yang sama setiap hari. '
            'Sesi bukan takaran nikotin'
            '${productsFor(_product).length > 1 ? ' dan tidak disetarakan dengan batang rokok' : ''}.',
            style: TextStyle(color: context.colors.muted),
          ),
          const SizedBox(height: 16),
        ],
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _confirmed,
          title: const Text('Ini total sepanjang hari untuk tanggal tersebut.'),
          onChanged: (value) => setState(() => _confirmed = value ?? false),
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: context.colors.reduction)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _save,
          child: const Text('Simpan total harian'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Pencatatan dan koreksi jumlah tidak memberikan XP. '
          'Catat dengan jujur meskipun hari ini lebih banyak dari rencana.',
        ),
      ],
    );
  }
}
