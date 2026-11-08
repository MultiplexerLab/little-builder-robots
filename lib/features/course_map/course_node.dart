import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';

enum NodeState { done, next, locked }

/// A map node (MAP-02): state shown by shape as well as colour. Done shows
/// 1 to 3 stars, filled or outlined; next is 96 pt, highlighted, with the
/// robot bouncing on it; locked is dashed with a padlock.
class CourseNode extends StatelessWidget {
  const CourseNode({
    required this.number,
    required this.stars,
    required this.state,
    required this.onTap,
    this.robot,
    this.gear,
    super.key,
  });

  /// The square every node is centred in.
  static const double slot = AppSizes.childPrimary;

  final int number;
  final int stars;
  final NodeState state;
  final VoidCallback onTap;

  /// Shown on the next node.
  final RobotConfig? robot;

  /// The golden gear: found (true), still hidden (false), or not shown.
  final bool? gear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final big = state == NodeState.next;
    final size = big ? AppSizes.childPrimary : AppSizes.childTarget;
    final circle = CustomPaint(
      painter: _NodePainter(state: state),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: state == NodeState.locked
              ? const Icon(Icons.lock_rounded, color: AppColors.navy, size: 28)
              : Text('$number', style: big ? AppText.title : AppText.button),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: l10n.courseNodeLabel(number, stars),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox.square(
          dimension: slot,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (big) Pulse(circle: true, child: circle) else circle,
              if (state == NodeState.done || (big && stars > 0))
                Positioned(
                  bottom: big ? -6 : 4,
                  child: Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Icon(
                          i < stars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 22,
                          color: i < stars ? AppColors.sunny : AppColors.navy,
                          shadows: const [
                            Shadow(color: AppColors.navy, blurRadius: 1),
                          ],
                        ),
                    ],
                  ),
                ),
              if (gear != null)
                Positioned(
                  right: 2,
                  top: 2,
                  child: GearBadge(found: gear!, size: 26),
                ),
              if (robot != null)
                // Beside the node, so it never covers the course before.
                Positioned(
                  left: -44,
                  bottom: 4,
                  child: _Bounce(
                    child: RobotView(config: robot!, size: 56, bob: false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodePainter extends CustomPainter {
  const _NodePainter({required this.state});

  final NodeState state;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = switch (state) {
          NodeState.done => AppColors.white,
          NodeState.next => AppColors.sunny,
          NodeState.locked => AppColors.cloud,
        },
    );
    final stroke = Paint()
      ..color = AppColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = state == NodeState.next ? 4 : 3;
    if (state != NodeState.locked) {
      canvas.drawCircle(c, r, stroke);
      return;
    }
    const dashes = 16;
    for (var i = 0; i < dashes; i++) {
      final a = i * 2 * pi / dashes;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a,
        pi / dashes,
        false,
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_NodePainter old) => old.state != state;
}

/// The robot marker bounces on the next node (MAP-02), still with Reduce
/// Motion.
class _Bounce extends StatefulWidget {
  const _Bounce({required this.child});

  final Widget child;

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      unawaited(_c.repeat(reverse: true));
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
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -10 * Curves.easeOut.transform(_c.value)),
      child: child,
    ),
    child: widget.child,
  );
}
