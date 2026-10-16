import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';

/// Welli, the living companion. Animation respects OS and in-app preferences.
class MobileCompanion extends StatefulWidget {
  const MobileCompanion({
    super.key,
    required this.controller,
    this.size = 286,
    this.onTap,
  });
  final WellnessController controller;
  final double size;
  final VoidCallback? onTap;
  @override
  State<MobileCompanion> createState() => _MobileCompanionState();
}

class _MobileCompanionState extends State<MobileCompanion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  int _seenReward = 0;
  bool _happy = false;
  bool _moving = false;
  Timer? _reactionTimer;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
  }

  @override
  void didUpdateWidget(MobileCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
    if (_seenReward != widget.controller.rewardSerial) {
      _seenReward = widget.controller.rewardSerial;
      _react();
    }
  }

  void _configure() {
    final move =
        !widget.controller.reduceMotion &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (move == _moving) return;
    _moving = move;
    if (move) {
      _motion.repeat(reverse: true);
    } else {
      _motion.stop();
    }
  }

  void _react() {
    if (!mounted) return;
    _reactionTimer?.cancel();
    setState(() => _happy = true);
    _reactionTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _happy = false);
    });
  }

  @override
  void dispose() {
    _reactionTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final kind = controller.profile?['companion']?.toString() ?? 'plant';
    final stage = companionStage(controller.level);
    return Semantics(
      button: true,
      label:
          '${controller.companionDisplayName}, ${companionStageName(stage)}, tahap $stage dari 5. Sentuh untuk menyapa.',
      child: GestureDetector(
        onTap: () {
          _react();
          widget.onTap?.call();
        },
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) => Transform.translate(
            offset: Offset(
              0,
              _moving
                  ? -6 * math.sin(_motion.value * math.pi) - (_happy ? 7 : 0)
                  : 0,
            ),
            child: AnimatedScale(
              scale: _happy && _moving ? 1.06 : 1,
              duration: Duration(milliseconds: _moving ? 250 : 0),
              child: SizedBox.square(
                dimension: widget.size,
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: _moving ? 650 : 0),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: CustomPaint(
                    key: ValueKey('$kind-$stage'),
                    size: Size.square(widget.size),
                    painter: _WelliPainter(
                      kind,
                      stage,
                      controller.companionAccessory,
                      controller.companionBackground,
                      _happy,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Still drawing of the companion with any stage or reward, for previews.
class CompanionPreview extends StatelessWidget {
  const CompanionPreview({
    super.key,
    required this.kind,
    required this.stage,
    this.accessory = 'none',
    this.background = 'natural',
    this.size = 84,
    this.happy = false,
  });
  final String kind, accessory, background;
  final int stage;
  final double size;
  final bool happy;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _WelliPainter(kind, stage, accessory, background, happy),
    ),
  );
}

/// Welli: a soft, round mochi-like buddy with a sprout that grows over five
/// stages (seed bud, sprout, leaves, bloom, glowing bloom). Everything is
/// placed relative to the body, so accessories follow every stage's size.
class _WelliPainter extends CustomPainter {
  _WelliPainter(
    this.kind,
    this.stage,
    this.accessory,
    this.background,
    this.happy,
  );
  final String kind, accessory, background;
  final int stage;
  final bool happy;

  static const _ink = Color(0xff2b2d42);
  static const _leaf = Color(0xff4e9a5e);
  static const _leafLight = Color(0xff7cc48a);
  static const _petal = Color(0xffff8fa3);
  static const _gold = Color(0xffffc94d);

  /// Body light/shade per colour choice; the stored ids predate Welli.
  (Color, Color) get _body => switch (kind) {
    'cat' => (const Color(0xffffd3bb), const Color(0xfff5a885)),
    'cloud' => (const Color(0xffd6d1fa), const Color(0xffa9a2ee)),
    _ => (const Color(0xffc3e6bd), const Color(0xff8fc78a)),
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300);
    const center = Offset(150, 150);
    final (inner, outer) = switch (background) {
      'dusk' => (const Color(0xffeee6fd), const Color(0xffcfc0f2)),
      'sunrise' => (const Color(0xfffff1d6), const Color(0xffffcf9f)),
      // Default: the app's cream, so every body colour stands out.
      _ => (const Color(0xfffffcef), const Color(0xffffefc4)),
    };
    canvas.drawCircle(
      center,
      126,
      Paint()
        ..shader = RadialGradient(
          colors: [inner, outer],
        ).createShader(Rect.fromCircle(center: center, radius: 126)),
    );

    final s = .74 + stage * .052;
    final w = 156 * s, h = 138 * s;
    const ground = 236.0;
    final top = ground - h;
    final left = 150 - w / 2, right = 150 + w / 2;
    final (light, shade) = _body;

    if (stage == 5) {
      final glow = Offset(150, top + h * .45);
      canvas.drawCircle(
        glow,
        w * .78,
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0x80fff3b0), const Color(0x00fff3b0)],
          ).createShader(Rect.fromCircle(center: glow, radius: w * .78)),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(150, ground + 3),
        width: w * .78,
        height: 14,
      ),
      Paint()..color = const Color(0x1a000000),
    );

    _sprout(canvas, Offset(150, top + 8), s);

    final limb = Paint()..color = shade;
    if (stage >= 2) {
      for (final dx in [-w * .2, w * .2]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(150 + dx, ground - 3),
            width: 30 * s,
            height: 16 * s,
          ),
          limb,
        );
      }
    }
    if (stage >= 3) {
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(150 + side * w * .47, top + h * .64);
        canvas.rotate(side * (happy ? -.9 : .35));
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(side * 10 * s, 0),
            width: 30 * s,
            height: 18 * s,
          ),
          limb,
        );
        canvas.restore();
      }
    }

    final body = Path()
      ..moveTo(150, top)
      ..cubicTo(150 + w * .42, top, right, top + h * .42, right, top + h * .68)
      ..cubicTo(right, ground - h * .06, 150 + w * .3, ground, 150, ground)
      ..cubicTo(150 - w * .3, ground, left, ground - h * .06, left, top + h * .68)
      ..cubicTo(left, top + h * .42, 150 - w * .42, top, 150, top)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, Color.lerp(light, shade, .55)!],
        ).createShader(Rect.fromLTRB(left, top, right, ground)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(150, ground - h * .2),
        width: w * .52,
        height: h * .3,
      ),
      Paint()..color = const Color(0x40ffffff),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(150 - w * .22, top + h * .24),
        width: w * .16,
        height: h * .1,
      ),
      Paint()..color = const Color(0x8cffffff),
    );

    _face(canvas, top + h * .52, w, s);
    _accessory(canvas, top, w, h, s);
    canvas.restore();
  }

  void _face(Canvas canvas, double eyeY, double w, double s) {
    final ink = Paint()..color = _ink;
    for (final dx in [-w * .17, w * .17]) {
      final eye = Offset(150 + dx, eyeY);
      if (happy) {
        canvas.drawArc(
          Rect.fromCenter(center: eye, width: 18 * s, height: 14 * s),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = _ink
            ..strokeWidth = 4 * s
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: eye, width: 16 * s, height: 21 * s),
          ink,
        );
        canvas.drawCircle(
          eye + Offset(3 * s, -4.4 * s),
          3.6 * s,
          Paint()..color = Colors.white,
        );
      }
    }
    for (final dx in [-w * .29, w * .29]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(150 + dx, eyeY + 15 * s),
          width: 22 * s,
          height: 12 * s,
        ),
        Paint()..color = const Color(0x73ff8a80),
      );
    }
    final mouth = Rect.fromCenter(
      center: Offset(150, eyeY + 13 * s),
      width: 16 * s,
      height: 12 * s,
    );
    if (happy) {
      canvas.drawArc(
        mouth,
        0,
        math.pi,
        true,
        Paint()..color = const Color(0xffe85d75),
      );
    } else {
      canvas.drawArc(
        mouth,
        .2,
        math.pi - .4,
        false,
        Paint()
          ..color = _ink
          ..strokeWidth = 3.2 * s
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _leafShape(
    Canvas canvas,
    Offset base,
    double angle,
    double length,
    Color color,
  ) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(length * .5, -length * .48, length, 0)
        ..quadraticBezierTo(length * .5, length * .48, 0, 0),
      Paint()..color = color,
    );
    canvas.drawLine(
      Offset(length * .15, 0),
      Offset(length * .78, 0),
      Paint()
        ..color = const Color(0x40ffffff)
        ..strokeWidth = 1.6,
    );
    canvas.restore();
  }

  /// The head sprout is how growth reads at a glance.
  void _sprout(Canvas canvas, Offset base, double s) {
    if (stage == 1) {
      _leafShape(canvas, base + Offset(0, -2 * s), -math.pi / 2, 22 * s, _leaf);
      return;
    }
    final height = [0, 26, 34, 42, 48][stage - 1] * s;
    final tip = base + Offset(0, -height);
    canvas.drawLine(
      base,
      tip,
      Paint()
        ..color = _leaf
        ..strokeWidth = 5 * s
        ..strokeCap = StrokeCap.round,
    );
    final leafLength = (stage >= 5 ? 36 : 30) * s;
    final joint = base + Offset(0, -height * .55);
    _leafShape(canvas, joint, -.55, leafLength, _leafLight);
    if (stage >= 3) {
      _leafShape(canvas, joint, math.pi + .55, leafLength, _leaf);
    }
    if (stage == 2) {
      _leafShape(canvas, tip, -math.pi / 2 - .3, 16 * s, _leaf);
      return;
    }
    if (stage >= 4) {
      final petals = stage == 5 ? 6 : 5;
      final radius = (stage == 5 ? 11 : 8) * s;
      for (var i = 0; i < petals; i++) {
        final angle = i * 2 * math.pi / petals - math.pi / 2;
        canvas.drawCircle(
          tip + Offset(math.cos(angle), math.sin(angle)) * radius,
          radius * .82,
          Paint()..color = _petal,
        );
      }
      canvas.drawCircle(tip, radius * .7, Paint()..color = _gold);
    }
  }

  void _sparkle(Canvas canvas, Offset center, double size) {
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy - size)
        ..quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy)
        ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size)
        ..quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy)
        ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size)
        ..close(),
      Paint()..color = _gold,
    );
  }

  void _accessory(Canvas canvas, double top, double w, double h, double s) {
    if (accessory == 'ribbon') {
      final knot = Offset(150 - w * .3, top + h * .2);
      canvas.save();
      canvas.translate(knot.dx, knot.dy);
      canvas.scale(1.45);
      canvas.translate(-knot.dx, -knot.dy);
      final bow = Paint()..color = const Color(0xffff7444);
      for (final side in [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(knot.dx, knot.dy)
            ..quadraticBezierTo(
              knot.dx + side * 20 * s,
              knot.dy - 16 * s,
              knot.dx + side * 18 * s,
              knot.dy + 2 * s,
            )
            ..quadraticBezierTo(
              knot.dx + side * 16 * s,
              knot.dy + 12 * s,
              knot.dx,
              knot.dy,
            ),
          bow,
        );
      }
      canvas.drawCircle(knot, 5 * s, Paint()..color = const Color(0xffe85d3a));
      canvas.restore();
    }
    if (accessory == 'crown') {
      canvas.save();
      canvas.translate(150 + w * .26, top + h * .12);
      canvas.rotate(.35);
      final cw = 36 * s, ch = 22 * s;
      canvas.drawPath(
        Path()
          ..moveTo(-cw / 2, 0)
          ..lineTo(-cw / 2, -ch)
          ..lineTo(-cw / 4, -ch * .45)
          ..lineTo(0, -ch * 1.1)
          ..lineTo(cw / 4, -ch * .45)
          ..lineTo(cw / 2, -ch)
          ..lineTo(cw / 2, 0)
          ..close(),
        Paint()..color = _gold,
      );
      canvas.drawCircle(
        Offset(0, -ch * .35),
        3.2 * s,
        Paint()..color = _leafLight,
      );
      canvas.restore();
    }
    if (stage == 5) {
      // The last stage glows: two small sparkles of its own.
      _sparkle(canvas, Offset(150 - w * .42, top - 4), 6);
      _sparkle(canvas, Offset(150 + w * .62, top + h * .18), 5);
    }
    if (accessory == 'stars' || happy) {
      _sparkle(canvas, Offset(150 - w * .68, top + h * .32), 10);
      _sparkle(canvas, Offset(150 + w * .66, top + h * .5), 8);
      _sparkle(canvas, Offset(150 + w * .5, top - 6), 7);
    }
  }

  @override
  bool shouldRepaint(_WelliPainter old) =>
      kind != old.kind ||
      stage != old.stage ||
      accessory != old.accessory ||
      background != old.background ||
      happy != old.happy;
}
