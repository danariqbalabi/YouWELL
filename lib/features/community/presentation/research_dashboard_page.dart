import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/auth/presentation/account_scope.dart';
import 'package:youwell/features/progress/domain/research_store.dart';

/// Researcher view for admins with MFA: every account's progress by alias,
/// participant codes P1–P10, the engagement criterion, and downloads.
class ResearchDashboardPage extends StatefulWidget {
  const ResearchDashboardPage({super.key, this.now});

  /// Fixed clock for tests; the live dashboard uses the current time.
  final DateTime? now;

  @override
  State<ResearchDashboardPage> createState() => _ResearchDashboardPageState();
}

class _ResearchDashboardPageState extends State<ResearchDashboardPage> {
  ResearchStore? _store;
  List<ParticipantOverview>? _people;
  String? _error;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AccountScope.maybeOf(context)?.researchStore;
    if (store != null && _store == null) {
      _store = store;
      _load();
    }
  }

  Future<void> _load() async {
    final store = _store;
    if (store == null || _loading) return;
    setState(() => _loading = true);
    try {
      final rows = await store.progressOverview();
      if (!mounted) return;
      setState(() {
        _people = [
          for (final row in rows)
            ?ParticipantOverview.fromRow(row, now: widget.now),
        ];
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Data belum bisa dimuat. Periksa koneksi dan migration tahap 5–6.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setCode(ParticipantOverview person, String? code) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _store!.setParticipantCode(person.account, code);
      await _load();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is StateError ? error.message : 'Kode belum tersimpan.',
          ),
        ),
      );
    }
  }

  void _download(String name, String body, String mime) =>
      platform.download(name, utf8.encode(body), mime);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_store == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text('Dashboard peneliti butuh login admin.'),
        ),
      );
    }
    final people = _people;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        children: [
          const Text(
            'Dashboard peneliti',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Progres yang sudah tersinkron. Beri kode P1–P10 pada peserta UAT yang sudah menandatangani persetujuan.',
            style: TextStyle(color: c.muted),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Text(_error!, style: TextStyle(color: c.amber))
          else if (people == null)
            const Center(child: CircularProgressIndicator())
          else
            ..._content(context, people),
        ],
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    List<ParticipantOverview> people,
  ) {
    final c = context.colors;
    final engagement = weekFourEngagement(people);
    final coded = people.where((p) => p.code != null).toList();
    final taken = {for (final p in coded) p.code};
    return [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _Stat(value: '${people.length}', label: 'Akun tersinkron'),
          _Stat(value: '${coded.length}', label: 'Peserta berkode'),
          _Stat(
            value: '${people.where((p) => p.activeLast7 > 0).length}',
            label: 'Aktif 7 hari terakhir',
          ),
          _Stat(
            value: engagement.reached == 0
                ? '–'
                : '${engagement.active}/${engagement.reached}',
            label: 'Peserta aktif minggu ke-4',
            highlight: engagement.reached > 0 && engagement.active >= 6,
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Kriteria proposal: ≥ 6 dari 10 peserta UAT aktif di minggu ke-4.',
        style: TextStyle(color: c.muted, fontSize: 12.5),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: coded.isEmpty
                ? null
                : () => _download(
                    'youwell-ringkasan-p1-p10.csv',
                    toCsv(researchCsvColumns, [
                      for (final p in coded) ...p.researchRows(),
                    ]),
                    'text/csv',
                  ),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Unduh ringkasan P1–P10 (CSV)'),
          ),
          OutlinedButton.icon(
            onPressed: people.isEmpty
                ? null
                : () => _download(
                    'youwell-progres-peserta.csv',
                    toCsv(ParticipantOverview.csvColumns, [
                      for (final p in people) p.toCsvRow(),
                    ]),
                    'text/csv',
                  ),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Unduh progres semua akun (CSV)'),
          ),
          TextButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Muat ulang'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (people.isEmpty)
        Text(
          'Belum ada akun yang tersinkron.',
          style: TextStyle(color: c.muted),
        )
      else
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
            columns: const [
              DataColumn(label: Text('Kode')),
              DataColumn(label: Text('Alias')),
              DataColumn(label: Text('Jalur')),
              DataColumn(label: Text('Hari')),
              DataColumn(label: Text('Level'), numeric: true),
              DataColumn(label: Text('Quest'), numeric: true),
              DataColumn(label: Text('Hari penuh'), numeric: true),
              DataColumn(label: Text('Aktif 7 hr'), numeric: true),
              DataColumn(label: Text('Minggu 1–4')),
              DataColumn(label: Text('Habit Swap'), numeric: true),
              DataColumn(label: Text('Tangga')),
              DataColumn(label: Text('Sinkron')),
              DataColumn(label: Text('Data')),
            ],
            rows: [
              for (final p in people)
                DataRow(
                  cells: [
                    DataCell(
                      DropdownButton<String?>(
                        value: p.code,
                        hint: const Text('–'),
                        underline: const SizedBox.shrink(),
                        onChanged: _loading
                            ? null
                            : (code) => _setCode(p, code),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('–')),
                          for (var i = 1; i <= 10; i++)
                            if (!taken.contains('P$i') || p.code == 'P$i')
                              DropdownMenuItem(
                                value: 'P$i',
                                child: Text('P$i'),
                              ),
                        ],
                      ),
                    ),
                    DataCell(Text(p.alias)),
                    DataCell(Text(p.path)),
                    DataCell(
                      Text(p.complete ? 'Selesai' : '${p.dayNumber}/28'),
                    ),
                    DataCell(Text('${p.level}')),
                    DataCell(Text('${p.questsDone}')),
                    DataCell(Text('${p.fullDays}')),
                    DataCell(Text('${p.activeLast7}/7')),
                    DataCell(_Weeks(p.activeWeeks)),
                    DataCell(Text('${p.habitSwaps}')),
                    DataCell(Text(_ladder(p.ladder))),
                    DataCell(
                      Text(
                        p.updatedAt == null
                            ? '–'
                            : _date(p.updatedAt!.toLocal()),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        tooltip: 'Unduh data ${p.alias} (JSON)',
                        icon: const Icon(Icons.file_download_outlined),
                        onPressed: () => _download(
                          'youwell-${p.alias}.json',
                          const JsonEncoder.withIndent('  ').convert(p.payload),
                          'application/json',
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
    ];
  }
}

String _ladder(Map<String, int> steps) => [
  for (final (key, label) in const [
    ('Body', 'G'),
    ('Energy', 'I'),
    ('Lifestyle', 'H'),
    ('Food', 'M'),
    ('Reduction', 'J'),
  ])
    if (steps[key] case final step?) '$label$step',
].join(' ');

String _date(DateTime time) =>
    '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.highlight = false,
  });
  final String value, label;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Container(
    width: 200,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: highlight ? context.colors.selected : context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: highlight ? context.colors.primary : context.colors.border,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: context.colors.accent,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: TextStyle(color: context.colors.muted)),
      ],
    ),
  );
}

/// Four dots: filled = active that week, hollow = not active, dash = later.
class _Weeks extends StatelessWidget {
  const _Weeks(this.weeks);
  final List<bool?> weeks;
  @override
  Widget build(BuildContext context) => Semantics(
    label: [
      for (final (i, active) in weeks.indexed)
        'minggu ${i + 1} ${active == null
            ? 'belum'
            : active
            ? 'aktif'
            : 'tidak aktif'}',
    ].join(', '),
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final active in weeks)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              active == null
                  ? Icons.remove_rounded
                  : active
                  ? Icons.circle
                  : Icons.circle_outlined,
              size: 14,
              color: active == true
                  ? context.colors.success
                  : context.colors.muted,
            ),
          ),
      ],
    ),
  );
}
