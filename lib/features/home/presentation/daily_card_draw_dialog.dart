import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/types/json_map.dart';

/// Shared mobile/web draw ritual: spin, swipe, reveal, then commit one pack.
class DailyCardDrawDialog extends StatefulWidget {
  const DailyCardDrawDialog({
    super.key,
    required this.controller,
    this.mobileExperience = false,
  });
  final WellnessController controller;
  final bool mobileExperience;

  @override
  State<DailyCardDrawDialog> createState() => _DailyCardDrawDialogState();
}

class _DailyCardDrawDialogState extends State<DailyCardDrawDialog> {
  @override
  void initState() {
    super.initState();
    // Saving notifies listeners, so wait until this first frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.drawDailyCards();
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      if (widget.controller.uatProgramComplete) {
        return AlertDialog(
          title: const Text('Perjalanan 28 hari selesai'),
          content: const Text(
            'Challenge harian sudah selesai. Kamu bisa melihat rekap dan riwayat perjalananmu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Lihat rekap'),
            ),
          ],
        );
      }
      final compact = MediaQuery.sizeOf(context).width < 600;
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 32,
          vertical: compact ? 20 : 32,
        ),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 820,
            maxHeight: compact ? 650 : 700,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.canvas,
              border: Border.all(color: context.colors.border),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 40,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: _DrawStage(
                controller: widget.controller,
                mobileExperience: widget.mobileExperience,
                onClose: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DrawStage extends StatelessWidget {
  const _DrawStage({
    required this.controller,
    required this.onClose,
    required this.mobileExperience,
  });
  final WellnessController controller;
  final VoidCallback onClose;
  final bool mobileExperience;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final selected = controller.selectedDailyCard;
    final recommended = controller.recommendedDailyCard;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 28,
        compact ? 16 : 24,
        compact ? 18 : 28,
        compact ? 18 : 26,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mobileExperience ? 'Kartu hari ini' : 'Daily Card Draw',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              _Pill(label: '${controller.dailyCardSwitchesRemaining}x ganti'),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Nanti saja',
                onPressed: onClose,
                icon: Icon(Icons.close_rounded, color: context.colors.muted),
              ),
            ],
          ),
          Text(
            mobileExperience
                ? 'Pilih 1 kartu berisi 3–5 misi.'
                : 'Satu kartu, 3–5 quest. Swipe lalu buka.',
            style: TextStyle(
              color: context.colors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (mobileExperience &&
              selected == null &&
              controller.passedDailyCardIds.isEmpty) ...[
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'relaxed',
                  label: Text('Santai'),
                  icon: Icon(Icons.spa_outlined),
                ),
                ButtonSegment(
                  value: 'normal',
                  label: Text('Normal'),
                  icon: Icon(Icons.bolt_outlined),
                ),
              ],
              selected: {controller.dailyPace},
              onSelectionChanged: (values) =>
                  controller.setDailyPace(values.first),
            ),
          ],
          if (controller.uatProgram != null &&
              selected == null &&
              recommended != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: controller.chooseRecommendedDailyCard,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text('Buka rekomendasi · ${recommended['size']} misi'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: selected == null
                ? _SpinningDeck(
                    key: ValueKey(
                      '${controller.dailyDeckStartIndex}-${controller.passedDailyCardIds.length}-${controller.dailyPace}',
                    ),
                    cards: controller.dailyDrawCards,
                    passedIds: controller.passedDailyCardIds,
                    initialIndex: controller.dailyDeckStartIndex,
                    onSelect: controller.selectDailyCard,
                    reduceMotion:
                        mobileExperience &&
                        (controller.reduceMotion ||
                            MediaQuery.disableAnimationsOf(context)),
                  )
                : _FlipReveal(
                    key: ValueKey(selected['id']),
                    card: selected,
                    reduceMotion:
                        mobileExperience &&
                        (controller.reduceMotion ||
                            MediaQuery.disableAnimationsOf(context)),
                    canChange: controller.canChooseAnotherDailyCard,
                    changesLeft: controller.dailyCardSwitchesRemaining,
                    onChange: controller.chooseAnotherDailyCard,
                    onCommit: () {
                      if (controller.commitDailyCardPack()) onClose();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SpinningDeck extends StatefulWidget {
  const _SpinningDeck({
    super.key,
    required this.cards,
    required this.passedIds,
    required this.initialIndex,
    required this.onSelect,
    this.reduceMotion = false,
  });
  final List<JsonMap> cards;
  final List<String> passedIds;
  final int initialIndex;
  final ValueChanged<String> onSelect;
  final bool reduceMotion;

  @override
  State<_SpinningDeck> createState() => _SpinningDeckState();
}

class _SpinningDeckState extends State<_SpinningDeck> {
  static const _basePage = 500;
  final math.Random _random = math.Random();
  late final PageController _pages;
  late final int _startPage;
  late int _page;
  bool _spinning = true;
  Timer? _spinTimer;

  @override
  void initState() {
    super.initState();
    _startPage = _basePage + widget.initialIndex;
    _page = _startPage;
    _pages = PageController(initialPage: _startPage, viewportFraction: .48);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _spinTimer = Timer(
        const Duration(milliseconds: 220),
        () => unawaited(_spin()),
      );
    });
  }

  Future<void> _spin() async {
    if (!mounted || !_pages.hasClients) return;
    final availableIndices = [
      for (var index = 0; index < widget.cards.length; index++)
        if (!widget.passedIds.contains(widget.cards[index]['id'])) index,
    ];
    if (availableIndices.isEmpty) {
      setState(() => _spinning = false);
      return;
    }
    final destination =
        availableIndices[_random.nextInt(availableIndices.length)];
    final deckLength = widget.cards.length;
    final fullTurns = 2 + _random.nextInt(2);
    final offset = (destination - (_startPage % deckLength)) % deckLength;
    if (widget.reduceMotion) {
      _pages.jumpToPage(_startPage + offset);
    } else {
      await _pages.animateToPage(
        _startPage + fullTurns * deckLength + offset,
        duration: const Duration(milliseconds: 1450),
        curve: Curves.easeInOutCubicEmphasized,
      );
    }
    if (mounted) setState(() => _spinning = false);
  }

  void _choose(int physicalIndex) {
    if (_spinning || physicalIndex != _page) return;
    final card = widget.cards[physicalIndex % widget.cards.length];
    if (widget.passedIds.contains(card['id'])) return;
    widget.onSelect(card['id'].toString());
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SizedBox(
              height: compact ? 350 : 390,
              child: MouseRegion(
                cursor: _spinning
                    ? SystemMouseCursors.wait
                    : SystemMouseCursors.grab,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: 1000,
                    physics: _spinning
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (context, physicalIndex) {
                      final index = physicalIndex % widget.cards.length;
                      return _CardBack(
                        index: index,
                        centered: physicalIndex == _page,
                        passed: widget.passedIds.contains(
                          widget.cards[index]['id'],
                        ),
                        compact: compact,
                        onTap: () => _choose(physicalIndex),
                        recommended:
                            widget.cards[index]['recommended'] == true &&
                            widget.cards[index].containsKey('activeMinutes'),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _spinning
                ? 'Mengocok deck…'
                : '${_page % widget.cards.length + 1} / ${widget.cards.length}  •  Ketuk kartu tengah',
            key: ValueKey(_spinning),
            style: TextStyle(
              color: _spinning ? context.colors.accent : context.colors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({
    required this.index,
    required this.centered,
    required this.passed,
    required this.compact,
    required this.onTap,
    this.recommended = false,
  });
  final int index;
  final bool centered, passed, compact;
  final VoidCallback onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[index % _palettes.length];
    return Center(
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        scale: centered ? 1 : .74,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: passed
              ? centered
                    ? .78
                    : .58
              : centered
              ? 1
              : .5,
          child: GestureDetector(
            onTap: centered && !passed ? onTap : null,
            child: ColorFiltered(
              colorFilter: passed
                  ? const ColorFilter.matrix([
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Container(
                width: compact ? 190 : 220,
                height: compact ? 310 : 350,
                decoration: _cardDecoration(palette, centered),
                child: Stack(
                  children: [
                    Positioned(
                      left: -38,
                      top: 58,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Text(
                        'YOUWELL',
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      top: 16,
                      child: Text(
                        '0${index + 1}',
                        style: TextStyle(
                          color: palette.ink.withValues(alpha: .6),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Center(child: _CardMascot(palette: palette)),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 18,
                      child: Column(
                        children: [
                          Text(
                            passed
                                ? 'SUDAH DILEWATI'
                                : recommended
                                ? 'COCOK BUATMU'
                                : 'KARTU MISI',
                            style: TextStyle(
                              color: palette.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            passed
                                ? 'TIDAK DIPILIH'
                                : centered
                                ? 'KETUK KARTU'
                                : 'GESER KARTU',
                            style: TextStyle(
                              color: palette.ink.withValues(alpha: .85),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardMascot extends StatelessWidget {
  const _CardMascot({required this.palette});
  final _Palette palette;
  @override
  Widget build(BuildContext context) => Container(
    width: 118,
    height: 126,
    decoration: BoxDecoration(
      color: palette.character,
      border: Border.all(color: Colors.white.withValues(alpha: .8), width: 3),
      borderRadius: BorderRadius.circular(44),
      boxShadow: [
        BoxShadow(
          color: palette.ink.withValues(alpha: .22),
          blurRadius: 10,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(left: 26, top: 28, child: _Eye(color: palette.ink)),
        Positioned(right: 26, top: 28, child: _Eye(color: palette.ink)),
        Center(
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 45,
            color: Colors.white.withValues(alpha: .88),
          ),
        ),
      ],
    ),
  );
}

class _Eye extends StatelessWidget {
  const _Eye({required this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 18,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
    ),
  );
}

class _FlipReveal extends StatelessWidget {
  const _FlipReveal({
    super.key,
    required this.card,
    required this.canChange,
    required this.changesLeft,
    required this.onChange,
    required this.onCommit,
    this.reduceMotion = false,
  });
  final JsonMap card;
  final bool canChange;
  final int changesLeft;
  final VoidCallback onChange, onCommit;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: Duration(milliseconds: reduceMotion ? 0 : 760),
    curve: Curves.easeInOutCubic,
    tween: Tween(begin: 0, end: 1),
    builder: (context, progress, _) {
      final front = progress >= .5;
      final angle = front ? math.pi * (1 - progress) : math.pi * progress;
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0014)
          ..rotateY(angle),
        child: front
            ? _CardFront(
                card: card,
                canChange: canChange,
                changesLeft: changesLeft,
                onChange: onChange,
                onCommit: onCommit,
              )
            : _RevealBack(palette: _paletteFor(card)),
      );
    },
  );
}

class _RevealBack extends StatelessWidget {
  const _RevealBack({required this.palette});
  final _Palette palette;
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 300,
      height: 410,
      decoration: _cardDecoration(palette, true),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style_rounded, size: 58, color: palette.ink),
            const SizedBox(height: 16),
            Text(
              'REVEALING…',
              style: TextStyle(
                color: palette.ink,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CardFront extends StatelessWidget {
  const _CardFront({
    required this.card,
    required this.canChange,
    required this.changesLeft,
    required this.onChange,
    required this.onCommit,
  });
  final JsonMap card;
  final bool canChange;
  final int changesLeft;
  final VoidCallback onChange, onCommit;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(card);
    final tasks = card['tasks'] is List
        ? (card['tasks'] as List)
              .whereType<Map>()
              .map((task) => Map<String, dynamic>.from(task))
              .toList()
        : [card];
    final difficulty = (card['difficulty'] as num?)?.toInt() ?? 1;
    final difficultyLabel = switch (difficulty) {
      2 => 'Sedang',
      3 => 'Penuh',
      _ => 'Ringan',
    };
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.colors.selected, context.colors.surface],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.light.withValues(alpha: .75)),
              boxShadow: [
                BoxShadow(
                  color: palette.dark.withValues(alpha: .32),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: palette.light,
                  child: Icon(
                    Icons.style_rounded,
                    color: palette.ink,
                    size: 29,
                  ),
                ),
                const SizedBox(height: 12),
                if (card['recommended'] == true) ...[
                  _Pill(label: 'Cocok buatmu', color: context.colors.success),
                  const SizedBox(height: 8),
                ],
                Text(
                  card['title'].toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tasks.length} misi  •  $difficultyLabel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                for (final task in tasks) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.canvas.withValues(alpha: .75),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.light.withValues(alpha: .35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          questIcon(task),
                          color: context.colors.accent,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            task['title'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.colors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+${task['xp']} XP',
                          style: TextStyle(
                            color: context.colors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 8),
                _Pill(
                  label:
                      '±${card['activeMinutes'] ?? card['durationMinutes']} menit${card.containsKey('activeMinutes') ? ' aktivitas' : ''}  •  total +${card['xp']} XP',
                  color: context.colors.accent,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCommit,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.light,
                      foregroundColor: palette.ink,
                    ),
                    icon: const Icon(Icons.rocket_launch_rounded),
                    label: Text('Mulai ${tasks.length} misi'),
                  ),
                ),
                if (canChange) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onChange,
                    child: Text('Pilih kartu lain ($changesLeft tersisa)'),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Text(
                    'Kesempatan ganti habis. Ambil kartu ini.',
                    style: TextStyle(color: context.colors.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.color});
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: (color ?? context.colors.accent).withValues(alpha: .13),
      border: Border.all(
        color: (color ?? context.colors.accent).withValues(alpha: .45),
      ),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color ?? context.colors.accent,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Palette {
  const _Palette(this.light, this.dark, this.character, this.ink);
  final Color light, dark, character, ink;
}

const _palettes = [
  _Palette(brandCream, Color(0xffeee6c9), brandOrange, Color(0xff28364f)),
  _Palette(brandLavender, Color(0xff9ea7e3), brandOrange, Color(0xff28364f)),
  _Palette(Color(0xffffba9e), brandOrange, brandBlue, Color(0xff28364f)),
  _Palette(Color(0xffdce0ff), brandLavender, brandBlue, Color(0xff28364f)),
  _Palette(brandCream, brandLavender, brandOrange, Color(0xff28364f)),
];

_Palette _paletteFor(JsonMap card) =>
    _palettes[((card['cardStyle'] as num?)?.toInt() ?? 0) % _palettes.length];

BoxDecoration _cardDecoration(_Palette palette, bool active) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [palette.light, palette.dark],
  ),
  border: Border.all(color: Colors.white.withValues(alpha: .88), width: 4),
  borderRadius: BorderRadius.circular(22),
  boxShadow: [
    BoxShadow(
      color: palette.dark.withValues(alpha: active ? .48 : .15),
      blurRadius: active ? 28 : 10,
      offset: const Offset(0, 10),
    ),
  ],
);
