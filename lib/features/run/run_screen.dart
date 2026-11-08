import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/router.dart';
import 'package:little_builder_robots/app/services.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/audio/audio_service.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/l10n/l10n_lookup.dart';
import 'package:little_builder_robots/core/utils/touch_guard.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/models/run_outcome.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';
import 'package:little_builder_robots/domain/rules/sticker_rules.dart';
import 'package:little_builder_robots/domain/sim/input_event.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';
import 'package:little_builder_robots/features/run/game/run_game.dart';
import 'package:little_builder_robots/features/run/hint_bubble.dart';
import 'package:little_builder_robots/features/run/hud.dart';
import 'package:little_builder_robots/features/run/pit_stop_panel.dart';
import 'package:little_builder_robots/features/run/run_controller.dart';

/// The obstacle run (RUN-01 to RUN-15, HLP, ONB-02, FEEL), and Test Track
/// with [testTrack] (TRK-01 to TRK-04).
class RunScreen extends ConsumerStatefulWidget {
  const RunScreen({this.testTrack = false, super.key});

  final bool testTrack;

  @override
  ConsumerState<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends ConsumerState<RunScreen> {
  late final Course _course;
  late final RobotConfig _startRobot;
  late final RunController _controller;
  late final RunGame _game;
  late final PlayStyle _style;
  final GlobalKey _bubbleKey = GlobalKey();
  bool _started = false;
  bool _leaving = false;
  int _lastHintStep = 0;
  int? _lastHintObstacle;
  bool _tutorialSpoken = false;
  Timer? _spokenHintTimer;
  bool _showSpokenHint = false;

  @override
  void initState() {
    super.initState();
    final data = ref.read(gameDataProvider);
    final profile = ref.read(profileProvider);
    _style = ref.read(settingsProvider).playStyle;
    _startRobot = profile.robot;
    _course = widget.testTrack
        ? ref.read(testTrackBuilderProvider).lap(profile)
        : ref.read(selectedCourseDataProvider);
    final firstPlay =
        !widget.testTrack && !profile.resultFor(_course.id).completed;
    _controller = RunController(
      course: _course,
      robot: _startRobot,
      calculator: ref.read(statCalculatorProvider),
      coach: ref.read(obstacleCoachProvider),
      tuning: data.tuning,
      playStyle: _style,
      owned: profile.unlockedPartIds,
      onEvent: _onEvent,
      // RUN-14: replays of a finished course skip the preview.
      preview: firstPlay,
      // ONB-02: wait at the first gap on the first course with gaps.
      tutorial:
          firstPlay &&
          _style == PlayStyle.big &&
          _course == _firstCourseWithGap(data.courses),
      loop: widget.testTrack,
    )..addListener(_onChange);
    _game = RunGame(_controller);
    final audio = ref.read(audioProvider);
    unawaited(
      audio.music(widget.testTrack ? MusicGroup.testTrack : MusicGroup.run),
    );
    unawaited(audio.voice(_course.hintKey));
  }

  static Course? _firstCourseWithGap(List<Course> courses) {
    for (final c in courses) {
      if (c.obstacles.any((o) => o is GapObstacle)) return c;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      // NFR-11: no camera pan with Reduce Motion.
      if (!MediaQuery.disableAnimationsOf(context)) _controller.startPreview();
    }
  }

  @override
  void dispose() {
    _spokenHintTimer?.cancel();
    _controller
      ..removeListener(_onChange)
      ..dispose();
    super.dispose();
  }

  void _onChange() {
    final hint = _controller.hint;
    final audio = ref.read(audioProvider);
    if (hint != null &&
        (hint.step != _lastHintStep ||
            hint.obstacleIndex != _lastHintObstacle)) {
      _lastHintStep = hint.step;
      _lastHintObstacle = hint.obstacleIndex;
      if (hint.step == 2) {
        // RUN-13 step 2: a voiced hint naming what is needed.
        unawaited(audio.voice(needHintKey(hint.need.need)));
        _spokenHintTimer?.cancel();
        _showSpokenHint = true;
        _spokenHintTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showSpokenHint = false);
        });
      } else if (hint.step == 3) {
        unawaited(audio.voice('tryNewParts'));
      }
    } else if (hint == null) {
      _lastHintStep = 0;
    }
    if (_controller.state.waitingForTap && !_tutorialSpoken) {
      _tutorialSpoken = true;
      unawaited(audio.voice('tutorialTapJump'));
    }
    if (!mounted) return;
    // Flame steps the run inside the frame; rebuild the overlay after it.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  void _onEvent(RunEvent event) {
    final audio = ref.read(audioProvider);
    final haptics = ref.read(hapticsProvider);
    switch (event) {
      case JumpedEvent() || HappyHopEvent():
        audio.sfx(Sfx.jump);
        haptics.light();
      case LandedEvent():
        audio.sfx(Sfx.land);
        haptics.light();
      case BoltCollectedEvent():
        audio.sfx(Sfx.bolt);
        haptics.light();
      case BumpedEvent():
        audio.sfx(Sfx.boing);
        haptics.medium();
      case FellEvent(:final obstacleIndex):
        final water =
            obstacleIndex != null &&
            _course.obstacles[obstacleIndex] is GapObstacle &&
            (_course.obstacles[obstacleIndex] as GapObstacle).water;
        audio.sfx(water ? Sfx.splash : Sfx.honk);
      case GateOpenedEvent() || SwitchPressedEvent():
        audio.sfx(Sfx.door);
      case LeavesBlownEvent() || RampLaunchEvent():
        audio.sfx(Sfx.whoosh);
      case SwungEvent():
        audio.sfx(Sfx.swing);
      case JetpackOnEvent():
        audio.sfx(Sfx.jetpack);
      case CeilingBonkEvent():
        audio.sfx(Sfx.boing);
      case ParkedEvent():
        audio.sfx(Sfx.tap);
        unawaited(audio.voice('pitStopHint'));
      case FinishedEvent():
        audio.sfx(Sfx.cheer);
        if (widget.testTrack) {
          ref.read(progressProvider.notifier).addFacts({Fact.testTrackLap});
        } else {
          Timer(const Duration(milliseconds: 1200), _finish);
        }
      default:
        break;
    }
  }

  Set<String> _facts() => {
    ...ref.read(stickerRulesProvider).factsFromRun(_course, _controller.events),
    if (_controller.swappedAtPitStop) Fact.pitStop,
  };

  void _finish() {
    if (!mounted || _leaving) return;
    _leaving = true;
    final report = ref
        .read(progressProvider.notifier)
        .applyRun(_course, _controller.sim.outcome, _facts());
    ref.read(lastRunProvider.notifier).set(report);
    context.go(AppRoute.result.path);
  }

  /// Leaving early keeps the bolts collected so far (RES-03).
  void _leave(AppRoute route, {Set<String> extraFacts = const {}}) {
    if (_leaving) return;
    _leaving = true;
    if (!widget.testTrack) {
      final o = _controller.sim.outcome;
      ref.read(progressProvider.notifier).applyRun(
        _course,
        RunOutcome(
          finished: false,
          boltsCollected: o.boltsCollected,
          boltsOnCourse: o.boltsOnCourse,
          falls: o.falls,
        ),
        {..._facts(), ...extraFacts},
      );
    } else if (extraFacts.isNotEmpty) {
      ref.read(progressProvider.notifier).addFacts(extraFacts);
    }
    context.go(route.path);
  }

  void _restart() {
    if (!widget.testTrack) {
      final o = _controller.sim.outcome;
      ref
          .read(progressProvider.notifier)
          .applyRun(
            _course,
            RunOutcome(
              finished: false,
              boltsCollected: o.boltsCollected,
              boltsOnCourse: o.boltsOnCourse,
              falls: o.falls,
            ),
            _facts(),
          );
    }
    _controller.restart(_startRobot);
  }

  /// RUN-13 step 3: the wrench opens the pit stop behind the robot, or the
  /// Workshop with the suggested part glowing (WRK-12).
  void _wrench() {
    final hint = _controller.hint;
    ref.read(audioProvider).sfx(Sfx.tap);
    if (_controller.pitStopBehind != null) {
      _controller.returnToPitStop();
      ref.read(progressProvider.notifier).addFacts({Fact.hint});
      return;
    }
    ref.read(suggestedPartProvider.notifier).set(hint?.suggestion?.id);
    _leave(AppRoute.workshop, extraFacts: {Fact.hint});
  }

  void _press() {
    if (TouchGuard.instance.palm) return;
    final hint = _controller.hint;
    if (hint != null && hint.step < 3) _controller.dismissHint();
    _controller.input(InputEvent.press);
  }

  /// RUN-13: tapping outside the bubble dismisses it; the tap still counts.
  void _maybeDismiss(PointerDownEvent e) {
    if (_controller.hint?.step != 3) return;
    final box = _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(e.position);
    if (!(Offset.zero & box.size).contains(local)) _controller.dismissHint();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = _controller.state;
    final parked = state.phase == RunPhase.parked;
    final hint = _controller.hint;
    final helper = _style == PlayStyle.little;
    final data = ref.watch(gameDataProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _maybeDismiss,
        child: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: _game)),
            if (_controller.previewing)
              // RUN-14: tap anywhere skips the preview.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _controller.skipPreview,
                ),
              ),
            // RUN-15: the jump zone is the right 40% below the HUD. In Helper
            // mode it is hidden and any tap is a happy hop (HLP-05).
            if (!_controller.previewing && !parked)
              Positioned(
                top: 96,
                bottom: 0,
                right: 0,
                width: MediaQuery.sizeOf(context).width * (helper ? 1 : 0.4),
                child: Semantics(
                  button: true,
                  label: l10n.jumpLabel,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => _press(),
                    onPointerUp: (_) => _controller.input(InputEvent.release),
                    onPointerCancel: (_) =>
                        _controller.input(InputEvent.release),
                    child: helper
                        ? const SizedBox.expand()
                        : Align(
                            alignment: const Alignment(0.3, 0.5),
                            child: _JumpIcon(
                              pulse: state.waitingForTap,
                            ),
                          ),
                  ),
                ),
              ),
            // HUD (RUN-07).
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.targetSpacing),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pause takes the Home button's place (HOM-06).
                    RoundIconButton(
                      icon: Icons.pause_rounded,
                      label: l10n.buttonPause,
                      onPressed: _controller.pause,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          if (!widget.testTrack)
                            ProgressTrack(course: _course, state: state),
                          if (state.fuelMax > 0)
                            FuelGauge(fuel: state.fuel, max: state.fuelMax),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (!widget.testTrack)
                      RunBolts(collected: state.collectedBolts.length),
                  ],
                ),
              ),
            ),
            if (state.waitingForTap)
              // ONB-02: a hand shows where to tap.
              Positioned(
                right: MediaQuery.sizeOf(context).width * 0.2,
                bottom: 40,
                child: const IgnorePointer(
                  child: Pulse(
                    child: Icon(
                      Icons.touch_app_rounded,
                      size: 72,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ),
            if (_showSpokenHint && hint != null && hint.step == 2)
              Positioned(
                left: MediaQuery.sizeOf(context).width * 0.3 + 40,
                top: 110,
                child: IgnorePointer(
                  child: _SpokenHint(
                    need: hint.need.need,
                    text: lookup(l10n, needHintKey(hint.need.need)),
                  ),
                ),
              ),
            if (hint != null && hint.step == 3 && !parked)
              Positioned(
                key: _bubbleKey,
                left: MediaQuery.sizeOf(context).width * 0.3 + 40,
                top: 110,
                child: HintBubble(
                  hint: hint,
                  robot: _controller.robot,
                  onWrench: _wrench,
                ),
              ),
            if (parked)
              Positioned.fill(
                child: PitStopPanel(
                  robot: _controller.robot,
                  catalog: data.catalog,
                  owned: profile.unlockedPartIds,
                  nextNeed: _controller.nextNeed,
                  glowPartId: hint?.suggestion?.id,
                  onSwap: (part) {
                    ref.read(audioProvider).sfx(Sfx.snap);
                    ref.read(hapticsProvider).light();
                    _controller.swapPart(part);
                  },
                  onGo: _controller.leavePitStop,
                ),
              ),
            if (_controller.paused)
              Positioned.fill(
                child: _PauseMenu(
                  collected: state.collectedBolts.length,
                  total: _course.bolts.length,
                  showBolts: !widget.testTrack,
                  soundOn: ref.watch(settingsProvider).sfx,
                  onResume: _controller.resume,
                  onRestart: _restart,
                  onWorkshop: () => _leave(AppRoute.workshop),
                  onMap: () => _leave(AppRoute.courseMap),
                  onHome: () => _leave(AppRoute.home),
                  onSound: () => ref
                      .read(settingsProvider.notifier)
                      .update(
                        (s) => s.copyWith(
                          sfx: !s.sfx,
                          music: !s.sfx,
                          voice: !s.sfx,
                        ),
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The voice clip key for a need's hint (RUN-13 step 2).
String needHintKey(Need need) {
  final name = need.name;
  return 'hint${name[0].toUpperCase()}${name.substring(1)}';
}

class _JumpIcon extends StatelessWidget {
  const _JumpIcon({required this.pulse});

  final bool pulse;

  @override
  Widget build(BuildContext context) {
    // The run's one primary action (DES-04): Sunny, Navy outline and
    // shadow, with its word under the icon (DES-09). The whole right 40% is
    // the jump zone; this only shows where it is (RUN-15).
    final icon = Container(
      width: AppSizes.jumpIcon,
      height: AppSizes.jumpIcon,
      decoration: BoxDecoration(
        color: AppColors.sunny,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.navy, width: AppSizes.outlineThick),
        boxShadow: const [
          BoxShadow(color: AppColors.navy, offset: Offset(0, AppSizes.shadow)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.arrow_upward_rounded,
            size: 52,
            color: AppColors.navy,
          ),
          // The jump zone already says "Jump" to VoiceOver (NFR-10).
          ExcludeSemantics(
            child: Text(
              AppLocalizations.of(context).jumpLabel,
              style: AppText.button,
            ),
          ),
        ],
      ),
    );
    return Pulse(active: pulse, circle: true, child: icon);
  }
}

class _SpokenHint extends StatelessWidget {
  const _SpokenHint({required this.need, required this.text});

  final Need need;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 300),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.navy, width: AppSizes.outline),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeedBadge(need: need, size: 44),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: AppText.body)),
      ],
    ),
  );
}

