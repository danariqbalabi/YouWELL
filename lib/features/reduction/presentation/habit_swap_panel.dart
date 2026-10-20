import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/features/reduction/presentation/swap_setup_flow.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

/// Habit Swap when a craving starts: (product) → activities → "Saya akan
/// coba" → "Saya sudah mencoba" → outcome now or later. No countdown. An
/// open moment survives closing the page and is shown again on return.
class HabitSwapPanel extends StatefulWidget {
  const HabitSwapPanel({super.key, required this.controller, this.product});
  final WellnessController controller;

  /// Preselected from "Saya ingin merokok/vape" on Home.
  final String? product;

  @override
  State<HabitSwapPanel> createState() => _HabitSwapPanelState();
}

class _HabitSwapPanelState extends State<HabitSwapPanel> {
  String? _product, _outcomeFor;
  bool _editing = false, _showAll = false;
  final _activities = <String>{};
  final _custom = <String>[];

  WellnessController get c => widget.controller;
  List<String> get _products => productsFor(c.nicotineProduct);

  @override
  void initState() {
    super.initState();
    _product = _products.length == 1
        ? _products.single
        : _products.contains(widget.product)
        ? widget.product
        : null;
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _start() {
    final active = c.activeSwapMoment;
    if (active != null) return;
    final started = c.startSwapMoment(
      product: _product!,
      activities: [..._activities],
      customActivities: _custom,
    );
    if (!started) return _snack('Pilih minimal satu kegiatan dulu.');
    setState(() {
      _activities.clear();
      _custom.clear();
      _showAll = false;
    });
  }

  Future<void> _addCustom() async {
    final text = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tulis kegiatan sendiri'),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: maxCustomSwapText,
          decoration: const InputDecoration(hintText: 'Misalnya: cuci muka'),
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
    if (clean.isNotEmpty && !_custom.contains(clean.single)) {
      setState(() => _custom.add(clean.single));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(22),
        child: Text(
          'Pilih dulu yang kamu gunakan: rokok, vape, atau keduanya.',
        ),
      );
    }
    final needing = c.productsNeedingSetup;
    if (_editing || needing.isNotEmpty) {
      return SwapSetupFlow(
        key: ValueKey('setup-$_editing-${needing.join()}'),
        controller: c,
        products: _editing ? _products : needing,
        editing: _editing,
        onDone: () => setState(() => _editing = false),
      );
    }
    if (_outcomeFor case final id?) {
      final row = c.habitSwaps.where((row) => row['id'] == id).firstOrNull;
      if (row != null) {
        return _OutcomeView(
          controller: c,
          row: row,
          onDone: (message) {
            setState(() => _outcomeFor = null);
            if (message != null) _snack(message);
          },
        );
      }
    }
    if (c.activeSwapMoment case final moment?) {
      return _ActiveMomentView(
        controller: c,
        moment: moment,
        onTried: (id) => setState(() => _outcomeFor = id),
        onLater: () {
          _snack('Momen disimpan. Buka Habit Swap lagi saat siap.');
          Navigator.of(context).maybePop();
        },
        onCancel: () => setState(() {}),
      );
    }
    return _startView(context);
  }

