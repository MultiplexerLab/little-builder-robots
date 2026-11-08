import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:little_builder_robots/core/widgets/robot_painter.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';

/// A little show the robot puts on, so a child sees straight away what a
/// part does (cause and effect, PAR-08).
enum Trick { zoom, march, boing, liftOff, rumble, thud, wave, spin, hop }

/// The trick that shows off [partId]: Wheels zoom, Legs march, Spring feet
/// boing, the Jetpack lifts off, and so on. Style-only changes spin.
Trick trickFor(String partId) => switch (partId) {
  'moves_wheels' => Trick.zoom,
  'moves_legs' => Trick.march,
  'moves_spring_feet' => Trick.boing,
  'moves_jetpack' => Trick.liftOff,
  'moves_tank_tracks' => Trick.rumble,
  'body_heavy_frame' => Trick.thud,
  'body_battery' || 'body_light_frame' => Trick.hop,
  'arms_short' || 'arms_grabber' || 'arms_fan' => Trick.wave,
  _ => Trick.spin,
};

/// Draws the robot and plays [trick] once each time [play] changes. Still
/// with Reduce Motion (NFR-11).
class RobotShowOff extends StatefulWidget {
  const RobotShowOff({
    required this.config,
    required this.trick,
    required this.play,
    this.size = 120,
    this.face = RobotFace.happy,
    super.key,
  });

  final RobotConfig config;
  final Trick trick;

  /// Bump this to play the trick again.
  final int play;
  final double size;
  final RobotFace face;

  static const duration = Duration(milliseconds: 1100);

  @override
  State<RobotShowOff> createState() => _RobotShowOffState();
}

class _RobotShowOffState extends State<RobotShowOff>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: RobotShowOff.duration,
  );

  @override
  void didUpdateWidget(RobotShowOff old) {
    super.didUpdateWidget(old);
    if (old.play != widget.play && !MediaQuery.disableAnimationsOf(context)) {
      unawaited(_c.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.size;
    final width = height * RobotArt.width / RobotArt.height;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final playing = _c.isAnimating;
        final pose = playing ? _pose(widget.trick, t, height) : const _Pose();
        return Transform.translate(
          offset: Offset(pose.dx, pose.dy),
          child: Transform.rotate(
            angle: pose.angle,
            alignment: Alignment.bottomCenter,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(pose.sx, pose.sy, 1),
              child: CustomPaint(
                size: Size(width, height),
                painter: RobotPainter(
                  RobotLook(
                    widget.config,
                    face: playing ? RobotFace.cheer : widget.face,
                    armsUp: pose.armsUp,
                    flame: pose.flame,
                    wheelTurn: pose.wheelTurn,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Where the robot is [t] (0..1) of the way through [trick].
  static _Pose _pose(Trick trick, double t, double size) {
    final fade = 1 - t; // every trick settles back to rest
    switch (trick) {
      case Trick.zoom:
        final x = sin(t * 2 * pi) * size * 0.35 * fade;
        return _Pose(
          dx: x,
          angle: cos(t * 2 * pi) * 0.12 * fade,
          wheelTurn: t * 4,
        );
      case Trick.march:
        final step = sin(t * 6 * pi).abs();
        return _Pose(dy: -step * size * 0.06, angle: sin(t * 6 * pi) * 0.06);
      case Trick.boing:
        final h = sin(t * 2 * pi).abs() * fade;
        final squash = t < 0.08 || (t > 0.45 && t < 0.58) ? 0.18 : 0.0;
        return _Pose(
          dy: -h * size * 0.45,
          sx: 1 + squash,
          sy: 1 - squash + (h > 0.2 ? 0.08 : 0),
        );
      case Trick.liftOff:
        final up = sin(t * pi);
        return _Pose(dy: -up * size * 0.4, flame: t < 0.8);
      case Trick.rumble:
        return _Pose(dx: sin(t * 60) * 3 * fade, wheelTurn: t * 2);
      case Trick.thud:
        final squash = t < 0.3 ? sin(t / 0.3 * pi) * 0.22 : 0.0;
        return _Pose(
          sx: 1 + squash,
          sy: 1 - squash,
          dx: sin(t * 50) * 2 * fade,
        );
      case Trick.wave:
        return _Pose(
          armsUp: (t * 6).floor().isEven,
          angle: sin(t * 4 * pi) * 0.05,
        );
      case Trick.spin:
        return _Pose(sx: cos(t * 2 * pi), dy: -sin(t * pi) * size * 0.12);
      case Trick.hop:
        return _Pose(dy: -sin(t * 2 * pi).abs() * size * 0.15 * fade);
    }
  }
}

class _Pose {
  const _Pose({
    this.dx = 0,
    this.dy = 0,
    this.angle = 0,
    this.sx = 1,
    this.sy = 1,
    this.armsUp = false,
    this.flame = false,
    this.wheelTurn = 0,
  });

  final double dx;
  final double dy;
  final double angle;
  final double sx;
  final double sy;
  final bool armsUp;
  final bool flame;
  final double wheelTurn;
}
