import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/core/utils/date_label.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
import 'package:youwell/features/activity/data/meal_photo_store.dart';

class ActivityHistoryPage extends StatelessWidget {
  const ActivityHistoryPage({super.key, required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final rows = [
        for (final row in controller.workoutSessions)
          {...row, 'collection': 'workoutSessions'},
        for (final row in controller.mealCheckIns)
          {...row, 'collection': 'mealCheckIns'},
      ]..sort((a, b) => b['time'].toString().compareTo(a['time'].toString()));
      final c = context.colors;
      final weekStart = shiftDayKey(controller.today, -6);
      final week = controller.workoutSessions
          .where((row) => row['day'].toString().compareTo(weekStart) >= 0)
          .toList();
      final weekMeters = week.fold<int>(
        0,
        (sum, row) => sum + ((row['meters'] as num?)?.toInt() ?? 0),
      );
      final weekMinutes =
          week.fold<int>(
            0,
            (sum, row) => sum + ((row['seconds'] as num?)?.toInt() ?? 0),
          ) ~/
          60;
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat aktivitas')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            GameCard(
              color: c.xpSoft,
              borderColor: c.xp.withValues(alpha: .45),
              child: Row(
                children: [
                  Icon(Icons.insights_rounded, color: c.onXp, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Minggu ini kamu bergerak dalam ${week.length} sesi',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '$weekMinutes menit · '
                          '${(weekMeters / 1000).toStringAsFixed(1)} km',
                          style: TextStyle(
                            color: c.onXp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Catatan pribadi. Koreksi tidak mengulang atau mencabut XP.',
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Belum ada catatan. Mulai dari satu aktivitas kecil.',
                ),
              ),
            for (final (index, row) in rows.indexed) ...[
              if (index == 0 || rows[index - 1]['day'] != row['day'])
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 0, 8),
                  child: Text(
                    dayLabel(row['day'].toString(), controller.now),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HistoryTile(
                  row: row,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _ActivityDetailPage(
                        controller: controller,
                        collection: row['collection'].toString(),
                        id: row['id'].toString(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.row, required this.onTap});
  final JsonMap row;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meal = row['collection'] == 'mealCheckIns';
    final run = row['kind'] == 'run';
    final color = meal ? c.reduction : c.body;
    final minutes = ((row['seconds'] as num?)?.toInt() ?? 0) ~/ 60;
    final meters = (row['meters'] as num?)?.toInt() ?? 0;
    final note = row['note']?.toString() ?? '';
    final storedPhoto = row['photoPath'] is String;
    final capturedOnly = row['photoCaptured'] == true && !storedPhoto;
    return GameCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              meal
                  ? Icons.restaurant_rounded
                  : run
                  ? Icons.directions_run_rounded
                  : Icons.directions_walk_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal
                      ? 'Momen makan'
                      : run
                      ? 'Lari'
                      : 'Jalan',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  meal
                      ? (note.isNotEmpty
                            ? note
                            : capturedOnly
                            ? 'Check-in selesai · foto tidak tersedia di perangkat ini'
                            : 'Ketuk untuk lihat foto')
                      : '$minutes menit · '
                            '${meters >= 1000 ? '${(meters / 1000).toStringAsFixed(2)} km' : '$meters m'}'
                            '${row['countsForQuest'] == false ? ' · tidak dihitung' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.muted),
        ],
      ),
    );
  }
}

class _ActivityDetailPage extends StatefulWidget {
  const _ActivityDetailPage({
    required this.controller,
    required this.collection,
    required this.id,
  });
  final WellnessController controller;
  final String collection, id;
  @override
  State<_ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<_ActivityDetailPage> {
  String? _error;
  bool _deleting = false;
  bool get _meal => widget.collection == 'mealCheckIns';
  JsonMap? get _row =>
      (_meal
              ? widget.controller.mealCheckIns
              : widget.controller.workoutSessions)
          .where((row) => row['id'] == widget.id)
          .firstOrNull;
  Future<void> _edit(JsonMap row) async {
    var note = row['note']?.toString() ?? '';
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit catatan pribadi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_meal) ...[
                const Text(
                  'Durasi dan jarak tidak bisa diedit. Hapus sesi jika keliru.',
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                initialValue: note,
                onChanged: (value) => note = value,
                maxLength: 200,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Catatan pribadi'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, note),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (saved == null || !mounted) return;
    final changed = widget.controller.editActivity(
      widget.collection,
      widget.id,
      note: saved,
    );
    setState(() => _error = changed ? null : 'Catatan belum bisa disimpan.');
  }

  Future<void> _delete(JsonMap row) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus catatan ini?'),
        content: Text(
          _meal
              ? row['photoPath'] is String
                    ? 'Catatan dan foto lokal dihapus permanen. XP yang sudah diperoleh tetap tersimpan.'
                    : 'Catatan Meal Snap dihapus permanen. XP yang sudah diperoleh tetap tersimpan.'
              : 'Sesi dihapus permanen dan tidak lagi menjadi bukti evaluasi tangga atau quest penelitian. XP tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      if (_meal && row['photoPath'] is String) {
        await MealPhotoStore.delete(row['photoPath']);
      }
      widget.controller.deleteActivity(widget.collection, widget.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Catatan belum bisa dihapus. Coba lagi.';
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = _row;
    return Scaffold(
      appBar: AppBar(title: Text(_meal ? 'Momen makan' : 'Detail gerak')),
      body: row == null
          ? const Center(child: Text('Catatan sudah dihapus.'))
          : ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Text(
                  dayLabel(row['day'].toString(), widget.controller.now),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (_meal && row['photoPath'] is String)
                  FutureBuilder<Uint8List?>(
                    future: MealPhotoStore.read(row['photoPath']),
                    builder: (context, snapshot) => ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: snapshot.data != null
                          ? Image.memory(snapshot.data!, fit: BoxFit.contain)
                          : SizedBox(
                              height: 180,
                              child: Center(
                                child: Text(
                                  snapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? 'Membuka foto…'
                                      : 'Foto tidak tersedia.',
                                ),
                              ),
                            ),
                    ),
                  ),
                if (_meal &&
                    row['photoCaptured'] == true &&
                    row['photoPath'] is! String)
                  GameCard(
                    color: context.colors.reduction.withValues(alpha: .1),
                    borderColor: context.colors.reduction.withValues(
                      alpha: .35,
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Meal Snap selesai. File foto tidak tersedia di perangkat ini. Yang disinkronkan hanya catatan check-in, bukan file foto.',
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!_meal) ...[
                  Text(
                    '${((row['seconds'] as num?) ?? 0) ~/ 60} menit · ${row['meters'] ?? 0} meter',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (row['countsForQuest'] == false)
                    Text(
                      'Sesi tersimpan, tetapi tidak dihitung untuk quest.',
                      style: TextStyle(color: context.colors.muted),
                    ),
                ],
                const SizedBox(height: 16),
                if (row['note']?.toString().isNotEmpty == true)
                  Text(row['note'].toString()),
                if (row['correctedAt'] != null || row['noteEditedAt'] != null)
                  Text(
                    'Catatan sudah dikoreksi',
                    style: TextStyle(color: context.colors.muted),
                  ),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: context.colors.amber)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _deleting ? null : () => _edit(row),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit catatan'),
                ),
                TextButton.icon(
                  onPressed: _deleting ? null : () => _delete(row),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus catatan'),
                ),
              ],
            ),
    );
  }
}
