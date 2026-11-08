import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/router.dart';
import 'package:little_builder_robots/app/services.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';

/// Splash (HOM-01): at most 2 s, no buttons, then First-run setup on the
/// first launch, the rest screen if today's time is up (PAR-07), or Home.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const duration = Duration(milliseconds: 1500);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen.duration, () {
      if (!mounted) return;
      final settings = ref.read(settingsProvider);
      final route = !settings.onboardingDone
          ? AppRoute.firstRun
          : ref.read(playLimitProvider).reached
          ? AppRoute.rest
          : AppRoute.home;
      context.go(route.path);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final robot = ref.watch(profileProvider).robot;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RobotView(config: robot, size: 120, backdrop: true),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).appTitle,
              style: AppText.display.copyWith(color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}
