import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/router.dart';
import 'package:little_builder_robots/app/services.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/audio/audio_service.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/widgets/chunky_button.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/core/widgets/robot_painter.dart';
import 'package:little_builder_robots/features/result/reveal.dart';

/// Result (RES-01 to RES-06).
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  /// RES-04: buttons appear after the reveals.
  bool _ready = false;
  bool _yawn = false;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    final audio = ref.read(audioProvider)..sfx(Sfx.cheer);
    unawaited(audio.music(MusicGroup.menus));
    unawaited(audio.voice('screenResult'));
    _yawn = ref.read(playLimitProvider).windDown; // PAR-11
    // Let the stars land first (NFR-21: under 4 s).
    _revealTimer = Timer(const Duration(milliseconds: 1200), _reveals);
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  Future<void> _reveals() async {
    if (!mounted) return;
    final report = ref.read(lastRunProvider);
    if (report?.newPartId case final id?) {
      final part = ref.read(gameDataProvider).catalog.byId(id);
      await revealPart(context, part);
    }
    if (!mounted) return;
    await revealStickers(context, ref);
    if (mounted) setState(() => _ready = true);
  }

  void _next() {
    final data = ref.read(gameDataProvider);
    final next = SelectedCourseController.nextCourse(
      data.courses,
      ref.read(profileProvider),
    );
    ref.read(selectedCourseProvider.notifier).select(next.id);
    context.go(AppRoute.courseMap.path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final report = ref.watch(lastRunProvider);
    final profile = ref.watch(profileProvider);
    if (report == null) {
      return ChildScaffold(
        body: Center(
          child: ChunkyButton(
            label: l10n.buttonNext,
            style: ChunkyButtonStyle.primary,
            onPressed: _next,
          ),
        ),
      );
    }
    final data = ref.watch(gameDataProvider);
    final finale =
        report.courseId == data.courses.last.id &&
        report.rewardBolts == 0 &&
        report.newPartId != null;
    final stars = [
      (report.stars.finish, Icons.flag_rounded, l10n.starFinish),
      (report.stars.allBolts, Icons.hexagon_rounded, l10n.starAllBolts),
      (report.stars.noFalls, Icons.water_drop_rounded, l10n.starNoFalls),
    ];
    final gained = report.runBolts + report.rewardBolts;

    final scaffold = ChildScaffold(
      topRight: BoltCounter(bolts: profile.bolts),
      body: Center(
        // Child screens never scroll (NFR-19): on a short screen the
        // content shrinks so Next, Rebuild and Play again stay in reach.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(88, 16, 16, 16),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (finale)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(l10n.celebration, style: AppText.title),
                      ),
                    RobotView(
                      config: profile.robot,
                      size: 150,
                      face: _yawn ? RobotFace.sleep : RobotFace.cheer,
                      armsUp: !_yawn,
                    ),
                    if (finale) const _Parade(),
                  ],
                ),
                const SizedBox(width: 32),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.screenResult, style: AppText.display),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, (earned, icon, label)) in stars.indexed)
                          _Star(
                            earned: earned,
                            icon: icon,
                            label: label,
                            delay: Duration(milliseconds: 250 * i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (report.outcome.foundGear)
                      Semantics(
                        label: l10n.gearFoundLabel,
                        excludeSemantics: true,
                        child: const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: GearBadge(found: true, size: 44),
                        ),
                      ),
                    if (gained > 0)
                      Semantics(
                        label: l10n.boltsGainedLabel(gained),
                        excludeSemantics: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('+$gained', style: AppText.title),
                            const SizedBox(width: 6),
                            const BoltIcon(size: 36),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    AnimatedOpacity(
                      opacity: _ready ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !_ready,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RoundIconButton(
                              icon: Icons.build_rounded,
                              label: l10n.buttonRebuild,
                              size: 72,
                              onPressed: () =>
                                  context.go(AppRoute.workshop.path),
                            ),
                            const SizedBox(width: AppSizes.targetSpacing),
                            RoundIconButton(
                              icon: Icons.replay_rounded,
                              label: l10n.buttonPlayAgain,
                              size: 72,
                              onPressed: () => context.go(AppRoute.run.path),
                            ),
                            const SizedBox(width: AppSizes.targetSpacing),
                            ChunkyButton(
                              label: l10n.buttonNext,
                              icon: Icons.arrow_forward_rounded,
                              style: ChunkyButtonStyle.primary,
                              onPressed: _next,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // A confetti shower to celebrate the finish (skipped with Reduce
    // Motion; never blocks a tap).
    return Stack(
      children: [
        scaffold,
        const Positioned.fill(child: ConfettiShower()),
      ],
    );
  }
}

/// RES-01: an earned star pops in; an unearned one is an outline. The rule
/// is an icon under the star (flag, bolt, no splash), not a word.
class _Star extends StatelessWidget {
  const _Star({
    required this.earned,
    required this.icon,
    required this.label,
    required this.delay,
  });

  final bool earned;
  final IconData icon;
  final String label;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final star = Icon(
      earned ? Icons.star_rounded : Icons.star_outline_rounded,
      size: 88,
      color: earned ? AppColors.sunny : AppColors.navy,
      shadows: const [Shadow(color: AppColors.navy, blurRadius: 2)],
    );
    final animated = MediaQuery.disableAnimationsOf(context) || !earned
        ? star
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300) + delay,
            curve: Interval(
              delay.inMilliseconds / (300 + delay.inMilliseconds),
              1,
              curve: Curves.easeOutBack,
            ),
            builder: (context, s, child) =>
                Transform.scale(scale: s, child: child),
            child: star,
          );
    return Semantics(
      label: '$label: ${earned ? '★' : '☆'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            animated,
            Icon(icon, size: 28, color: AppColors.navy),
          ],
        ),
      ),
    );
  }
}

/// Course 15's celebration parade: the robot's friends march past.
class _Parade extends StatelessWidget {
  const _Parade();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.celebration_rounded, size: 40, color: AppColors.tangerine),
      Icon(Icons.emoji_events_rounded, size: 40, color: AppColors.sunny),
      Icon(Icons.celebration_rounded, size: 40, color: AppColors.tangerine),
    ],
  );
}
