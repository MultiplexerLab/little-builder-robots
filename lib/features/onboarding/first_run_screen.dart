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
import 'package:little_builder_robots/core/utils/touch_guard.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/models/settings.dart';

/// First-run setup (ONB-01): a voiced "For grown-ups" card asking who is
/// playing. Only the play style is stored; no age, name or birthday.
class FirstRunScreen extends ConsumerStatefulWidget {
  const FirstRunScreen({super.key});

  @override
  ConsumerState<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends ConsumerState<FirstRunScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(audioProvider).voice('firstRunQuestion'));
  }

  void _choose(PlayStyle style) {
    ref.read(audioProvider).sfx(Sfx.cheer);
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(playStyle: style, onboardingDone: true));
    context.go(AppRoute.home.path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final robot = ref.watch(profileProvider).robot;
    return ChildScaffold(
      showHome: false,
      body: Center(
        // Child screens never scroll (NFR-19): on a short screen the card
        // shrinks so the whole card, heading included, stays in view.
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.targetSpacing),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: AppColors.navy,
                  width: AppSizes.outline,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.family_restroom_rounded,
                        color: AppColors.navy,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.firstRunTitle, style: AppText.label),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          l10n.firstRunQuestion,
                          style: AppText.title,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const ReplayVoiceButton(voiceKey: 'firstRunQuestion'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      _StyleCard(
                        label: l10n.playStyleLittle,
                        ages: l10n.playStyleLittleAges,
                        robotSize: 90,
                        robot: robot,
                        onTap: () => _choose(PlayStyle.little),
                      ),
                      _StyleCard(
                        label: l10n.playStyleBig,
                        ages: l10n.playStyleBigAges,
                        robotSize: 120,
                        robot: robot,
                        onTap: () => _choose(PlayStyle.big),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.firstRunNote,
                    style: AppText.label,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A large picture button for one play style (ONB-01).
class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.label,
    required this.ages,
    required this.robotSize,
    required this.robot,
    required this.onTap,
  });

  final String label;
  final String ages;
  final double robotSize;
  final RobotConfig robot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label, $ages',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: () {
        if (TouchGuard.instance.allowNavigation()) onTap();
      },
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.sunnyPale,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.navy,
            width: AppSizes.outlineThick,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 130,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: RobotView(config: robot, size: robotSize, bob: false),
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: AppText.button),
            Text(ages, style: AppText.body),
          ],
        ),
      ),
    ),
  );
}
