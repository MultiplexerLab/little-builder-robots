import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:little_builder_robots/app/services.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/audio/audio_service.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/utils/touch_guard.dart';
import 'package:little_builder_robots/core/widgets/robot_painter.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/models/stats.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';

/// The icon for each need. Stat icons in the Workshop match the obstacle
/// icons in the run (WRK-04, RUN-12).
IconData needIcon(Need need) => switch (need) {
  Need.speed => Icons.speed_rounded,
  Need.climb => Icons.stairs_rounded,
  Need.jump => Icons.keyboard_double_arrow_up_rounded,
  Need.heavy || Need.light => Icons.fitness_center_rounded,
  Need.jetpack => Icons.rocket_launch_rounded,
  Need.grab => Icons.back_hand_rounded,
  Need.fan => Icons.air_rounded,
};

IconData statIcon(Stat stat) => switch (stat) {
  Stat.speed => needIcon(Need.speed),
  Stat.climb => needIcon(Need.climb),
  Stat.jump => needIcon(Need.jump),
  Stat.weight => needIcon(Need.heavy),
  Stat.fuel => Icons.local_gas_station_rounded,
};

IconData abilityIcon(Ability ability) => switch (ability) {
  Ability.jetpack => needIcon(Need.jetpack),
  Ability.grab => needIcon(Need.grab),
  Ability.fan => needIcon(Need.fan),
  Ability.mudproof => Icons.terrain_rounded,
};

/// A need's icon in a white circle. "Light" (mud) shows the weight icon
/// crossed out, so it reads without colour (DES-10).
class NeedBadge extends StatelessWidget {
  const NeedBadge({required this.need, this.size = 40, super.key});

  final Need need;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.white,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.navy, width: AppSizes.outline),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(needIcon(need), color: AppColors.navy, size: size * 0.6),
        if (need == Need.light)
          Transform.rotate(
            angle: -pi / 4,
            child: Container(
              width: size * 0.75,
              height: 3,
              color: AppColors.danger,
            ),
          ),
      ],
    ),
  );
}

/// 0 to 5 pips (WRK-04). Gained pips show an up arrow, lost pips are crossed
/// out with a down arrow (WRK-05, DES-10).
class Pips extends StatelessWidget {
  const Pips({
    required this.value,
    this.before,
    this.max = 5,
    this.size = 14,
    super.key,
  });

  final int value;

  /// The value before a change, to show gains and losses.
  final int? before;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    final was = before ?? value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _pip(
              i < value,
              i >= was && i < value,
              i >= value && i < was,
            ),
          ),
        if (value > was)
          Icon(
            Icons.arrow_upward_rounded,
            size: size + 6,
            color: AppColors.success,
          )
        else if (value < was)
          Icon(
            Icons.arrow_downward_rounded,
            size: size + 6,
            color: AppColors.danger,
          ),
      ],
    );
  }

  Widget _pip(bool filled, bool gained, bool lost) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: gained
          ? AppColors.mint
          : filled
          ? AppColors.navy
          : AppColors.white,
      border: Border.all(color: AppColors.navy, width: 2),
    ),
    child: lost
        ? Icon(Icons.close_rounded, size: size - 2, color: AppColors.danger)
        : null,
  );
}

/// The hexagon bolt icon (DES-12).
class BoltIcon extends StatelessWidget {
  const BoltIcon({this.size = 28, this.filled = true, super.key});

  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _BoltPainter(filled: filled),
  );
}

class _BoltPainter extends CustomPainter {
  const _BoltPainter({required this.filled});

  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final a = pi / 6 + i * pi / 3;
      final p = c + Offset(cos(a), sin(a)) * r;
      i == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
    }
    hex.close();
    canvas
      ..drawPath(
        hex,
        Paint()..color = filled ? AppColors.sunny : AppColors.white,
      )
      ..drawPath(
        hex,
        Paint()
          ..color = AppColors.navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      )
      ..drawCircle(
        c,
        r * 0.38,
        Paint()
          ..color = AppColors.navy
          ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_BoltPainter old) => old.filled != filled;
}

/// The read-only bolt counter: bolt icon and number in a white pill with a
/// Navy outline (DES-12, WRK-09). It shakes gently when [shake] changes
/// (WRK-11).
class BoltCounter extends StatelessWidget {
  const BoltCounter({required this.bolts, this.shake = 0, super.key});

  final int bolts;
  final int shake;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final pill = Semantics(
      label: AppLocalizations.of(context).boltsLabel(bolts),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.navy, width: AppSizes.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BoltIcon(),
            const SizedBox(width: 8),
            Text('$bolts', style: AppText.button),
          ],
        ),
      ),
    );
    if (reduce || shake == 0) return pill;
    return TweenAnimationBuilder<double>(
      key: ValueKey(shake),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(sin(t * pi * 4) * 6 * (1 - t), 0),
        child: child,
      ),
      child: pill,
    );
  }
}

