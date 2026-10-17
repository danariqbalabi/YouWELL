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

/// Burst of falling confetti for big moments (Hari Penuh, evolution).
/// Painted straight from the animation, so no widget rebuilds per frame.
class _Confetti extends StatefulWidget {
  const _Confetti({
    this.delay = Duration.zero,
    this.seed = 7,
    this.pieces = 46,
    this.duration = const Duration(milliseconds: 3200),
  });
  final Duration delay, duration;
  final int seed, pieces;
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final _fall = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _start;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _fall.forward();
    } else {
      _start = Timer(widget.delay, () {
        if (mounted) _fall.forward();
      });
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: CustomPaint(
        willChange: true,
        painter: _ConfettiPainter(_fall, widget.seed, widget.pieces, [
          c.xp,
          c.primary,
          c.success,
          c.energy,
          c.lifestyle,
        ]),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.fall, this.seed, this.pieces, this.colors)
    : super(repaint: fall);
  final Animation<double> fall;
  final int seed, pieces;
  final List<Color> colors;
  final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final t = fall.value;
    if (t <= 0 || t >= 1) return;
    final random = math.Random(seed);
    final eased = Curves.easeOutQuad.transform(t);
    for (var i = 0; i < pieces; i++) {
      final x = random.nextDouble() * size.width;
      final drift = (random.nextDouble() - .5) * 80;
      final fallBy = size.height * (.25 + .8 * random.nextDouble());
      final wobble = math.sin(t * 9 + i) * 10;
      final spin = random.nextDouble() * math.pi * 2 + t * 7;
      // Fade out only in the last third, so the burst does not just vanish.
      _paint.color = colors[i % colors.length].withValues(
        alpha: (1 - ((t - .66) / .34).clamp(0.0, 1.0)) * .95,
      );
      canvas.save();
      canvas.translate(x + drift * eased + wobble, -20 + fallBy * eased);
      canvas.rotate(spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4, -7, 8, 14),
          const Radius.circular(2),
        ),
        _paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.colors != colors;
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
  // One timeline for the entrance (~3.6 s): ribbons draw in, rays open behind
  // the trophy, then text, a counting XP pill and the button arrive one after
  // another. Afterwards the ribbons sway, the rays turn and the trophy floats.
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
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

  /// Fades and lifts [child] in during [begin]–[end] of the entrance.
  Widget _enter(
    double begin,
    double end,
    Widget child, {
    double rise = 18,
    double fromScale = 1,
    Curve curve = Curves.easeOutCubic,
  }) {
    final progress = CurvedAnimation(
      parent: _intro,
      curve: Interval(begin, end, curve: curve),
    );
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (_, child) {
        final v = progress.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, rise * (1 - v)),
            child: Transform.scale(
              scale: fromScale + (1 - fromScale) * v,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final moment = widget.moment;
    const ink = Color(0xff0d1417);
    final lines = [
      if (moment.evolved) 'Temanmu tumbuh ke tahap baru',
      ...moment.unlocks.map((name) => '$name terbuka'),
      ...moment.badges.map((name) => 'Lencana: $name'),
    ];
    return Material(
      color: ink,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                willChange: !widget.reduceMotion,
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
          if (!widget.reduceMotion) ...[
            const Positioned.fill(
              child: IgnorePointer(
                child: _Confetti(
                  delay: Duration(milliseconds: 500),
                  pieces: 56,
                  duration: Duration(milliseconds: 4200),
                ),
              ),
            ),
            // A second, lighter wave as the XP lands.
            const Positioned.fill(
              child: IgnorePointer(
                child: _Confetti(
                  delay: Duration(milliseconds: 1900),
                  seed: 21,
                  pieces: 34,
                  duration: Duration(milliseconds: 4600),
                ),
              ),
            ),
          ],
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  SizedBox(
                    width: 200,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              willChange: !widget.reduceMotion,
                              painter: _TrophyRaysPainter(
                                c.xp,
                                intro: _intro,
                                flow: _flow,
                                animated: !widget.reduceMotion,
                              ),
                            ),
                          ),
                        ),
                        _enter(
                          .16,
                          .4,
                          AnimatedBuilder(
                            animation: _flow,
                            child: Icon(
                              Icons.emoji_events_rounded,
                              color: c.xp,
                              size: 84,
                            ),
                            // Three whole bobs per loop: no jump on repeat.
                            builder: (_, child) => Transform.translate(
                              offset: Offset(
                                0,
                                widget.reduceMotion
                                    ? 0
                                    : math.sin(_flow.value * math.pi * 6) * 4,
                              ),
                              child: child,
                            ),
                          ),
                          rise: 0,
                          fromScale: .2,
                          curve: Curves.elasticOut,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  _enter(
                    .32,
                    .5,
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
                  ),
                  const SizedBox(height: 10),
                  _enter(
                    .4,
                    .58,
                    const Text(
                      'Semua misi hari ini selesai. Hari Penuh!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xffd7e3e8),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _enter(
                    .5,
                    .66,
                    // The XP counts up once the pill has landed.
                    AnimatedBuilder(
                      animation: _intro,
                      builder: (_, _) => XpPill(
                        (moment.xp *
                                Curves.easeOutCubic.transform(
                                  ((_intro.value - .54) / .26).clamp(0.0, 1.0),
                                ))
                            .round(),
                        large: true,
                      ),
                    ),
                    rise: 0,
                    fromScale: .5,
                    curve: Curves.easeOutBack,
                  ),
                  for (final (index, line) in lines.indexed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _enter(
                        (.66 + index * .05).clamp(0, .85),
                        (.8 + index * .05).clamp(0, 1),
                        Text(
                          line,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        rise: 10,
                      ),
                    ),
                  const Spacer(),
                  _enter(
                    .82,
                    1,
                    ChunkyButton(
                      label: 'Lanjut',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    rise: 24,
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
/// No blur: a mask filter per frame stutters on the web renderer.
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
  final _band = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _sheen = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = Colors.white.withValues(alpha: .16);

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
    // Top ribbon draws during the first 55% of the entrance, bottom after.
    double reveal(double begin, double end) => Curves.easeInOutCubic.transform(
      ((intro.value - begin) / (end - begin)).clamp(0.0, 1.0),
    );
    _ribbon(canvas, topPath, top, width, reveal(0, .36), flow.value);
    _ribbon(
      canvas,
      bottomPath,
      bottom,
      width,
      reveal(.08, .44),
      flow.value + .5,
    );
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
    _band
      ..strokeWidth = width
      ..color = color;
    if (reveal >= 1 && !animated) {
      canvas.drawPath(path, _band);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        reveal >= 1 ? path : metric.extractPath(0, metric.length * reveal),
        _band,
      );
      if (!animated || reveal < 1) continue;
      // A thin, faint highlight travelling along the ribbon's centre.
      final start = (sheenAt % 1) * metric.length * 1.3 - metric.length * .15;
      final from = start.clamp(0.0, metric.length);
      final to = (start + metric.length * .18).clamp(0.0, metric.length);
      if (to - from < 1) continue;
      canvas.drawPath(
        metric.extractPath(from, to),
        _sheen..strokeWidth = width * .22,
      );
    }
  }

  @override
  bool shouldRepaint(_SwooshPainter old) =>
      old.top != top || old.bottom != bottom || old.animated != animated;
}

/// Soft glow, slowly turning rays and twinkles behind the trophy. The rays
/// open with the trophy, then turn one ray-gap per loop so repeats are seamless.
class _TrophyRaysPainter extends CustomPainter {
  _TrophyRaysPainter(
    this.color, {
    required this.intro,
    required this.flow,
    required this.animated,
  }) : super(repaint: Listenable.merge([intro, flow]));
  final Color color;
  final Animation<double> intro, flow;
  final bool animated;
  static const _rays = 12;
  final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final open = Curves.easeOutCubic.transform(
      ((intro.value - .14) / .3).clamp(0.0, 1.0),
    );
    if (open <= 0) return;
    final center = size.center(Offset.zero);
    final phase = animated ? flow.value : 0.0;
    final pulse = animated ? (math.sin(phase * math.pi * 4) + 1) / 2 : .5;
    final radius = size.shortestSide * .62 * open;

    _paint.shader = RadialGradient(
      colors: [
        color.withValues(alpha: (.34 + .12 * pulse) * open),
        color.withValues(alpha: 0),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, _paint);
    _paint.shader = null;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(phase * math.pi * 2 / _rays);
    _paint.color = color.withValues(alpha: .13 * open);
    final ray = Path()
      ..moveTo(0, 0)
      ..lineTo(radius * 1.25, -radius * .11)
      ..lineTo(radius * 1.25, radius * .11)
      ..close();
    for (var i = 0; i < _rays; i++) {
      canvas.drawPath(ray, _paint);
      canvas.rotate(math.pi * 2 / _rays);
    }
    canvas.restore();

    // Four twinkles that fade in and out at their own moments.
    for (var i = 0; i < 4; i++) {
      final at = (phase * 2 + i / 4) % 1;
      final glow = animated ? math.sin(at * math.pi) : .6;
      final angle = -math.pi * .85 + i * math.pi * .56;
      final spot =
          center + Offset(math.cos(angle), math.sin(angle) * .7) * radius * .8;
      _star(canvas, spot, (5 + 4 * glow) * open, glow * open);
    }
  }

  void _star(Canvas canvas, Offset at, double r, double alpha) {
    if (alpha <= .02) return;
    _paint.color = Colors.white.withValues(alpha: .9 * alpha);
    final star = Path()
      ..moveTo(at.dx, at.dy - r)
      ..quadraticBezierTo(at.dx, at.dy, at.dx + r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r)
      ..quadraticBezierTo(at.dx, at.dy, at.dx - r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r)
      ..close();
    canvas.drawPath(star, _paint);
  }

  @override
  bool shouldRepaint(_TrophyRaysPainter old) =>
      old.color != color || old.animated != animated;
}
