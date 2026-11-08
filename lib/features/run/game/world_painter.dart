import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart'
    show IconData, Icons, TextDirection, TextPainter, TextSpan, TextStyle;
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart'
    show needIcon;
import 'package:little_builder_robots/core/widgets/robot_painter.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';
import 'package:little_builder_robots/domain/sim/terrain.dart';
import 'package:little_builder_robots/features/run/run_controller.dart';

/// Draws the run from [RunController] state (Flame renders, the simulator
/// decides; SRS 7). World units are px with y up from ground level 0.
class WorldPainter {
  WorldPainter(this.controller)
    : terrain = Terrain.fromCourse(controller.course),
      needs = [
        for (var i = 0; i < controller.course.obstacles.length; i++)
          controller.coach.needFor(controller.course, i),
      ];

  final RunController controller;
  final Terrain terrain;
  final List<ObstacleNeed> needs;

  /// How much of the world fits the screen height.
  static const worldHeight = 430.0;

  /// The robot sits this far across the screen.
  static const robotScreenX = 0.3;

  double _clock = 0;

  void tick(double dt) => _clock += dt;

  Course get _course => controller.course;

  void paint(Canvas canvas, Size size) {
    final scale = size.height / worldHeight;
    final groundY = size.height * 0.8;
    final s = controller.state;
    final p = controller.previous;
    final a = controller.alpha.clamp(0.0, 1.0);
    final robotX = p.x + (s.x - p.x) * a;
    final robotY = p.y + (s.y - p.y) * a;

    var cameraX = robotX;
    if (controller.previewing) {
      // RUN-14: pan out to the main obstacle and back.
      final t = sin(controller.previewProgress * pi);
      cameraX = robotX + (controller.previewTargetX - robotX + 200) * t;
    }
    final originX = size.width * robotScreenX - cameraX * scale;
    double sx(double x) => originX + x * scale;
    double sy(double y) => groundY - y * scale;
    final left = cameraX - size.width * robotScreenX / scale - 100;
    final right = left + size.width / scale + 200;

    _sky(canvas, size, cameraX);
    _ground(canvas, size, sx, sy, left, right);
    _obstacles(canvas, size, sx, sy, scale, left, right, robotX);
    _checkpoints(canvas, sx, sy, scale, left, right);
    _bolts(canvas, sx, sy, scale, left, right);
    _flag(canvas, sx, sy, scale);
    _robot(canvas, sx(robotX), sy(robotY), scale, s);
  }

