import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

/// Listens once for rewards from every mobile route, including activity pages.
/// The queue is transient; earned rewards themselves are persisted by the controller.
class MobileRewardHost extends StatefulWidget {
  const MobileRewardHost({
    super.key,
    required this.controller,
    required this.child,
    required this.target,
  });
  final WellnessController controller;
  final Widget child;
  final GlobalKey target;
  @override
  State<MobileRewardHost> createState() => _MobileRewardHostState();
}

class _MobileRewardHostState extends State<MobileRewardHost> {
  OverlayEntry? _entry;
  Timer? _timer;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_schedule);
  }

  bool _celebrating = false;

  void _schedule() {
    if (_entry != null || _celebrating || _scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _showNext();
    });
  }

  void _showNext() {
    if (_entry != null || _celebrating || !mounted) return;
    final moment = widget.controller.takeRewardMoment();
    if (moment == null) return;
    if (moment.dayComplete) {
      _celebrate(moment);
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final box = widget.target.currentContext?.findRenderObject();
    final overlayBox = overlay.context.findRenderObject();
    Offset? destination;
    if (box is RenderBox &&
        box.attached &&
        overlayBox is RenderBox &&
        ModalRoute.of(context)?.isCurrent == true) {
      destination = box.localToGlobal(
        box.size.center(Offset.zero),
        ancestor: overlayBox,
      );
    }
    if (widget.controller.haptics && moment.xp > 0) {
      unawaited(HapticFeedback.lightImpact().catchError((_) {}));
    }
    final reduce =
        widget.controller.reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    _entry = OverlayEntry(
      builder: (_) => InheritedTheme.captureAll(
        context,
        _RewardOverlay(
          moment: moment,
          destination: destination,
          reduceMotion: reduce,
          onClose: _close,
        ),
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(
      Duration(seconds: moment.dayComplete || moment.evolved ? 5 : 3),
      _close,
    );
  }

  /// Full-screen "Kerja bagus!" for finishing every quest of the day.
  Future<void> _celebrate(RewardMoment moment) async {
    _celebrating = true;
    if (widget.controller.haptics) {
      unawaited(HapticFeedback.mediumImpact().catchError((_) {}));
    }
    final reduce =
        widget.controller.reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration(milliseconds: reduce ? 0 : 250),
      pageBuilder: (_, _, _) =>
          _FullDayCelebration(moment: moment, reduceMotion: reduce),
    );
    _celebrating = false;
    if (mounted) _schedule();
  }

  void _close() {
    _timer?.cancel();
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    if (mounted) {
      _schedule();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_schedule);
    _timer?.cancel();
    _entry?.remove();
    _entry?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _RewardOverlay extends StatelessWidget {
  const _RewardOverlay({
    required this.moment,
    required this.destination,
    required this.reduceMotion,
    required this.onClose,
  });
  final RewardMoment moment;
  final Offset? destination;
  final bool reduceMotion;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final target = destination ?? Offset(size.width / 2, 160);
    final c = context.colors;
    final big = moment.dayComplete || moment.evolved;
    final title = moment.dayComplete
        ? 'Hari Penuh!'
        : moment.evolved
        ? 'Temanmu tumbuh!'
        : moment.ladder ??
              (moment.xp > 0 ? 'Langkah kecil, berarti.' : 'Pencapaian baru!');
    final details = [
      if (moment.dayComplete) 'Semua quest selesai · bonus 20 XP',
      if (moment.evolved) 'Tahap pertumbuhan baru terbuka',
      ...moment.unlocks.map((name) => '$name terbuka'),
      ...moment.badges,
    ];
    return Stack(
      children: [
        if (!reduceMotion && moment.xp > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1600),
                curve: Curves.easeInOut,
                builder: (context, value, _) => Stack(
                  children: [
                    Positioned(
                      left: target.dx - 56,
                      top: target.dy + 90 * (1 - value),
                      child: Opacity(
                        opacity: (1 - value).clamp(0, 1),
                        child: Material(
                          type: MaterialType.transparency,
                          child: XpPill(moment.xp, large: true),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (big && !reduceMotion)
          const Positioned.fill(child: IgnorePointer(child: _Confetti())),
        Positioned(
          top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
          left: 16,
          right: 16,
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: big ? c.xpSoft : c.card,
              elevation: 3,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: c.xp, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.xp,
                      ),
                      child: Icon(
                        moment.dayComplete
                            ? Icons.emoji_events_rounded
                            : moment.evolved
                            ? Icons.spa_rounded
                            : moment.ladder != null
                            ? Icons.stairs_rounded
                            : moment.badges.isNotEmpty
                            ? Icons.workspace_premium_rounded
                            : Icons.bolt_rounded,
                        color: const Color(0xff3b1a02),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (moment.xp > 0) ...[
                            const SizedBox(height: 4),
                            XpPill(moment.xp),
                          ],
                          if (details.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                details.join(' · '),
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup perayaan',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Short burst of falling confetti for big moments (Hari Penuh, evolution).
class _Confetti extends StatelessWidget {
  const _Confetti();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final colors = [c.xp, c.primary, c.success, c.energy, c.lifestyle];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) =>
          CustomPaint(painter: _ConfettiPainter(value, colors)),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.colors);
  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 46; i++) {
      final x = random.nextDouble() * size.width;
      final drift = (random.nextDouble() - .5) * 80;
      final fall = size.height * (.15 + .7 * random.nextDouble());
      final y = -20 + fall * t;
      final spin = random.nextDouble() * math.pi * 2 + t * 8;
      paint.color = colors[i % colors.length].withValues(
        alpha: (1 - t * .8).clamp(0, 1),
      );
      canvas.save();
      canvas.translate(x + drift * t, y);
      canvas.rotate(spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4, -7, 8, 14),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _FullDayCelebration extends StatefulWidget {
  const _FullDayCelebration({required this.moment, required this.reduceMotion});
  final RewardMoment moment;
  final bool reduceMotion;

  @override
  State<_FullDayCelebration> createState() => _FullDayCelebrationState();
}

class _FullDayCelebrationState extends State<_FullDayCelebration>
    with TickerProviderStateMixin {
  // The ribbons draw in once, then keep a slow wave and a gliding sheen.
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: widget.reduceMotion ? 1 : 0,
  );
  late final _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) {
      _intro.forward();
      _flow.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final moment = widget.moment;
    const ink = Color(0xff0d1417);
    return Material(
      color: ink,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _SwooshPainter(
                  c.primary,
                  c.xp,
                  intro: _intro,
                  flow: _flow,
                  animated: !widget.reduceMotion,
                ),
              ),
            ),
          ),
          if (!widget.reduceMotion)
            const Positioned.fill(child: IgnorePointer(child: _Confetti())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  Icon(Icons.emoji_events_rounded, color: c.xp, size: 72),
                  const SizedBox(height: 12),
                  const Text(
                    'Kerja bagus!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Semua misi hari ini selesai. Hari Penuh!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xffd7e3e8),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  XpPill(moment.xp, large: true),
                  for (final line in [
                    if (moment.evolved) 'Temanmu tumbuh ke tahap baru',
                    ...moment.unlocks.map((name) => '$name terbuka'),
                    ...moment.badges.map((name) => 'Lencana: $name'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const Spacer(),
                  ChunkyButton(
                    label: 'Lanjut',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two bold ribbons behind the celebration text. When [animated], they draw
/// in along their length, then sway gently while a soft sheen glides along.
class _SwooshPainter extends CustomPainter {
  _SwooshPainter(
    this.top,
    this.bottom, {
    required this.intro,
    required this.flow,
    required this.animated,
  }) : super(repaint: Listenable.merge([intro, flow]));
  final Color top, bottom;
  final Animation<double> intro, flow;
  final bool animated;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final phase = flow.value * math.pi * 2;
    // A loop of whole sine periods, so the wave never jumps on repeat.
    double sway(double shift) => animated ? math.sin(phase + shift) : 0;
    final width = w * .16;
    final topPath = Path()
      ..moveTo(-w * .2, h * (.32 + .015 * sway(0)))
      ..cubicTo(
        w * .3,
        h * (.12 + .035 * sway(1.2)),
        w * .75,
        h * (.2 - .035 * sway(2.1)),
        w * 1.15,
        -h * .05,
      );
    final bottomPath = Path()
      ..moveTo(-w * .2, h * (.74 - .015 * sway(.6)))
      ..cubicTo(
        w * .25,
        h * (.95 - .03 * sway(1.8)),
        w * .7,
        h * (.9 + .03 * sway(2.7)),
        w * 1.2,
        h * .7,
      );
    final reveal = Curves.easeOutCubic.transform(intro.value);
    // The bottom ribbon follows the top one a little later.
    final revealBottom = Curves.easeOutCubic.transform(
      ((intro.value - .2) / .8).clamp(0.0, 1.0),
    );
    _ribbon(canvas, topPath, top, width, reveal, flow.value);
    _ribbon(canvas, bottomPath, bottom, width, revealBottom, flow.value + .5);
  }

  void _ribbon(
    Canvas canvas,
    Path path,
    Color color,
    double width,
    double reveal,
    double sheenAt,
  ) {
    if (reveal <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = color;
    for (final metric in path.computeMetrics()) {
      final shown = metric.length * reveal;
      canvas.drawPath(metric.extractPath(0, shown), paint);
      if (!animated || reveal < 1) continue;
      // A thin, faint highlight travelling along the ribbon's centre.
      final start = (sheenAt % 1) * metric.length * 1.3 - metric.length * .15;
      final sheen = metric.extractPath(
        start.clamp(0, metric.length),
        (start + metric.length * .18).clamp(0, metric.length),
      );
      canvas.drawPath(
        sheen,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width * .28
          ..color = Colors.white.withValues(alpha: .22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_SwooshPainter old) =>
      old.top != top || old.bottom != bottom || old.animated != animated;
}
