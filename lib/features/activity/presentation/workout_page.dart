import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

/// Walk/run log that keeps counting with the screen locked or the app in the
/// background (Android foreground service, iOS background location). Only
/// meters and seconds are kept; coordinates never enter the local snapshot.
/// An unfinished session is kept as a device-only draft until it is saved
/// or discarded, so closing the app does not lose it.
class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> with WidgetsBindingObserver {
  final _watch = _WallStopwatch();
  Timer? _ticker;
  StreamSubscription<Position>? _positions;
  Position? _lastPosition;
  String _kind = 'walk';
  String? _message;
  double _meters = 0;
  bool _starting = false;
  bool _gpsEnabled = false;
  bool _openSettings = false;
  DateTime? _resumeSince;
  late String _sessionDay = widget.controller.today;

  /// Web app: the session counts time only, with no location at all.
  bool get _timed => widget.controller.workoutUsesTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreDraft();
  }

  /// A session the OS closed (app swiped away, iOS evicting the web app) is
  /// restored. If it was running recently on the same day, the wall-clock
  /// time keeps counting as it would have with the screen locked; otherwise
  /// only the time up to the last saved heartbeat is kept, paused.
  void _restoreDraft() {
    final draft = widget.controller.workoutDraft;
    if (draft == null) return;
    if (draft['kind'] == 'run') _kind = 'run';
    _meters = (draft['meters'] as num?)?.toDouble() ?? 0;
    final banked = Duration(
      seconds: (draft['bankedSeconds'] as num?)?.toInt() ?? 0,
    );
    final since = DateTime.tryParse(draft['since']?.toString() ?? '');
    final heartbeat =
        DateTime.tryParse(draft['heartbeat']?.toString() ?? '') ?? since;
    final now = DateTime.now();
    final day = draft['day']?.toString() ?? widget.controller.today;
    _sessionDay = day;
    if (since != null &&
        heartbeat != null &&
        day == widget.controller.today &&
        !now.isBefore(since) &&
        now.difference(heartbeat) <= _resumeWindow) {
      _watch.restore(banked);
      _resumeSince = since;
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    } else {
      final counted = since == null || heartbeat == null
          ? Duration.zero
          : heartbeat.difference(since);
      _watch.restore(banked + (counted.isNegative ? Duration.zero : counted));
    }
    _message =
        'Sesi sebelumnya dipulihkan. Lanjutkan, atau tekan Selesai & simpan.';
  }

  void _saveDraft() {
    if (_watch.elapsed.inSeconds < 1 && !_watch.isRunning) return;
    widget.controller.saveWorkoutDraft({
      'kind': _kind,
      'day': _sessionDay,
      'bankedSeconds': _watch.banked.inSeconds,
      'since': _watch.since?.toIso8601String(),
      'heartbeat': DateTime.now().toIso8601String(),
      // Only the total distance: coordinates never enter the snapshot.
      'meters': _meters.round(),
    });
  }

  /// The session keeps running in the background; on return, refresh the
  /// time and distance at once. Leaving the app saves a heartbeat first.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    } else if (_watch.isRunning || _watch.elapsed.inSeconds > 0) {
      _saveDraft();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _positions?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_watch.isRunning || _starting) return;
    // A new session belongs to the day Mulai is pressed, even past midnight.
    if (_watch.elapsed == Duration.zero && _resumeSince == null) {
      _sessionDay = widget.controller.today;
    }
    setState(() {
      _starting = true;
      _message = null;
    });
    var enabled = false;
    var serviceOff = false, deniedForever = false;
    try {
      // Timed mode (web app) never asks for location.
      if (!_timed) {
        serviceOff = !await Geolocator.isLocationServiceEnabled();
        if (!serviceOff) {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          deniedForever = permission == LocationPermission.deniedForever;
          enabled =
              permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse;
        }
      }
    } catch (_) {
      enabled = false;
    }
    if (!mounted) return;
    _gpsEnabled = enabled;
    // The browser has no settings page to open; a phone does.
    _openSettings = !kIsWeb && (serviceOff || deniedForever);
    _lastPosition = null;
    if (enabled) {
      _positions =
          Geolocator.getPositionStream(
            locationSettings: _backgroundSettings(),
          ).listen(
            (position) {
              if (!mounted || !_watch.isRunning) return;
              // A coarse fix must not become the anchor either: the next good
              // fix would add the whole error as distance.
              if (position.accuracy > 40) return;
              final anchor = _lastPosition;
              if (anchor == null) {
                _lastPosition = position;
                return;
              }
              final delta = Geolocator.distanceBetween(
                anchor.latitude,
                anchor.longitude,
                position.latitude,
                position.longitude,
              );
              // Fixes inside the GPS error circle are noise: sitting still
              // must not add distance, so keep the anchor until we move out.
              if (delta < max(position.accuracy, 10)) return;
              final seconds =
                  position.timestamp
                      .difference(anchor.timestamp)
                      .inMilliseconds /
                  1000;
              _lastPosition = position;
              // Jumps faster than 7 m/s (~25 km/h) are a vehicle or GPS glitch.
              if (seconds <= 0 || delta / seconds > 7) return;
              setState(() => _meters += delta);
            },
            onError: (_) {
              if (mounted) {
                setState(() {
                  _gpsEnabled = false;
                  _message =
                      'GPS terputus. Jarak berhenti dihitung sampai sinyal kembali.';
                });
              }
            },
          );
    }
    _watch.start(_resumeSince);
    _resumeSince = null;
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      // A heartbeat every 15 s bounds what a killed app can lose.
      if (_watch.isRunning && timer.tick % 15 == 0) _saveDraft();
    });
    _saveDraft();
    setState(() {
      _starting = false;
      if (!enabled && !_timed) {
        _message = deniedForever
            ? 'Izin lokasi ditolak. Buka pengaturan untuk mengizinkan lokasi '
                  'saat aplikasi dipakai. Rute tidak disimpan.'
            : 'Lokasi belum aktif. Misi jalan/lari dihitung dari jarak GPS, '
                  'jadi nyalakan lokasi dulu. Rute tidak disimpan.';
      } else if (enabled) {
        _message = null;
      }
    });
  }

  void _pause() {
    _watch.stop();
    _positions?.cancel();
    _positions = null;
    _lastPosition = null;
    _saveDraft();
    setState(() {});
  }

  Future<void> _openLocationSettings() async {
    var opened = false;
    try {
      opened = await Geolocator.isLocationServiceEnabled()
          ? await Geolocator.openAppSettings()
          : await Geolocator.openLocationSettings();
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      setState(() => _message = 'Buka Pengaturan HP > Lokasi secara manual.');
    }
  }

  /// Back while a session exists: save it, discard it, or keep going.
  Future<void> _confirmLeave() async {
    if (_watch.isRunning) _pause();
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Simpan sesi ini?'),
        content: const Text(
          'Sesi yang belum disimpan tidak dihitung untuk misi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: const Text('Buang'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Lanjutkan sesi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'save') {
      _finish();
    } else if (choice == 'discard') {
      widget.controller.saveWorkoutDraft(null);
      Navigator.of(context).pop();
    }
  }

  void _finish() {
    _pause();
    if (_watch.elapsed.inSeconds < 1) return;
    final result = widget.controller.recordWorkout(
      kind: _kind,
      seconds: _watch.elapsed.inSeconds,
      meters: _meters.round(),
      startedOn: _sessionDay,
    );
    widget.controller.saveWorkoutDraft(null);
    final message = result.tooFast
        ? 'Sesi tercatat, tapi kecepatan rata-rata di atas '
              '${maxWalkRunKmPerHour.round()} km/jam, jadi tidak dihitung '
              'untuk quest.'
        : result.completed.isNotEmpty
        ? 'Quest selesai: ${result.completed.join(', ')}.'
        : result.partial.isNotEmpty
        ? 'Tercapai sebagian: ${result.partial.join(', ')}. Tetap tercatat.'
        : _meters < 1 && !_timed
        ? 'Sesi tercatat, tapi jarak belum terhitung. Misi jalan/lari butuh '
              'lokasi aktif.'
        : 'Sesi tercatat.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop();
  }

  /// The open walk/run quest this session counts toward, with live progress.
  Widget? _questTarget(BuildContext context) {
    final task = widget.controller.quests
        .where(
          (task) =>
              task['status'] != 'completed' &&
              (task['activityKind'] == 'walk' ||
                  task['activityKind'] == 'run' && _kind == 'run'),
        )
        .firstOrNull;
    if (task == null) return null;
    final c = context.colors;
    final targetMeters = (task['targetMeters'] as num?)?.toInt();
    final targetMinutes = (task['durationMinutes'] as num?)?.toInt() ?? 1;
    final byDistance = targetMeters != null;
    final progress = byDistance
        ? _meters / targetMeters
        : _watch.elapsed.inSeconds / (targetMinutes * 60);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GameCard(
        color: c.xpSoft,
        borderColor: c.xp.withValues(alpha: .5),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_rounded, color: c.onXp),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Misi: ${task['title']}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                XpPill((task['xp'] as num?)?.toInt() ?? 0),
              ],
            ),
            const SizedBox(height: 10),
            XpBar(value: progress),
            const SizedBox(height: 6),
            Text(
              progress >= 1
                  ? 'Target tercapai! Tekan Selesai & simpan.'
                  : byDistance
                  ? '${_meters.round()} / $targetMeters m'
                  : '${_watch.elapsed.inMinutes} / $targetMinutes menit',
              style: TextStyle(color: c.onXp, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _watch.elapsed;
    final clock =
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    return PopScope(
      canPop: !_starting && !_watch.isRunning && elapsed.inSeconds < 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_starting) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Jalan & Lari')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Text(
              'Gerak sesuai ritmemu',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              _timed
                  ? 'Di aplikasi web, misi jalan/lari dihitung dari lama sesi. '
                        'Setelah mulai, boleh kunci layar; waktunya tetap '
                        'berjalan. Berhenti jika pusing atau nyeri.'
                  : 'Setelah mulai, boleh kunci layar atau buka aplikasi lain; '
                        'jarak tetap dihitung. Lokasi hanya dipakai selama sesi '
                        'dan rute tidak disimpan. Berhenti jika pusing atau nyeri.',
              style: TextStyle(color: context.colors.muted, height: 1.4),
            ),
            const SizedBox(height: 24),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'walk',
                  icon: Icon(Icons.directions_walk),
                  label: Text('Jalan'),
                ),
                ButtonSegment(
                  value: 'run',
                  icon: Icon(Icons.directions_run),
                  label: Text('Lari'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: _watch.elapsed.inSeconds > 0
                  ? null
                  : (value) => setState(() => _kind = value.first),
            ),
            ?_questTarget(context),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                children: [
                  Icon(
                    _kind == 'walk'
                        ? Icons.directions_walk_rounded
                        : Icons.directions_run_rounded,
                    size: 68,
                    color: context.colors.accent,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    clock,
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'waktu aktif',
                    style: TextStyle(color: context.colors.muted),
                  ),
                  if (!_timed) ...[
                    const SizedBox(height: 22),
                    Text(
                      '${(_meters / 1000).toStringAsFixed(2)} km',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: context.colors.accent,
                      ),
                    ),
                    Text(
                      _gpsEnabled
                          ? 'jarak GPS perkiraan'
                          : 'jarak belum tersedia',
                      style: TextStyle(color: context.colors.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(_message!, style: TextStyle(color: context.colors.amber)),
            ],
            if (_openSettings && !_gpsEnabled) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openLocationSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Buka pengaturan lokasi'),
                ),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _starting
                  ? null
                  : _watch.isRunning
                  ? _pause
                  : _start,
              icon: Icon(
                _watch.isRunning
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                _starting
                    ? 'Menyiapkan...'
                    : _watch.isRunning
                    ? 'Tahan'
                    : elapsed.inSeconds > 0
                    ? 'Lanjutkan'
                    : 'Mulai',
              ),
            ),
            if (elapsed.inSeconds > 0) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Selesai & simpan'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Location updates that continue while the phone is locked or another app
/// is open. Android shows an ongoing notification (required for a foreground
/// service); iOS shows its blue location indicator.
LocationSettings _backgroundSettings() {
  const accuracy = LocationAccuracy.high;
  const distanceFilter = 10;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => AndroidSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'YouWELL sedang menghitung jarak',
        notificationText: 'Sesi jalan/lari aktif. Rute tidak disimpan.',
        enableWakeLock: true,
        setOngoing: true,
      ),
    ),
    TargetPlatform.iOS => AppleSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      activityType: ActivityType.fitness,
      pauseLocationUpdatesAutomatically: false,
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
    ),
    _ => const LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    ),
  };
}

/// Like [Stopwatch], but on the wall clock, so time spent with the screen
/// locked (when the device may sleep between GPS fixes) is still counted.
class _WallStopwatch {
  Duration _banked = Duration.zero;
  DateTime? _since;

  bool get isRunning => _since != null;
  Duration get banked => _banked;
  DateTime? get since => _since;

  Duration get elapsed {
    final since = _since;
    return since == null ? _banked : _banked + DateTime.now().difference(since);
  }

  /// [from] resumes a restored running session at its original start.
  void start([DateTime? from]) => _since ??= from ?? DateTime.now();

  void restore(Duration banked) {
    _banked = banked;
    _since = null;
  }

  void stop() {
    _banked = elapsed;
    _since = null;
  }
}

/// How long after its last heartbeat a closed running session still resumes.
const _resumeWindow = Duration(hours: 3);
