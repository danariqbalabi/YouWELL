import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

/// One-time setup per product: usual triggers, activities to try, summary.
/// It is a personal list of choices, never a report that anything was done.
/// "Belum yakin, pilih nanti" skips it so help is never blocked.
class SwapSetupFlow extends StatefulWidget {
  const SwapSetupFlow({
    super.key,
    required this.controller,
    required this.products,
    this.editing = false,
    this.onDone,
  });
  final WellnessController controller;

  /// The products to set up, in order ("keduanya" sets up both).
  final List<String> products;

  /// Opened from "Ubah pemicu & kegiatan": prefilled, no "pilih nanti".
  final bool editing;
  final VoidCallback? onDone;

  @override
  State<SwapSetupFlow> createState() => _SwapSetupFlowState();
}

class _SwapSetupFlowState extends State<SwapSetupFlow> {
  var _productIndex = 0, _step = 0;
  final _triggers = <String>{}, _activities = <String>{};
  final _customTriggers = <String>[], _customActivities = <String>[];

  String get _product => widget.products[_productIndex];
  WellnessController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  void _loadProduct() {
    final saved = c.swapSetup(_product);
    _triggers
      ..clear()
      ..addAll(((saved?['triggers'] as List?) ?? const []).cast<String>());
    _activities
      ..clear()
      ..addAll(((saved?['activities'] as List?) ?? const []).cast<String>());
    _customTriggers
      ..clear()
      ..addAll(
        ((saved?['customTriggers'] as List?) ?? const []).cast<String>(),
      );
    _customActivities
      ..clear()
      ..addAll(
        ((saved?['customActivities'] as List?) ?? const []).cast<String>(),
      );
    _step = 0;
  }

  void _save() {
    c.saveSwapSetup(
      _product,
      triggers: [..._triggers],
      customTriggers: _customTriggers,
      activities: [..._activities],
      customActivities: _customActivities,
    );
    if (_productIndex + 1 < widget.products.length) {
      setState(() {
        _productIndex++;
        _loadProduct();
      });
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Pilihanmu tersimpan.')));
    widget.onDone?.call();
  }

  Future<void> _addCustom(List<String> into, String title) async {
    final text = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: maxCustomSwapText,
          decoration: const InputDecoration(hintText: 'Tulis singkat saja'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, text.text),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    text.dispose();
    final clean = cleanCustom([value ?? '']);
    if (clean.isNotEmpty && !into.contains(clean.single)) {
      setState(() => into.add(clean.single));
    }
  }

  Widget _chips(
    Map<String, String> labels,
    Set<String> picked,
    List<String> custom,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final entry in labels.entries)
        FilterChip(
          label: Text(entry.value),
          selected: picked.contains(entry.key),
          onSelected: (on) => setState(
            () => on ? picked.add(entry.key) : picked.remove(entry.key),
          ),
        ),
      for (final text in custom)
        InputChip(
          label: Text(text),
          selected: true,
          onDeleted: () => setState(() => custom.remove(text)),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final verb = useVerb(_product);
    final both = widget.products.length > 1;
    final header = both
        ? '${nicotineProductLabels[_product]} · '
              '${_productIndex + 1} dari ${widget.products.length}'
        : null;
    final steps = [
      // 1. Usual triggers.
      [
        Text(
          'Biasanya kapan atau karena apa kamu ingin $verb?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text('Boleh pilih beberapa.', style: TextStyle(color: colors.muted)),
        const SizedBox(height: 12),
        _chips(
          {
            for (final key in triggersFor(_product))
              if (key != 'other') key: reductionTriggerLabels[key]!,
          },
          _triggers,
          _customTriggers,
        ),
        TextButton.icon(
          onPressed: () => _addCustom(_customTriggers, 'Pemicu lain'),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Tulis sendiri'),
        ),
      ],
      // 2. Activities to try.
      [
        Text(
          'Kegiatan apa yang mau kamu coba saat keinginan muncul?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Boleh pilih beberapa. Nanti tetap bisa memilih kegiatan lain.',
          style: TextStyle(color: colors.muted),
        ),
        const SizedBox(height: 12),
        _chips(
          {
            for (final key in suggestedSwaps(
              lowImpact: c.profile?['lowImpact'] == true,
              product: _product,
              history: const [],
            ))
              key: swapActivityLabels[key]!,
          },
          _activities,
          _customActivities,
        ),
        TextButton.icon(
          onPressed: () => _addCustom(_customActivities, 'Kegiatan lain'),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Tulis sendiri'),
        ),
      ],
      // 3. Summary.
      [
        Text(
          'Ringkasan pilihanmu',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        GameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saat keinginan biasanya muncul',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                triggerText({
                      'triggers': [..._triggers],
                      'customTriggers': _customTriggers,
                    }) ??
                    'Belum dipilih',
              ),
              const SizedBox(height: 12),
              const Text(
                'Kegiatan yang mau dicoba',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                [
                  ...activityNames({
                    'activities': [..._activities],
                  }),
                  ..._customActivities,
                ].join(', ').ifEmpty('Belum dipilih'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ini daftar pilihanmu, bukan catatan bahwa kegiatannya sudah '
          'dilakukan. Bisa diubah kapan saja.',
          style: TextStyle(color: colors.muted, fontSize: 13),
        ),
      ],
    ];
    final last = _step == steps.length - 1;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          widget.editing ? 'Ubah pemicu & kegiatan' : 'Persiapan singkat',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (header != null) ...[
          const SizedBox(height: 4),
          Text(
            header,
            style: TextStyle(color: colors.accent, fontWeight: FontWeight.w800),
          ),
        ],
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (_step + 1) / steps.length,
          minHeight: 5,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 20),
        ...steps[_step],
        const SizedBox(height: 20),
        // The app theme makes buttons full width, so they share the row.
        Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text('Kembali'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: last ? _save : () => setState(() => _step++),
                child: Text(last ? 'Simpan pilihan saya' : 'Lanjut'),
              ),
            ),
          ],
        ),
        if (!widget.editing) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                c.deferSwapSetup();
                widget.onDone?.call();
              },
              child: const Text('Belum yakin, pilih nanti'),
            ),
          ),
        ],
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
