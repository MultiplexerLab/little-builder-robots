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
import 'package:little_builder_robots/features/parent_gate/parent_gate_screen.dart';

/// Home (HOM-02 to HOM-05).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  /// HOM-02: hesitation before the buttons say their names.
  static const idleHint = Duration(seconds: 5);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _idle;
  bool _cheer = false;
  bool _hinting = false;

  @override
  void initState() {
    super.initState();
    final audio = ref.read(audioProvider);
    unawaited(audio.music(MusicGroup.menus));
    unawaited(audio.voice('homeGreeting'));
    _restartIdle();
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  void _restartIdle() {
    _idle?.cancel();
    _idle = Timer(HomeScreen.idleHint, () {
      if (!mounted) return;
      setState(() => _hinting = true);
      unawaited(ref.read(audioProvider).voice('homeIdlePlay'));
    });
  }

  void _tapRobot() {
    _restartIdle();
    ref.read(audioProvider).sfx(Sfx.honk);
    ref.read(hapticsProvider).light();
    setState(() => _cheer = true);
    Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _cheer = false);
    });
  }

  void _play() {
    final data = ref.read(gameDataProvider);
    final next = SelectedCourseController.nextCourse(
      data.courses,
      ref.read(profileProvider),
    );
    ref.read(selectedCourseProvider.notifier).select(next.id);
    context.go(AppRoute.workshop.path);
  }

  Future<void> _grownUps() async {
    if (await askParentGate(context)) {
      if (mounted) context.go(AppRoute.grownUps.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider);
    final testTrackOpen = ref
        .watch(testTrackBuilderProvider)
        .isUnlocked(profile);
    final audio = ref.read(audioProvider);

    return ChildScaffold(
      showHome: false,
      // HOM-04: 48 pt gear, top right, away from the child buttons.
      topRight: Semantics(
        button: true,
        label: l10n.buttonGrownUps,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: _grownUps,
          child: Container(
            width: AppSizes.grownUpsTarget,
            height: AppSizes.grownUpsTarget,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.navy,
                width: AppSizes.outline,
              ),
            ),
            child: const Icon(Icons.settings_outlined, color: AppColors.navy),
          ),
        ),
      ),
      body: Listener(
        onPointerDown: (_) {
          _restartIdle();
          if (_hinting) setState(() => _hinting = false);
        },
        child: LayoutBuilder(
          builder: (context, box) {
            final ground = box.maxHeight * 0.2;
            final robotSize = (box.maxHeight * 0.5).clamp(110.0, 260.0);
            final buttons = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.appTitle, style: AppText.title),
                const SizedBox(height: 12),
                Pulse(
                  active: _hinting,
                  child: ChunkyButton(
                    label: l10n.buttonPlay,
                    icon: Icons.play_arrow_rounded,
                    style: ChunkyButtonStyle.primary,
                    onPressed: _play,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: AppSizes.targetSpacing * 2,
                  runSpacing: AppSizes.targetSpacing,
                  children: [
                    _LabelledButton(
                      icon: Icons.map_rounded,
                      label: l10n.buttonCourses,
                      onPressed: () => context.go(AppRoute.courseMap.path),
                    ),
                    _LabelledButton(
                      icon: Icons.route_rounded,
                      label: l10n.buttonTestTrack,
                      locked: !testTrackOpen,
                      onPressed: () {
                        if (testTrackOpen) {
                          context.go(AppRoute.testTrack.path);
                        } else {
                          // TRK-01: says when it opens.
                          audio.sfx(Sfx.shake);
                          unawaited(audio.voice('testTrackLocked'));
                        }
                      },
                    ),
                    _LabelledButton(
                      icon: Icons.menu_book_rounded,
                      label: l10n.buttonStickers,
                      onPressed: () => context.go(AppRoute.stickerBook.path),
                    ),
                  ],
                ),
              ],
            );
            return Stack(
              children: [
                // Grass for the robot to stand on, as in the mockup.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: ground,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.grass,
                      border: Border(
                        top: BorderSide(
                          color: AppColors.navy,
                          width: AppSizes.outline,
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Padding(
                        // Above the grass, clear of the ground line.
                        padding: EdgeInsets.only(left: 24, bottom: ground),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: buttons,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: ground - 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _SpeechBubble(text: l10n.homeGreeting),
                            const SizedBox(height: 8),
                            Semantics(
                              button: true,
                              label: l10n.robotLabel,
                              child: GestureDetector(
                                onTap: _tapRobot,
                                child: RobotView(
                                  config: profile.robot,
                                  size: robotSize,
                                  face: _cheer
                                      ? RobotFace.cheer
                                      : RobotFace.happy,
                                  armsUp: _cheer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A 64 pt+ round button with its name under it, paired with an icon
/// (DES-09).
class _LabelledButton extends StatelessWidget {
  const _LabelledButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool locked;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      RoundIconButton(
        icon: icon,
        label: label,
        size: 72,
        locked: locked,
        onPressed: onPressed,
      ),
      const SizedBox(height: 4),
      // The button already says its name to VoiceOver (NFR-10).
      ExcludeSemantics(child: Text(label, style: AppText.label)),
    ],
  );
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.navy, width: AppSizes.outline),
    ),
    child: Text(text, style: AppText.button),
  );
}