  Widget _startView(BuildContext context) {
    final colors = context.colors;
    final pending = c.swapsAwaitingOutcome;
    final product = _product;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        for (final row in pending.reversed.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GameCard(
              borderColor: colors.reduction.withValues(alpha: .4),
              child: Row(
                children: [
                  Icon(Icons.pending_actions_rounded, color: colors.reduction),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hasil momen ${_timeOf(row)} belum diisi',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _outcomeFor = row['id'].toString()),
                    child: const Text('Isi hasil'),
                  ),
                ],
              ),
            ),
          ),
        if (product == null) ...[
          Text(
            'Sekarang ingin merokok atau vape?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          for (final option in _products)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.tonal(
                onPressed: () => setState(() => _product = option),
                child: Text(cravingLabel(option)),
              ),
            ),
        ] else
          ..._activityPicker(context, product),
        const SizedBox(height: 24),
        _TodaySummary(controller: c),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => setState(() => _editing = true),
          icon: const Icon(Icons.tune_rounded),
          label: Text(
            _products.any((p) => c.swapSetup(p) == null)
                ? 'Siapkan pemicu & kegiatan'
                : 'Ubah pemicu & kegiatan',
          ),
        ),
      ],
    );
  }

  List<Widget> _activityPicker(BuildContext context, String product) {
    final colors = context.colors;
    final setup = c.swapSetup(product);
    final mine = ((setup?['activities'] as List?) ?? const []).cast<String>();
    final myCustom = ((setup?['customActivities'] as List?) ?? const [])
        .cast<String>();
    final others = suggestedSwaps(
      lowImpact: c.profile?['lowImpact'] == true,
      product: product,
      history: c.habitSwaps.where((row) {
        final from = shiftDayKey(c.today, -6);
        return row['day'].toString().compareTo(from) >= 0;
      }).toList(),
    ).where((key) => !mine.contains(key)).toList();
    // Without personal picks, the suggestions are the starting list.
    final showOthers = _showAll || (mine.isEmpty && myCustom.isEmpty);
    FilterChip chip(String label, bool selected, ValueChanged<bool> onTap) =>
        FilterChip(label: Text(label), selected: selected, onSelected: onTap);
    return [
      if (_products.length > 1)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _product = null;
              _activities.clear();
            }),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text('${cravingLabel(product)} · ganti'),
          ),
        ),
      Text(
        'Coba lakukan satu kegiatan dulu',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 4),
      Text(
        'Boleh pilih lebih dari satu. Tidak ada hitung mundur.',
        style: TextStyle(color: colors.muted),
      ),
      const SizedBox(height: 14),
      if (mine.isNotEmpty || myCustom.isNotEmpty) ...[
        Text('Pilihanmu', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final key in mine)
              chip(
                swapActivityLabels[key]!,
                _activities.contains(key),
                (on) => setState(
                  () => on ? _activities.add(key) : _activities.remove(key),
                ),
              ),
            for (final text in myCustom)
              chip(
                text,
                _custom.contains(text),
                (on) => setState(
                  () => on ? _custom.add(text) : _custom.remove(text),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      if (showOthers)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final key in others)
              chip(
                swapActivityLabels[key]!,
                _activities.contains(key),
                (on) => setState(
                  () => on ? _activities.add(key) : _activities.remove(key),
                ),
              ),
          ],
        )
      else
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _showAll = true),
            child: const Text('Lihat kegiatan lain'),
          ),
        ),
      if (_custom.any((text) => !myCustom.contains(text)))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final text in _custom.where((t) => !myCustom.contains(t)))
                InputChip(
                  label: Text(text),
                  selected: true,
                  onDeleted: () => setState(() => _custom.remove(text)),
                ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _addCustom,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Tulis kegiatan sendiri'),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _activities.isEmpty && _custom.isEmpty ? null : _start,
        child: const Text('Saya akan coba'),
      ),
    ];
  }
}

String _timeOf(Map row) {
  final time = DateTime.tryParse(
    (row['startedAt'] ?? row['time'] ?? '').toString(),
  );
  if (time == null) return row['day'].toString();
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  return '${row['day']} $hh.$mm';
}

/// The open moment: what was picked, then "Saya sudah mencoba".
class _ActiveMomentView extends StatefulWidget {
  const _ActiveMomentView({
    required this.controller,
    required this.moment,
    required this.onTried,
    required this.onLater,
    required this.onCancel,
  });
  final WellnessController controller;
  final Map<String, dynamic> moment;
  final ValueChanged<String> onTried;
  final VoidCallback onLater, onCancel;

  @override
  State<_ActiveMomentView> createState() => _ActiveMomentViewState();
}

