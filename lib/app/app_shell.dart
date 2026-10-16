import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/activity/presentation/activity_page.dart';
import 'package:youwell/features/community/presentation/community_page.dart';
import 'package:youwell/features/home/presentation/daily_card_draw_dialog.dart';
import 'package:youwell/features/home/presentation/home_page.dart';
import 'package:youwell/features/profile/presentation/profile_page.dart';
import 'package:youwell/features/progress/presentation/progress_page.dart';
import 'package:youwell/features/companion/presentation/mobile_reward_host.dart';
import 'package:youwell/features/auth/presentation/account_scope.dart';
import 'package:youwell/features/sync/presentation/progress_sync_panel.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final WellnessController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _drawing = false;
  bool _drawDeferred = false;
  late String _day = widget.controller.today;
  Timer? _dayWatcher;
  final _companionTarget = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.enableMobileRewards();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDay());
    // Catch midnight while the app stays open in the foreground.
    _dayWatcher = Timer.periodic(const Duration(minutes: 1), (_) {
      if (widget.controller.today != _day) {
        _startDay();
      } else if (_drawDeferred) {
        _openDailyDraw();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayWatcher?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _startDay();
  }

  void _startDay() {
    if (!mounted) return;
    _day = widget.controller.today;
    widget.controller.prepareToday();
    _openDailyDraw();
  }

  Future<void> _openDailyDraw() async {
    if (!mounted || _drawing || !widget.controller.needsDailyCardDraw) return;
    // Never cover a pushed page, e.g. a walk that runs past midnight.
    _drawDeferred = ModalRoute.of(context)?.isCurrent == false;
    if (_drawDeferred) return;
    _drawing = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DailyCardDrawDialog(
        controller: widget.controller,
        mobileExperience: true,
      ),
    );
    _drawing = false;
  }

  void _openProfile() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProfilePage(controller: widget.controller),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        controller: widget.controller,
        companionKey: _companionTarget,
        onOpenDraw: _openDailyDraw,
        onOpenActivity: () => setState(() => _tab = 1),
      ),
      ActivityPage(controller: widget.controller),
      ProgressPage(controller: widget.controller),
      CommunityPage(controller: widget.controller),
    ];
    const labels = ['Hari ini', 'Aktivitas', 'Perjalanan', 'Komunitas'];
    const icons = [
      Icons.flag_outlined,
      Icons.directions_run_rounded,
      Icons.emoji_events_outlined,
      Icons.people_alt_outlined,
    ];
    const selectedIcons = [
      Icons.flag_rounded,
      Icons.directions_run_rounded,
      Icons.emoji_events_rounded,
      Icons.people_alt_rounded,
    ];
    final alias = widget.controller.profile!['alias'].toString();
    return MobileRewardHost(
      controller: widget.controller,
      target: _companionTarget,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (AccountScope.maybeOf(context) case final account?)
                ProgressSyncPanel(auth: account, compact: true),
              if (widget.controller.storageError case final error?)
                MaterialBanner(
                  content: Text(error),
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: context.colors.amber,
                  ),
                  actions: [
                    TextButton(
                      onPressed: widget.controller.dismissStorageError,
                      child: const Text('Mengerti'),
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
                child: Row(
                  children: [
                    Text(
                      'YouWELL',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: context.colors.success,
                            letterSpacing: -.5,
                          ),
                    ),
                    const Spacer(),
                    StatChip(
                      icon: Icons.local_fire_department_rounded,
                      color: context.colors.streak,
                      value: '${widget.controller.activeDaysIn(7)}',
                      label: 'hari aktif minggu ini',
                    ),
                    StatChip(
                      icon: Icons.bolt_rounded,
                      color: context.colors.xp,
                      value: '${widget.controller.xp}',
                      label: 'XP',
                    ),
                    if (widget.controller.needsDailyCardDraw)
                      IconButton(
                        tooltip: 'Ambil kartu hari ini',
                        onPressed: _openDailyDraw,
                        icon: Badge(
                          smallSize: 9,
                          backgroundColor: context.colors.primary,
                          child: Icon(
                            Icons.style_rounded,
                            color: context.colors.text,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Semantics(
                      button: true,
                      label: 'Buka profil',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _openProfile,
                        child: SizedBox.square(
                          dimension: 48,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: context.colors.selected,
                                child: Text(
                                  alias[0].toUpperCase(),
                                  style: TextStyle(
                                    color: context.colors.text,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: 0,
                                child: LevelBadge(
                                  widget.controller.level,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    for (final (index, page) in pages.indexed)
                      TickerMode(enabled: index == _tab, child: page),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: List.generate(
            labels.length,
            (index) => NavigationDestination(
              icon: Icon(icons[index]),
              selectedIcon: Icon(selectedIcons[index]),
              label: labels[index],
            ),
          ),
        ),
      ),
    );
  }
}