/// RUN-08: Resume (primary, 96 pt+), Restart and Workshop as large icon
/// buttons; Map, Home and sound as 64 pt buttons; bolts as icons. White
/// outlines on the dark scrim (DES-07).
class _PauseMenu extends StatelessWidget {
  const _PauseMenu({
    required this.collected,
    required this.total,
    required this.showBolts,
    required this.soundOn,
    required this.onResume,
    required this.onRestart,
    required this.onWorkshop,
    required this.onMap,
    required this.onHome,
    required this.onSound,
  });

  final int collected;
  final int total;
  final bool showBolts;
  final bool soundOn;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onWorkshop;
  final VoidCallback onMap;
  final VoidCallback onHome;
  final VoidCallback onSound;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget labelled(Widget button, String label) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 6),
        // The button already says its name to VoiceOver (NFR-10).
        ExcludeSemantics(
          child: Text(
            label,
            style: AppText.button.copyWith(color: AppColors.white),
          ),
        ),
      ],
    );
    return ColoredBox(
      color: AppColors.scrim,
      child: SafeArea(
        child: Stack(
          children: [
            // RUN-08: Home, sound and Map are the smaller 64 pt buttons.
            Positioned(
              left: AppSizes.targetSpacing,
              top: AppSizes.targetSpacing,
              child: RoundIconButton(
                icon: Icons.home_rounded,
                label: l10n.buttonHome,
                onDark: true,
                onPressed: onHome,
              ),
            ),
            Positioned(
              right: AppSizes.targetSpacing,
              top: AppSizes.targetSpacing,
              child: RoundIconButton(
                icon: soundOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: l10n.buttonSound,
                onDark: true,
                onPressed: onSound,
              ),
            ),
            Positioned(
              right: AppSizes.targetSpacing,
              bottom: AppSizes.targetSpacing,
              child: RoundIconButton(
                icon: Icons.map_rounded,
                label: l10n.buttonCourses,
                onDark: true,
                onPressed: onMap,
              ),
            ),
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.pausedTitle,
                      style: AppText.title.copyWith(color: AppColors.white),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        labelled(
                          RoundIconButton(
                            icon: Icons.replay_rounded,
                            label: l10n.buttonRestart,
                            size: 88,
                            onDark: true,
                            onPressed: onRestart,
                          ),
                          l10n.buttonRestart,
                        ),
                        const SizedBox(width: 24),
                        labelled(
                          RoundIconButton(
                            icon: Icons.play_arrow_rounded,
                            label: l10n.buttonResume,
                            size: 112,
                            primary: true,
                            onDark: true,
                            onPressed: onResume,
                          ),
                          l10n.buttonResume,
                        ),
                        const SizedBox(width: 24),
                        labelled(
                          RoundIconButton(
                            icon: Icons.build_rounded,
                            label: l10n.buttonWorkshop,
                            size: 88,
                            onDark: true,
                            onPressed: onWorkshop,
                          ),
                          l10n.buttonWorkshop,
                        ),
                      ],
                    ),
                    if (showBolts) ...[
                      const SizedBox(height: 16),
                      BoltRow(collected: collected, total: total),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