  void _sky(Canvas canvas, Size size, double cameraX) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.sky);
    final cloud = Paint()..color = AppColors.white;
    for (var i = 0; i < 6; i++) {
      final x = (i * 260 - cameraX * 0.2) % (size.width + 300) - 150;
      final y = 40.0 + (i * 53) % 90;
      canvas
        ..drawCircle(Offset(x, y), 26, cloud)
        ..drawCircle(Offset(x + 28, y + 6), 20, cloud)
        ..drawCircle(Offset(x - 26, y + 8), 18, cloud);
    }
  }

  void _ground(
    Canvas canvas,
    Size size,
    double Function(double) sx,
    double Function(double) sy,
    double left,
    double right,
  ) {
    final outline = Paint()
      ..color = AppColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final seg in terrain.segments) {
      if (seg.end < left || seg.start > right) continue;
      final x0 = sx(max(seg.start, left));
      final x1 = sx(min(seg.end, right));
      final height = seg.height;
      if (height == null) {
        final water = _course.obstacles.any(
          (o) => o is GapObstacle && o.water && o.x == seg.start,
        );
        if (water) {
          canvas.drawRect(
            Rect.fromLTRB(x0, sy(-40), x1, size.height),
            Paint()..color = AppColors.roboBlue,
          );
        }
        if (seg.bar) {
          final barY = sy(_barHeight);
          canvas
            ..drawLine(
              Offset(x0, barY),
              Offset(x1, barY),
              Paint()
                ..color = AppColors.navy
                ..strokeWidth = 8
                ..strokeCap = StrokeCap.round,
            )
            ..drawLine(
              Offset(x0, barY),
              Offset(x1, barY),
              Paint()
                ..color = AppColors.cloud
                ..strokeWidth = 3,
            );
        }
        continue;
      }
      final top = sy(height);
      canvas
        ..drawRect(
          Rect.fromLTRB(x0, top, x1, size.height),
          Paint()..color = height > 0 ? AppColors.cloud : AppColors.grass,
        )
        ..drawRect(
          Rect.fromLTRB(x0, top, x1, top + 10),
          Paint()..color = AppColors.grass,
        )
        ..drawLine(Offset(x0, top), Offset(x1, top), outline);
      // Walls at the segment ends.
      for (final x in [seg.start, seg.end]) {
        if (x >= left && x <= right && x.isFinite) {
          canvas.drawLine(
            Offset(sx(x), top),
            Offset(sx(x), size.height),
            outline,
          );
        }
      }
    }
  }

  /// Bars hang just above the robot's head.
  static const _barHeight = 78.0;

  void _obstacles(
    Canvas canvas,
    Size size,
    double Function(double) sx,
    double Function(double) sy,
    double scale,
    double left,
    double right,
    double robotX,
  ) {
    final s = controller.state;
    final outline = Paint()
      ..color = AppColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final (i, o) in _course.obstacles.indexed) {
      if (o.end < left || o.start > right) continue;
      switch (o) {
        case TimedGateObstacle(:final plateX, :final x, :final openSeconds):
          _plate(canvas, sx(plateX), sy(0), scale);
          final left = s.openGates[i];
          _door(canvas, sx(x), sy(0), scale, open: left != null);
          if (left != null) {
            // SRS 4.3: a shrinking light ring shows the time left.
            canvas.drawArc(
              Rect.fromCircle(
                center: Offset(sx(x), sy(190)),
                radius: 18 * scale * 2,
              ),
              -pi / 2,
              2 * pi * (left / openSeconds),
              false,
              Paint()
                ..color = AppColors.sunny
                ..style = PaintingStyle.stroke
                ..strokeWidth = 8,
            );
          }
        case HeavySwitchObstacle(:final plateX, :final x):
          _plate(canvas, sx(plateX), sy(0), scale, heavy: true);
          _door(canvas, sx(x), sy(0), scale, open: s.openDoors.contains(i));
        case MudObstacle(:final x, :final width):
          final r = Rect.fromLTRB(sx(x), sy(6), sx(x + width), sy(-24));
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(12)),
            Paint()..color = AppColors.navy.withValues(alpha: 0.55),
          );
          for (var b = x + 30; b < x + width; b += 70) {
            canvas.drawCircle(
              Offset(sx(b), sy(-6)),
              5 * scale * 2,
              Paint()..color = AppColors.cloud.withValues(alpha: 0.6),
            );
          }
        case LeafPileObstacle(:final x, :final width, :final height)
            when !s.clearedLeaves.contains(i):
          final pile = Path()
            ..moveTo(sx(x - 10), sy(0))
            ..quadraticBezierTo(
              sx(x + width / 2),
              sy(height * 1.6),
              sx(x + width + 10),
              sy(0),
            )
            ..close();
          canvas
            ..drawPath(pile, Paint()..color = AppColors.tangerine)
            ..drawPath(pile, outline);
          for (var k = 0; k < 6; k++) {
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset(
                  sx(x + width * (k / 5)),
                  sy(height * (0.2 + (k % 3) * 0.25)),
                ),
                width: 14 * scale * 2,
                height: 8 * scale * 2,
              ),
              Paint()..color = AppColors.grass,
            );
          }
        case LowCeilingObstacle(:final x, :final width, :final height):
          final r = Rect.fromLTRB(sx(x), 0, sx(x + width), sy(height));
          canvas
            ..drawRect(r, Paint()..color = AppColors.cloud)
            ..drawLine(r.bottomLeft, r.bottomRight, outline..strokeWidth = 4);
          outline.strokeWidth = 3;
        case RampObstacle(:final x, :final width):
          final ramp = Path()
            ..moveTo(sx(x), sy(0))
            ..lineTo(sx(x + width), sy(28))
            ..lineTo(sx(x + width), sy(0))
            ..close();
          canvas
            ..drawPath(ramp, Paint()..color = AppColors.tangerine)
            ..drawPath(ramp, outline);
        default:
          break;
      }
      _needSign(canvas, i, sx, sy, scale, robotX);
    }
  }

  /// RUN-12: the obstacle's need icon and pips, pulsing as the robot comes
  /// near.
  void _needSign(
    Canvas canvas,
    int i,
    double Function(double) sx,
    double Function(double) sy,
    double scale,
    double robotX,
  ) {
    final o = _course.obstacles[i];
    if (o is GapObstacle && i > 0 && _course.obstacles[i - 1] is RampObstacle) {
      return; // the ramp shows it
    }
    final need = needs[i];
    final top = switch (o) {
      StepsObstacle(:final stepHeights) => stepHeights.fold<double>(
        0,
        (a, b) => a + b,
      ),
      LeafPileObstacle(:final height) ||
      LowCeilingObstacle(:final height) => height,
      _ => 160.0,
    };
    final near = (o.start - robotX).abs() < 350;
    final pulse = near ? 1 + 0.12 * sin(_clock * 8) : 1.0;
    final r = 22 * scale * 1.6 * pulse;
    final c = Offset(sx(o.start + 20), sy(top + 70));
    canvas
      ..drawCircle(c, r, Paint()..color = AppColors.white)
      ..drawCircle(
        c,
        r,
        Paint()
          ..color = AppColors.navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    _icon(canvas, needIcon(need.need), c, r * 1.2);
    if (need.need == Need.light) {
      canvas.drawLine(
        c + Offset(-r * 0.7, r * 0.7),
        c + Offset(r * 0.7, -r * 0.7),
        Paint()
          ..color = AppColors.danger
          ..strokeWidth = 4,
      );
    }
    for (var k = 0; k < need.pips; k++) {
      final pc = c + Offset((k - (need.pips - 1) / 2) * r * 0.55, r + 10);
      canvas
        ..drawCircle(pc, r * 0.2, Paint()..color = AppColors.navy)
        ..drawCircle(
          pc,
          r * 0.2,
          Paint()
            ..color = AppColors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
    }
  }

  void _plate(
    Canvas canvas,
    double x,
    double y,
    double scale, {
    bool heavy = false,
  }) {
    final r = Rect.fromCenter(
      center: Offset(x, y - 4),
      width: (heavy ? 60 : 44) * scale * 1.6,
      height: 10,
    );
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        Paint()..color = heavy ? AppColors.tangerine : AppColors.sunny,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        Paint()
          ..color = AppColors.navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  void _door(
    Canvas canvas,
    double x,
    double y,
    double scale, {
    required bool open,
  }) {
    final height = 170 * scale;
    final post = Paint()..color = AppColors.navy;
    canvas.drawRect(
      Rect.fromLTWH(x - 4, y - height - 20 * scale, 8, height + 20 * scale),
      post,
    );
    final doorTop = open ? y - height - 10 * scale : y - height;
    final doorBottom = open ? y - height * 0.85 : y;
    final door = Rect.fromLTRB(
      x - 14 * scale * 1.4,
      doorTop,
      x + 14 * scale * 1.4,
      doorBottom,
    );
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(door, const Radius.circular(6)),
        Paint()..color = AppColors.tangerine,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(door, const Radius.circular(6)),
        Paint()
          ..color = AppColors.navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
  }

  void _checkpoints(
    Canvas canvas,
    double Function(double) sx,
    double Function(double) sy,
    double scale,
    double left,
    double right,
  ) {
    for (final (i, cp) in _course.checkpoints.indexed) {
      if (i == 0 || cp.x < left || cp.x > right) continue;
      final base = Offset(sx(cp.x), sy(0));
      if (cp.pitStop) {
        // RUN-11: a garage pad.
        final pad = Rect.fromCenter(
          center: base + const Offset(0, -3),
          width: 90 * scale * 1.6,
          height: 10,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(pad, const Radius.circular(4)),
          Paint()..color = AppColors.sunny,
        );
        _icon(
          canvas,
          Icons.build_rounded,
          base + Offset(0, -110 * scale),
          36 * scale * 1.6,
        );
      }
      final pole = Paint()
        ..color = AppColors.navy
        ..strokeWidth = 4;
      final top = base + Offset(-40 * scale, -100 * scale);
      canvas
        ..drawLine(base + Offset(-40 * scale, 0), top, pole)
        ..drawPath(
          Path()
            ..moveTo(top.dx, top.dy)
            ..lineTo(top.dx + 30 * scale, top.dy + 12 * scale)
            ..lineTo(top.dx, top.dy + 24 * scale)
            ..close(),
          Paint()
            ..color = i <= controller.state.checkpointIndex
                ? AppColors.success
                : AppColors.tangerine,
        );
    }
  }

  void _bolts(
    Canvas canvas,
    double Function(double) sx,
    double Function(double) sy,
    double scale,
    double left,
    double right,
  ) {
    final collected = controller.state.collectedBolts;
    for (final (i, bolt) in _course.bolts.indexed) {
      if (collected.contains(i) || bolt.x < left || bolt.x > right) continue;
      final c = Offset(sx(bolt.x), sy(bolt.y + 4 * sin(_clock * 3 + i)));
      final r = 13 * scale * 1.6;
      final hex = Path();
      for (var k = 0; k < 6; k++) {
        final ang = pi / 6 + k * pi / 3;
        final pt = c + Offset(cos(ang), sin(ang)) * r;
        k == 0 ? hex.moveTo(pt.dx, pt.dy) : hex.lineTo(pt.dx, pt.dy);
      }
      hex.close();
      canvas
        ..drawPath(hex, Paint()..color = AppColors.sunny)
        ..drawPath(
          hex,
          Paint()
            ..color = AppColors.navy
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        )
        ..drawCircle(c, r * 0.38, Paint()..color = AppColors.navy);
    }
  }

  void _flag(
    Canvas canvas,
    double Function(double) sx,
    double Function(double) sy,
    double scale,
  ) {
    if (controller.loop) return;
    final base = Offset(sx(_course.lengthPx), sy(0));
    final top = base + Offset(0, -180 * scale);
    canvas.drawLine(
      base,
      top,
      Paint()
        ..color = AppColors.navy
        ..strokeWidth = 5,
    );
    const cells = 4;
    final cell = 14 * scale * 1.4;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < cells; c++) {
        canvas.drawRect(
          Rect.fromLTWH(top.dx + c * cell, top.dy + r * cell, cell, cell),
          Paint()..color = (r + c).isEven ? AppColors.navy : AppColors.white,
        );
      }
    }
  }

  void _robot(Canvas canvas, double x, double y, double scale, RunState s) {
    final c = controller;
    final face = switch (s.phase) {
      RunPhase.bumped || RunPhase.fallen => RobotFace.spiral,
      RunPhase.finished => RobotFace.cheer,
      _ => RobotFace.happy,
    };
    final look = RobotLook(
      c.robot,
      face: face,
      armsUp:
          s.onBar ||
          c.shrugging ||
          c.previewing ||
          s.phase == RunPhase.finished,
      flame: s.thrusting,
      wheelTurn: s.x / 80,
    );
    // The art is a bit bigger than the hitbox so the robot reads well.
    final artScale = c.tuning.robotHeight * 1.3 * scale / RobotArt.height;
    canvas
      ..save()
      ..translate(
        x - RobotArt.width * artScale / 2,
        y - RobotArt.height * artScale,
      );
    if (s.phase == RunPhase.bumped) {
      canvas.rotate(0.08 * sin(_clock * 30)); // comic wobble (FEEL-01)
    }
    canvas.scale(artScale);
    RobotArt.draw(canvas, look);
    canvas.restore();
  }

  static void _icon(Canvas canvas, IconData icon, Offset center, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: AppColors.navy,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
}