/// A round icon button with a Navy outline (DES-04): 64 pt by default.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = AppSizes.childTarget,
    this.primary = false,
    this.locked = false,
    this.onDark = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final bool primary;

  /// Shows a padlock badge.
  final bool locked;

  /// White outline on dark overlays (DES-07).
  final bool onDark;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed == null
          ? null
          : () {
              if (TouchGuard.instance.allowNavigation()) onPressed!();
            },
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: primary ? AppColors.sunny : AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: onDark ? AppColors.white : AppColors.navy,
                  width: primary ? AppSizes.outlineThick : AppSizes.outline,
                ),
                boxShadow: [
                  if (primary)
                    const BoxShadow(
                      color: AppColors.navy,
                      offset: Offset(0, AppSizes.shadow),
                    ),
                ],
              ),
              child: Center(
                child: Icon(icon, color: AppColors.navy, size: size * 0.5),
              ),
            ),
            if (locked)
              const Positioned(
                right: -4,
                bottom: -4,
                child: _LockBadge(),
              ),
          ],
        ),
      ),
    ),
  );
}

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: AppColors.cloud,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.navy, width: 2),
    ),
    child: const Icon(Icons.lock_rounded, size: 16, color: AppColors.navy),
  );
}

/// Plays a voice clip again (MAP-08: 64 pt).
class ReplayVoiceButton extends ConsumerWidget {
  const ReplayVoiceButton({required this.voiceKey, super.key});

  final String voiceKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RoundIconButton(
    icon: Icons.volume_up_rounded,
    label: AppLocalizations.of(context).buttonReplay,
    onPressed: () => ref.read(audioProvider).voice(voiceKey),
  );
}

/// Round 64 pt Home button, always top left on child screens (HOM-06).
class HomeButton extends ConsumerWidget {
  const HomeButton({this.onPressed, super.key});

  /// Defaults to going Home.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RoundIconButton(
    icon: Icons.home_rounded,
    label: AppLocalizations.of(context).buttonHome,
    onPressed: () {
      ref.read(audioProvider).sfx(Sfx.tap);
      if (onPressed != null) {
        onPressed!();
      } else {
        context.go('/home');
      }
    },
  );
}

/// A child screen: Sky background, safe area, Home button top left
/// (HOM-06) and optional widgets top right.
class ChildScaffold extends StatelessWidget {
  const ChildScaffold({
    required this.body,
    this.showHome = true,
    this.topRight,
    this.background = AppColors.sky,
    super.key,
  });

  final Widget body;
  final bool showHome;
  final Widget? topRight;
  final Color background;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    body: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(child: body),
          if (showHome)
            const Positioned(
              left: AppSizes.targetSpacing,
              top: AppSizes.targetSpacing,
              child: HomeButton(),
            ),
          if (topRight != null)
            Positioned(
              right: AppSizes.targetSpacing,
              top: AppSizes.targetSpacing,
              child: topRight!,
            ),
        ],
      ),
    ),
  );
}

/// The robot as a widget, gently bobbing while idle (HOM-05). Reduce Motion
/// keeps it still (NFR-11).
class RobotView extends StatefulWidget {
  const RobotView({
    required this.config,
    this.size = 160,
    this.face = RobotFace.happy,
    this.armsUp = false,
    this.bob = true,
    this.backdrop = false,
    super.key,
  });

  final RobotConfig config;
  final double size;
  final RobotFace face;
  final bool armsUp;
  final bool bob;

  /// A Sky disc behind the robot, so its Navy outlines show on dark
  /// screens (splash, rest).
  final bool backdrop;

  @override
  State<RobotView> createState() => _RobotViewState();
}

class _RobotViewState extends State<RobotView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context) || !widget.bob;
    if (still) {
      _bob.stop();
    } else if (!_bob.isAnimating) {
      unawaited(_bob.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.size;
    final width = height * RobotArt.width / RobotArt.height;
    final robot = AnimatedBuilder(
      animation: _bob,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, -4 * Curves.easeInOut.transform(_bob.value)),
        child: CustomPaint(
          size: Size(width, height),
          painter: RobotPainter(
            RobotLook(widget.config, face: widget.face, armsUp: widget.armsUp),
          ),
        ),
      ),
    );
    if (!widget.backdrop) return robot;
    return Container(
      width: height * 1.25,
      height: height * 1.25,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.sky,
        shape: BoxShape.circle,
      ),
      child: robot,
    );
  }
}

/// A pulsing glow around [child] (WRK-12, MAP-02 next node). Still with
/// Reduce Motion.
class Pulse extends StatefulWidget {
  const Pulse({
    required this.child,
    this.active = true,
    this.circle = false,
    super.key,
  });

  final Widget child;
  final bool active;

  /// Glow in a circle, for round buttons and map nodes.
  final bool circle;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.active && !MediaQuery.disableAnimationsOf(context);
    if (run && !_c.isAnimating) {
      unawaited(_c.repeat(reverse: true));
    } else if (!run) {
      _c
        ..stop()
        ..value = widget.active ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => DecoratedBox(
      decoration: BoxDecoration(
        shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: widget.circle ? null : BorderRadius.circular(28),
        boxShadow: [
          if (widget.active)
            BoxShadow(
              color: AppColors.sunny.withValues(alpha: 0.4 + 0.5 * _c.value),
              blurRadius: 8 + 10 * _c.value,
              spreadRadius: 2 + 4 * _c.value,
            ),
        ],
      ),
      child: child,
    ),
    child: widget.child,
  );
}
