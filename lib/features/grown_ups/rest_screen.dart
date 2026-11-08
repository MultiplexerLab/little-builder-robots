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
import 'package:little_builder_robots/core/utils/play_clock.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/core/widgets/robot_painter.dart';
import 'package:little_builder_robots/features/parent_gate/parent_gate_screen.dart';

/// Rest time (PAR-07, PAR-11): the robot plugs itself in and falls asleep.
/// Play stays locked until tomorrow, or until a grown-up passes the gate
/// and gives 10 more minutes or turns the limit off.
class RestScreen extends ConsumerStatefulWidget {
  const RestScreen({super.key});

  @override
  ConsumerState<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends ConsumerState<RestScreen> {
  @override
  void initState() {
    super.initState();
    final audio = ref.read(audioProvider)..sfx(Sfx.yawn);
    unawaited(audio.voice('restMessage'));
  }

  Future<void> _grownUp(void Function() action) async {
    if (!await askParentGate(context)) return;
    ref.read(gatePassedProvider.notifier).set(false);
    action();
    if (mounted) context.go(AppRoute.home.path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final robot = ref.watch(profileProvider).robot;
    return ChildScaffold(
      showHome: false,
      background: AppColors.navy,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RobotView(
                    config: robot,
                    size: 130,
                    face: RobotFace.sleep,
                    bob: false,
                    backdrop: true,
                  ),
                  const Icon(
                    Icons.power_rounded,
                    color: AppColors.sunny,
                    size: 48,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bedtime_rounded,
                    color: AppColors.sunny,
                    size: 40,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.restMessage,
                      style: AppText.title.copyWith(color: AppColors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const ReplayVoiceButton(voiceKey: 'restMessage'),
                ],
              ),
              const SizedBox(height: 32),
              // Grown-up actions, small and behind the gate (PAR-07).
              Theme(
                data: AppTheme.grownUps(),
                child: Wrap(
                  spacing: 16,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.white,
                        minimumSize: const Size(0, AppSizes.grownUpsTarget),
                      ),
                      icon: const Icon(Icons.more_time_rounded),
                      label: Text(l10n.restMoreTime),
                      onPressed: () => _grownUp(
                        () => ref
                            .read(progressProvider.notifier)
                            .addBonusSeconds(dayKey(DateTime.now()), 10 * 60),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.white,
                        minimumSize: const Size(0, AppSizes.grownUpsTarget),
                      ),
                      icon: const Icon(Icons.timer_off_outlined),
                      label: Text(l10n.restTurnOff),
                      onPressed: () => _grownUp(
                        () => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(dailyLimitMinutes: 0)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