class _ActiveMomentViewState extends State<_ActiveMomentView> {
  final _triggers = <String>{};
  final _customTriggers = <String>{};

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan momen ini?'),
        content: const Text(
          'Pakai ini jika momen dimulai tidak sengaja. Tidak ada yang dicatat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Batalkan momen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    widget.controller.cancelSwapMoment();
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = widget.controller;
    final product = widget.moment['product'].toString();
    final setup = c.swapSetup(product);
    final mine = ((setup?['triggers'] as List?) ?? const []).cast<String>();
    final myCustom = ((setup?['customTriggers'] as List?) ?? const [])
        .cast<String>();
    final triggerChoices = [
      ...mine,
      ...triggersFor(product).where((key) => !mine.contains(key)),
    ];
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          'Momen sedang berjalan',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          '${cravingLabel(product)} · mulai ${_timeOf({'day': c.today, ...widget.moment})}',
          style: TextStyle(color: colors.muted),
        ),
        const SizedBox(height: 16),
        GameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kegiatan yang mau kamu coba',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              for (final name in activityNames(widget.moment))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: colors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Pemicunya tadi (opsional)'),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in triggerChoices)
                  FilterChip(
                    label: Text(reductionTriggerLabels[key]!),
                    selected: _triggers.contains(key),
                    onSelected: (on) => setState(
                      () => on ? _triggers.add(key) : _triggers.remove(key),
                    ),
                  ),
                for (final text in myCustom)
                  FilterChip(
                    label: Text(text),
                    selected: _customTriggers.contains(text),
                    onSelected: (on) => setState(
                      () => on
                          ? _customTriggers.add(text)
                          : _customTriggers.remove(text),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            final id = c.reportSwapTried(
              triggers: [..._triggers],
              customTriggers: [..._customTriggers],
            );
            if (id != null) widget.onTried(id);
          },
          icon: const Icon(Icons.check_rounded),
          label: const Text('Saya sudah mencoba'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: widget.onLater,
          child: const Text('Cek hasil nanti'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: _cancel, child: const Text('Batalkan momen ini')),
      ],
    );
  }
}

/// "Setelah mencoba, apa yang terjadi?" in the words of the moment's product.
class _OutcomeView extends StatefulWidget {
  const _OutcomeView({
    required this.controller,
    required this.row,
    required this.onDone,
  });
  final WellnessController controller;
  final Map<String, dynamic> row;

  /// Called with a message to show, or null.
  final ValueChanged<String?> onDone;

  @override
  State<_OutcomeView> createState() => _OutcomeViewState();
}

class _OutcomeViewState extends State<_OutcomeView> {
  String? _outcome, _used;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final product = widget.row['product'].toString();
    final both = productsFor(c.nicotineProduct).length > 1;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          'Setelah mencoba, apa yang terjadi?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Kegiatan yang sudah kamu coba tetap tercatat, apa pun hasilnya.',
          style: TextStyle(color: context.colors.muted),
        ),
        const SizedBox(height: 16),
        for (final option in const ['skipped', 'used', 'later'])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ChoiceChip(
              label: Text(outcomeLabel(option, product)),
              selected: _outcome == option,
              onSelected: (_) => setState(() {
                _outcome = option;
                _used = option == 'used' ? product : null;
              }),
            ),
          ),
        if (_outcome == 'used' && both) ...[
          const SizedBox(height: 8),
          const Text('Yang akhirnya dipakai'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final kind in const ['cigarette', 'vape'])
                ChoiceChip(
                  label: Text(nicotineProductLabels[kind]!),
                  selected: _used == kind,
                  onSelected: (_) => setState(() => _used = kind),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _outcome == null
              ? null
              : () {
                  if (_outcome == 'later') {
                    return widget.onDone(
                      'Hasilnya bisa diisi nanti dari Habit Swap.',
                    );
                  }
                  c.recordSwapOutcome(
                    widget.row['id'].toString(),
                    _outcome!,
                    usedProduct: _outcome == 'used' ? _used : null,
                  );
                  widget.onDone(
                    _outcome == 'skipped'
                        ? 'Tercatat. Momen ini terlewati.'
                        : 'Tercatat. Mencoba tetap berarti, terima kasih '
                              'sudah jujur.',
                  );
                },
          child: const Text('Simpan hasil'),
        ),
      ],
    );
  }
}

/// Tries today and the day's confirmed total, kept as two separate facts.
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final tries = c.swapAttemptsToday.length;
    final free = c.dayWithoutUse(c.today);
    return Text(
      '$tries kali mencoba kegiatan pengganti hari ini.\n${switch (free) {
        null => 'Total hari ini belum dikonfirmasi.',
        true => 'Total hari ini: 0, sudah dikonfirmasi.',
        false => 'Total hari ini sudah dicatat.',
      }}',
      style: TextStyle(color: context.colors.muted, height: 1.5),
    );
  }
}
