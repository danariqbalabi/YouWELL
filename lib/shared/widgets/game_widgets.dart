import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/utils/date_key.dart';

/// Reward-facing building blocks for the mobile app. Personal only: no ranks.

/// Icon for a quest, picked from what the user actually does.
IconData questIcon(Map<String, dynamic> task) =>
    switch (task['activityKind'] ?? task['catalogId'] ?? task['ladder']) {
      'walk' => Icons.directions_walk_rounded,
      'run' => Icons.directions_run_rounded,
      'habit_swap' => Icons.swap_horiz_rounded,
      'water' || 'water-glass' => Icons.water_drop_rounded,
      'meal_snap' || 'ladder-food' || 'Food' => Icons.restaurant_rounded,
      'ladder-energy' || 'Energy' => Icons.bedtime_rounded,
      'posture' || 'stand-break' => Icons.accessibility_new_rounded,
      'stretch' => Icons.sports_gymnastics_rounded,
      'sunlight' => Icons.wb_sunny_rounded,
      'screen-break' => Icons.phonelink_off_rounded,
      'fresh-air' => Icons.park_rounded,
      'fruit-veg' => Icons.eco_rounded,
      'trigger' => Icons.search_rounded,
      'swap-plan' => Icons.checklist_rounded,
      _ => switch (task['category']) {
        'Body' => Icons.directions_walk_rounded,
        'Energy' => Icons.bedtime_rounded,
        'Reduction' => Icons.swap_horiz_rounded,
        'Lifestyle' => Icons.water_drop_rounded,
        'Food' => Icons.restaurant_rounded,
        _ => Icons.auto_awesome_rounded,
      },
    };

/// Flat gold "+25 XP" pill.
class XpPill extends StatelessWidget {
  const XpPill(this.xp, {super.key, this.prefix = '+', this.large = false});
  final int xp;
  final String prefix;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: c.xpSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: large ? 18 : 15, color: c.onXp),
          Text(
            '$prefix$xp XP',
            style: TextStyle(
              color: c.onXp,
              fontSize: large ? 15 : 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Flat gold medal with the level number.
class LevelBadge extends StatelessWidget {
  const LevelBadge(this.level, {super.key, this.size = 52});
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Level $level',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.xp,
          border: Border.all(color: c.card, width: size > 30 ? 3 : 2),
        ),
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (size > 30)
                Text(
                  'LV',
                  style: TextStyle(
                    color: const Color(0xff3d2a00),
                    fontSize: size * .19,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              Text(
                '$level',
                style: TextStyle(
                  color: const Color(0xff3d2a00),
                  fontSize: size * (size > 30 ? .38 : .5),
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thick flat progress bar (Duolingo style) with a soft highlight stripe.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.value, this.height = 14, this.color});
  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fill = color ?? c.primary;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(99),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.04, 1).toDouble(),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(99),
          ),
          alignment: Alignment.topCenter,
          padding: EdgeInsets.fromLTRB(
            height * .5,
            height * .22,
            height * .5,
            0,
          ),
          child: Container(
            height: height * .22,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big Duolingo-style button with a 3D bottom edge that presses down.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.edge,
    this.foreground,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color, edge, foreground;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.onPressed != null;
    final face = enabled ? widget.color ?? c.primary : c.raised;
    final edge = enabled ? widget.edge ?? c.primaryEdge : c.border;
    final ink = enabled ? widget.foreground ?? c.onPrimary : c.muted;
    const depth = 4.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onPressed!();
              }
            : null,
        child: ExcludeSemantics(
          child: SizedBox(
            height: 56,
            child: Stack(
              children: [
                Positioned.fill(
                  top: depth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: edge,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 80),
                  left: 0,
                  right: 0,
                  top: _down ? depth : 0,
                  bottom: _down ? 0 : depth,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: face,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: ink, size: 22),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small stat for the top bar: icon + bold number.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value, label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $label',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 3),
            Text(
              value,
              style: TextStyle(
                color: context.colors.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Circular progress with a centered child.
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    required this.child,
    this.size = 64,
    this.stroke = 7,
    this.color,
    this.track,
  });
  final double value, size, stroke;
  final Widget child;
  final Color? color, track;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _RingPainter(
        value.clamp(0, 1).toDouble(),
        stroke,
        color ?? context.colors.success,
        track ?? context.colors.raised,
      ),
      child: Center(child: child),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.color, this.track);
  final double value, stroke;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        arc,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// Last seven days as dots; filled days had at least one finished quest.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.now,
    required this.activeDays,
    this.dark = false,
  });
  final DateTime now;
  final Set<String> activeDays;

  /// Draw on a colored hero card instead of a plain card.
  final bool dark;

  static const _letters = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = dayKey(now);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var back = 6; back >= 0; back--)
          Builder(
            builder: (context) {
              final date = DateTime(now.year, now.month, now.day - back);
              final key = dayKey(date);
              final active = activeDays.contains(key);
              final isToday = key == today;
              return Semantics(
                label:
                    '${_letters[date.weekday - 1]} ${active ? 'aktif' : 'belum aktif'}',
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? c.streak : c.raised,
                        border: Border.all(
                          color: isToday ? c.text : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: active
                          ? const Icon(
                              Icons.local_fire_department_rounded,
                              size: 18,
                              color: Color(0xff3d1f00),
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _letters[date.weekday - 1],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                        color: dark ? c.text : c.muted,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Flat card: white surface with a firm 2px border, no shadow.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color, borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: color ?? c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor ?? c.border, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Bold section heading with an optional trailing widget.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.icon});
  final String text;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: context.colors.primary),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    ),
  );
}
