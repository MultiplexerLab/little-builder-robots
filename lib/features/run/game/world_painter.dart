import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart'
    show
        Curves,
        IconData,
        Icons,
        TextDirection,
        TextPainter,
        TextSpan,
        TextStyle;
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart'
    show needIcon, paintGear;
import 'package:little_builder_robots/core/widgets/robot_painter.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';
import 'package:little_builder_robots/domain/sim/terrain.dart';
import 'package:little_builder_robots/features/run/exclaimer.dart';
import 'package:little_builder_robots/features/run/game/effects.dart';
import 'package:little_builder_robots/features/run/run_controller.dart';

/// Draws the run from [RunController] state (Flame renders, the simulator
/// decides; SRS 7). World units are px with y up from ground level 0.
///
/// Everything here is decoration and feedback: parallax scenery for Gear
/// Garden, particles for bolts, landings, bumps and splashes, and the
/// robot's squash and stretch. None of it feeds back into the run. With
/// Reduce Motion on, particles, shake and spinning scenery are off
/// (NFR-11).
class WorldPainter {
  WorldPainter(
    this.controller, {
    this.reduceMotion = false,
    this.lines = const {},
    this.onSay,
  }) : exclaimer = Exclaimer(controller.course),
       terrain = Terrain.fromCourse(controller.course),
       needs = [
         for (var i = 0; i < controller.course.obstacles.length; i++)
           controller.coach.needFor(controller.course, i),
       ];

  final RunController controller;
  final Terrain terrain;
  final List<ObstacleNeed> needs;
  final bool reduceMotion;
  final Effects effects = Effects();

  /// The robot's exclamations: l10n key to text, and a callback that plays
  /// the matching voice clip.
  final Map<String, String> lines;
  final void Function(String key)? onSay;
  final Exclaimer exclaimer;
  final Map<int, int> _failures = {};

  /// How much of the world fits the screen height.
  static const worldHeight = 430.0;

  /// The robot sits this far across the screen.
  static const robotScreenX = 0.3;

  /// Bars hang just above the robot's head.
  static const _barHeight = 78.0;

  double _clock = 0;
  int _seenEvents = 0;

  /// Positive squashes the robot (just landed), negative stretches it (just
  /// jumped). Eases back to 0.
  double _squash = 0;
  double _trailTimer = 0;

  Course get _course => controller.course;

  /// A fixed pseudo-random number in 0..1 for [n], so scenery is the same
  /// every frame and every run.
  static double _hash(num n) {
    final v = sin(n * 12.9898 + 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  void tick(double dt) {
    _clock += dt;
    _readEvents();
    _squash *= pow(0.0005, dt).toDouble(); // springs back in ~0.3 s
    if (reduceMotion) return;
    final s = controller.state;
    if (s.phase == RunPhase.running && !controller.paused) {
      _trailTimer -= dt;
      if (_trailTimer <= 0) {
        _trailTimer = 0.07;
        if (s.onGround) effects.trail(s.x - 18, s.y);
        if (s.thrusting) effects.jetpack(s.x - 22, s.y + 30);
      }
    }
    effects.update(dt);
  }

  /// Turns new run events into feedback.
  void _readEvents() {
    final events = controller.events;
    if (events.length < _seenEvents) {
      _seenEvents = 0; // restarted
      effects.clear();
      exclaimer.reset();
      _failures.clear();
    }
    final s = controller.state;
    final head = s.y + controller.tuning.robotHeight;
    for (var i = _seenEvents; i < events.length; i++) {
      _maybeSay(events[i]);
      switch (events[i]) {
        case JumpedEvent():
          _squash = -0.18;
          if (!reduceMotion) effects.dust(s.x, s.y, count: 4, power: 0.6);
        case HappyHopEvent():
          _squash = -0.12;
        case LandedEvent():
          _squash = 0.22;
          if (!reduceMotion) effects.dust(s.x, s.y);
        case RampLaunchEvent():
          _squash = -0.25;
          if (!reduceMotion) effects.dust(s.x, s.y, count: 12, power: 1.6);
        case BoltCollectedEvent(:final boltIndex):
          final bolt = _course.bolts[boltIndex];
          if (!reduceMotion) effects.boltCollected(bolt.x, bolt.y);
        case BumpedEvent():
          if (!reduceMotion) effects.bump(s.x + 20, head);
        case CeilingBonkEvent():
          if (!reduceMotion) effects.bump(s.x, head, shakeScreen: false);
        case FellEvent(:final obstacleIndex):
          final o = obstacleIndex == null
              ? null
              : _course.obstacles[obstacleIndex];
          if (o is GapObstacle && o.water && !reduceMotion) {
            effects.splash(s.x, -40);
          }
        case LeavesBlownEvent(:final obstacleIndex):
          final o = _course.obstacles[obstacleIndex];
          if (!reduceMotion) {
            effects
              ..burst(o.start, 20, AppColors.tangerine)
              ..burst(o.start, 20, AppColors.grass, count: 8);
          }
        case GateOpenedEvent(:final obstacleIndex) ||
            SwitchPressedEvent(:final obstacleIndex):
          final o = _course.obstacles[obstacleIndex];
          if (!reduceMotion) {
            effects.burst(o.start, 0, AppColors.sunny, count: 8);
          }
        case FinishedEvent():
          if (!reduceMotion && !controller.loop) {
            effects.confetti(_course.lengthPx, 160);
          }
        case GearFoundEvent():
          final gear = _course.gear!;
          if (!reduceMotion) {
            effects
              ..boltCollected(gear.x, gear.y)
              ..burst(gear.x, gear.y - 40, AppColors.sunny, count: 18);
          }
        case CheckpointReachedEvent(:final checkpointIndex):
          final cp = _course.checkpoints[checkpointIndex];
          if (!reduceMotion) {
            effects.burst(cp.x - 40, 90, AppColors.mint, count: 10);
          }
        default:
          break;
      }
    }
    _seenEvents = events.length;
  }

  /// Lets the robot shout on fun moments. A bump or fall only gets a shout
  /// the first time at that obstacle, and only in Big Builder: after that
  /// (and always in Little Builder) the voiced hint speaks instead.
  void _maybeSay(RunEvent event) {
    var first = false;
    if (event
        case BumpedEvent(:final obstacleIndex) ||
            FellEvent(:final obstacleIndex)) {
      if (obstacleIndex != null) {
        final n = (_failures[obstacleIndex] ?? 0) + 1;
        _failures[obstacleIndex] = n;
        first = n == 1 && controller.playStyle == PlayStyle.big;
      }
    }
    final key = exclaimer.react(event, _clock, firstFailure: first);
    if (key != null) onSay?.call(key);
  }

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

    canvas.save();
    if (effects.shake > 0) {
      final k = effects.shake * 24;
      canvas.translate(sin(_clock * 90) * k, cos(_clock * 70) * k * 0.6);
    }
    _sky(canvas, size, cameraX, scale, groundY);
    _ground(canvas, size, sx, sy, scale, left, right);
    _obstacles(canvas, size, sx, sy, scale, left, right, robotX);
    _checkpoints(canvas, sx, sy, scale, left, right);
    _bolts(canvas, sx, sy, scale, left, right);
    _goldenGear(canvas, sx, sy, scale, left, right);
    _flag(canvas, sx, sy, scale);
    _robot(canvas, sx(robotX), sy(robotY), scale, s);
    _particles(canvas, sx, sy, scale);
    _speech(canvas, sx(robotX), sy(robotY), scale, size);
    canvas.restore();
  }

  // ------------------------------------------------------------ backdrop

  void _sky(
    Canvas canvas,
    Size size,
    double cameraX,
    double scale,
    double groundY,
  ) {
    final top = Color.lerp(AppColors.sky, AppColors.roboBlue, 0.45)!;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = Gradient.linear(Offset.zero, Offset(0, groundY), [
          top,
          AppColors.sky,
        ]),
    );

    // The sun, with slowly turning rays.
    final sun = Offset(size.width * 0.82, size.height * 0.2);
    final rays = Paint()
      ..color = AppColors.sunny.withValues(alpha: 0.35)
      ..strokeWidth = 6 * scale
      ..strokeCap = StrokeCap.round;
    final turn = reduceMotion ? 0.0 : _clock * 0.2;
    for (var i = 0; i < 12; i++) {
      final ang = turn + i * pi / 6;
      canvas.drawLine(
        sun + Offset(cos(ang), sin(ang)) * 42 * scale,
        sun + Offset(cos(ang), sin(ang)) * 60 * scale,
        rays,
      );
    }
    canvas
      ..drawCircle(sun, 34 * scale, Paint()..color = AppColors.sunny)
      ..drawCircle(
        sun,
        34 * scale,
        Paint()
          ..color = AppColors.tangerine.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

    // Drifting clouds (far, slow).
    final cloud = Paint()..color = AppColors.white.withValues(alpha: 0.9);
    final drift = reduceMotion ? 0.0 : _clock * 10;
    for (var i = 0; i < 6; i++) {
      final w = size.width + 300;
      final x = (i * 260 - cameraX * 0.12 * scale - drift) % w - 150;
      final y = (30.0 + (i * 53) % 90) * scale + 10;
      final k = scale * (0.8 + _hash(i) * 0.5);
      canvas
        ..drawCircle(Offset(x, y), 26 * k, cloud)
        ..drawCircle(Offset(x + 28 * k, y + 6 * k), 20 * k, cloud)
        ..drawCircle(Offset(x - 26 * k, y + 8 * k), 18 * k, cloud)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(x - 44 * k, y + 4 * k, x + 46 * k, y + 26 * k),
            Radius.circular(12 * k),
          ),
          cloud,
        );
    }

    // Gear Garden's giant gears, half hidden behind the hills.
    final gearPaint = Paint()..color = AppColors.white.withValues(alpha: 0.55);
    final gearHole = Paint()
      ..color = Color.lerp(AppColors.sky, AppColors.roboBlue, 0.2)!;
    const gearSpacing = 520.0;
    final gearScroll = cameraX * 0.3 * scale;
    final first = (gearScroll / gearSpacing).floor() - 1;
    for (
      var i = first;
      i < first + (size.width / gearSpacing).ceil() + 3;
      i++
    ) {
      final cx = i * gearSpacing - gearScroll + _hash(i) * 200;
      final r = (60 + _hash(i + 50) * 50) * scale;
      final cy = groundY - 40 * scale - _hash(i + 9) * 40 * scale;
      final spin = (reduceMotion ? 0.0 : _clock * 0.3) * (i.isEven ? 1 : -1);
      _gear(canvas, Offset(cx, cy), r, spin, gearPaint, gearHole);
    }

    // Rolling hills (mid distance).
    final hills = Paint()
      ..color = Color.lerp(AppColors.sky, AppColors.grass, 0.65)!;
    final hillScroll = cameraX * 0.45 * scale;
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width + 20; x += 20) {
      final wx = x + hillScroll;
      final h = 50 + 26 * sin(wx / 140) + 18 * sin(wx / 61 + 1.3);
      path.lineTo(x, groundY - 30 * scale - h * scale);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, hills);

    // Round bushes in front of the hills.
    final bush = Paint()
      ..color = Color.lerp(AppColors.grass, AppColors.success, 0.25)!;
    const bushSpacing = 240.0;
    final bushScroll = cameraX * 0.7 * scale;
    final firstBush = (bushScroll / bushSpacing).floor() - 1;
    for (
      var i = firstBush;
      i < firstBush + (size.width / bushSpacing).ceil() + 3;
      i++
    ) {
      final bx = i * bushSpacing - bushScroll + _hash(i + 3) * 120;
      final by = groundY - 18 * scale;
      final r = (18 + _hash(i + 7) * 14) * scale;
      canvas
        ..drawCircle(Offset(bx, by), r, bush)
        ..drawCircle(Offset(bx + r * 0.9, by + r * 0.2), r * 0.75, bush)
        ..drawCircle(Offset(bx - r * 0.8, by + r * 0.3), r * 0.6, bush);
    }
  }

  void _gear(
    Canvas canvas,
    Offset c,
    double r,
    double angle,
    Paint fill,
    Paint hole,
  ) {
    const teeth = 10;
    final path = Path();
    for (var i = 0; i < teeth * 2; i++) {
      final a0 = angle + i * pi / teeth;
      final a1 = angle + (i + 1) * pi / teeth;
      final rr = i.isEven ? r : r * 0.82;
      if (i == 0) path.moveTo(c.dx + cos(a0) * rr, c.dy + sin(a0) * rr);
      path
        ..lineTo(c.dx + cos(a0) * rr, c.dy + sin(a0) * rr)
        ..lineTo(c.dx + cos(a1) * rr, c.dy + sin(a1) * rr);
    }
    path.close();
    canvas
      ..drawPath(path, fill)
      ..drawCircle(c, r * 0.32, hole);
  }

  // --------------------------------------------------------------- ground

  void _ground(
    Canvas canvas,
    Size size,
    double Function(double) sx,
    double Function(double) sy,
    double scale,
    double left,
    double right,
  ) {
    final outline = Paint()
      ..color = AppColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final earth = Color.lerp(AppColors.grass, AppColors.success, 0.35)!;
    final earthDeep = Color.lerp(AppColors.grass, AppColors.success, 0.55)!;
    for (final seg in terrain.segments) {
      if (seg.end < left || seg.start > right) continue;
      final x0 = sx(max(seg.start, left));
      final x1 = sx(min(seg.end, right));
      final height = seg.height;
      if (height == null) {
        final water = _course.obstacles.any(
          (o) => o is GapObstacle && o.water && o.x == seg.start,
        );
        if (water) _water(canvas, size, x0, x1, sy(-30), scale);
        if (seg.bar) _bar(canvas, x0, x1, sy(_barHeight));
        continue;
      }
      final top = sy(height);
      final body = Rect.fromLTRB(x0, top, x1, size.height);
      if (height > 0) {
        _bricks(canvas, body, scale);
      } else {
        // Earth with darker bands and pebbles.
        canvas
          ..drawRect(body, Paint()..color = earth)
          ..drawRect(
            Rect.fromLTRB(x0, top + 40 * scale, x1, size.height),
            Paint()..color = earthDeep,
          );
        final pebble = Paint()..color = AppColors.cloud.withValues(alpha: 0.7);
        final from = max(seg.start, left);
        final to = min(seg.end, right);
        for (var wx = (from / 60).floor() * 60.0; wx < to; wx += 60) {
          final h = _hash(wx);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(sx(wx + h * 40), top + (20 + h * 50) * scale),
              width: (8 + h * 10) * scale,
              height: (5 + h * 5) * scale,
            ),
            pebble,
          );
        }
      }
      // A grass cap with tufts on every surface.
      final cap = Paint()..color = AppColors.grass;
      canvas.drawRect(Rect.fromLTRB(x0, top, x1, top + 12 * scale), cap);
      final from = max(seg.start, left);
      final to = min(seg.end, right);
      for (var wx = (from / 16).floor() * 16.0; wx < to; wx += 16) {
        canvas.drawCircle(
          Offset(sx(wx + 8), top + 12 * scale),
          7 * scale,
          cap,
        );
      }
      canvas.drawLine(Offset(x0, top), Offset(x1, top), outline);
      if (height == 0) _flowers(canvas, sx, top, from, to, scale);
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

  /// Stone bricks for raised steps.
  void _bricks(Canvas canvas, Rect body, double scale) {
    canvas.drawRect(body, Paint()..color = AppColors.cloud);
    final seam = Paint()
      ..color = AppColors.navy.withValues(alpha: 0.15)
      ..strokeWidth = 2;
    final rowH = 20 * scale;
    final brickW = 44 * scale;
    var row = 0;
    for (var y = body.top + 12 * scale + rowH; y < body.bottom; y += rowH) {
      canvas.drawLine(Offset(body.left, y), Offset(body.right, y), seam);
      final offset = row.isEven ? 0 : brickW / 2;
      for (var x = body.left + offset; x < body.right; x += brickW) {
        canvas.drawLine(Offset(x, y), Offset(x, y + rowH), seam);
      }
      row++;
    }
  }

  void _flowers(
    Canvas canvas,
    double Function(double) sx,
    double top,
    double from,
    double to,
    double scale,
  ) {
    const colours = [AppColors.sunny, AppColors.white, AppColors.tangerine];
    for (var wx = (from / 90).floor() * 90.0; wx < to; wx += 90) {
      final h = _hash(wx + 1);
      if (h < 0.45) continue;
      final x = sx(wx + h * 60);
      final sway = reduceMotion ? 0.0 : sin(_clock * 2 + wx) * 2 * scale;
      final head = Offset(x + sway, top - 10 * scale);
      canvas.drawLine(
        Offset(x, top + 2),
        head,
        Paint()
          ..color = AppColors.success
          ..strokeWidth = 2 * scale,
      );
      final petal = Paint()..color = colours[(h * 100).floor() % 3];
      for (var k = 0; k < 5; k++) {
        final ang = k * 2 * pi / 5;
        canvas.drawCircle(
          head + Offset(cos(ang), sin(ang)) * 4 * scale,
          3.2 * scale,
          petal,
        );
      }
      canvas.drawCircle(head, 2.4 * scale, Paint()..color = AppColors.navy);
    }
  }

  void _water(
    Canvas canvas,
    Size size,
    double x0,
    double x1,
    double surface,
    double scale,
  ) {
    final wave = Path()..moveTo(x0, size.height);
    for (var x = x0; x <= x1; x += 6) {
      final y =
          surface + (reduceMotion ? 0 : sin(x / 18 + _clock * 3) * 4 * scale);
      wave.lineTo(x, y);
    }
    wave
      ..lineTo(x1, size.height)
      ..close();
    canvas
      ..drawPath(wave, Paint()..color = AppColors.roboBlue)
      ..drawPath(
        wave,
        Paint()
          ..color = AppColors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
  }

  void _bar(Canvas canvas, double x0, double x1, double barY) {
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

  // ------------------------------------------------------------ obstacles

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
          final timeLeft = s.openGates[i];
          _door(canvas, sx(x), sy(0), scale, open: timeLeft != null);
          if (timeLeft != null) {
            // SRS 4.3: a shrinking light ring shows the time left.
            canvas.drawArc(
              Rect.fromCircle(
                center: Offset(sx(x), sy(190)),
                radius: 18 * scale * 2,
              ),
              -pi / 2,
              2 * pi * (timeLeft / openSeconds),
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
          // Slow bubbles in the mud.
          for (var b = x + 30; b < x + width; b += 70) {
            final pop = reduceMotion
                ? 0.6
                : (sin(_clock * 1.5 + b) * 0.5 + 0.5);
            canvas.drawCircle(
              Offset(sx(b), sy(-6)),
              (3 + 4 * pop) * scale * 2,
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
          _bricks(canvas, r, scale);
          canvas.drawLine(
            r.bottomLeft,
            r.bottomRight,
            outline..strokeWidth = 4,
          );
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
          // Chevrons say "go fast".
          final chevron = Paint()
            ..color = AppColors.white
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          for (var k = 1; k < 4; k++) {
            final cx = x + width * k / 4;
            final cy = 28 * k / 4 * 0.5;
            canvas.drawPath(
              Path()
                ..moveTo(sx(cx - 6), sy(cy + 5))
                ..lineTo(sx(cx), sy(cy))
                ..lineTo(sx(cx - 6), sy(cy - 5)),
              chevron,
            );
          }
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
    final pulse = near && !reduceMotion ? 1 + 0.12 * sin(_clock * 8) : 1.0;
    final r = 22 * scale * 1.6 * pulse;
    final c = Offset(sx(o.start + 20), sy(top + 70));
    // A little post holds the sign up.
    canvas
      ..drawLine(
        c,
        Offset(c.dx, sy(top)),
        Paint()
          ..color = AppColors.navy
          ..strokeWidth = 4,
      )
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
    if (!open) {
      // Hazard stripes so a shut door reads at a glance.
      final stripe = Paint()
        ..color = AppColors.sunny
        ..strokeWidth = 5;
      canvas
        ..save()
        ..clipRRect(RRect.fromRectAndRadius(door, const Radius.circular(6)));
      for (var yy = door.top; yy < door.bottom + door.width; yy += 22) {
        canvas.drawLine(
          Offset(door.left, yy),
          Offset(door.right, yy - door.width),
          stripe,
        );
      }
      canvas.restore();
    }
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
      final reached = i <= controller.state.checkpointIndex;
      final pole = Paint()
        ..color = AppColors.navy
        ..strokeWidth = 4;
      final top = base + Offset(-40 * scale, -100 * scale);
      final wave = reduceMotion ? 0.0 : sin(_clock * 6 + i) * 3 * scale;
      canvas
        ..drawLine(base + Offset(-40 * scale, 0), top, pole)
        ..drawPath(
          Path()
            ..moveTo(top.dx, top.dy)
            ..quadraticBezierTo(
              top.dx + 15 * scale,
              top.dy + 6 * scale + wave,
              top.dx + 30 * scale,
              top.dy + 12 * scale,
            )
            ..lineTo(top.dx, top.dy + 24 * scale)
            ..close(),
          Paint()..color = reached ? AppColors.success : AppColors.tangerine,
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
      final bob = reduceMotion ? 0.0 : 4 * sin(_clock * 3 + i);
      final c = Offset(sx(bolt.x), sy(bolt.y + bob));
      final r = 13 * scale * 1.6;
      // Spins around its upright axis.
      final turn = reduceMotion ? 1.0 : cos(_clock * 2.5 + i * 0.7).abs();
      final squeeze = max(0.25, turn);
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..scale(squeeze, 1);
      final hex = Path();
      for (var k = 0; k < 6; k++) {
        final ang = pi / 6 + k * pi / 3;
        final pt = Offset(cos(ang), sin(ang)) * r;
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
        ..drawCircle(Offset.zero, r * 0.38, Paint()..color = AppColors.navy)
        ..restore();
      // A soft glint now and then (well under 3 flashes a second, NFR-21).
      final glint = sin(_clock * 1.7 + i * 2.1);
      if (!reduceMotion && glint > 0.9) {
        final k = (glint - 0.9) * 10;
        final g = c + Offset(r * 0.5, -r * 0.5);
        final gp = Paint()
          ..color = AppColors.white
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas
          ..drawLine(g + Offset(-6 * k, 0), g + Offset(6 * k, 0), gp)
          ..drawLine(g + Offset(0, -6 * k), g + Offset(0, 6 * k), gp);
      }
    }
  }

  /// RUN-16: the golden gear, turning slowly inside a soft glow until it is
  /// picked up.
  void _goldenGear(
    Canvas canvas,
    double Function(double) sx,
    double Function(double) sy,
    double scale,
    double left,
    double right,
  ) {
    final gear = _course.gear;
    if (gear == null || controller.state.gotGear) return;
    if (gear.x < left || gear.x > right) return;
    final bob = reduceMotion ? 0.0 : 5 * sin(_clock * 2);
    final c = Offset(sx(gear.x), sy(gear.y + bob));
    final r = 18 * scale * 1.6;
    final glow = reduceMotion ? 0.5 : 0.5 + 0.2 * sin(_clock * 3);
    canvas.drawCircle(
      c,
      r * 1.7,
      Paint()..color = AppColors.sunny.withValues(alpha: 0.25 * glow + 0.1),
    );
    paintGear(canvas, c, r, angle: reduceMotion ? 0 : _clock * 0.8);
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
    canvas
      ..drawLine(
        base,
        top,
        Paint()
          ..color = AppColors.navy
          ..strokeWidth = 5,
      )
      ..drawCircle(top, 6 * scale, Paint()..color = AppColors.sunny);
    const cells = 4;
    final cell = 14 * scale * 1.4;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < cells; c++) {
        final wave = reduceMotion
            ? 0.0
            : sin(_clock * 5 - c * 0.9) * 4 * scale * c / cells;
        canvas.drawRect(
          Rect.fromLTWH(
            top.dx + c * cell,
            top.dy + r * cell + wave,
            cell,
            cell,
          ),
          Paint()..color = (r + c).isEven ? AppColors.navy : AppColors.white,
        );
      }
    }
  }

  // ---------------------------------------------------------------- robot

  void _robot(Canvas canvas, double x, double y, double scale, RunState s) {
    final c = controller;
    // A blink every few seconds keeps the robot alive.
    final blinking = !reduceMotion && (_clock % 3.2) < 0.12;
    final face = switch (s.phase) {
      RunPhase.bumped || RunPhase.fallen => RobotFace.spiral,
      RunPhase.finished => RobotFace.cheer,
      _ when blinking => RobotFace.sleep,
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
    final w = RobotArt.width * artScale;
    final h = RobotArt.height * artScale;

    // A soft shadow on the ground under the robot.
    final ground = terrain.supportUnder(s.x - 10, s.x + 10);
    if (ground != null) {
      final lift = ((s.y - ground) / 200).clamp(0.0, 0.7);
      final gy = y + (s.y - ground) * scale;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, gy),
          width: w * 0.8 * (1 - lift),
          height: 8 * scale * (1 - lift),
        ),
        Paint()..color = AppColors.navy.withValues(alpha: 0.18),
      );
    }

    // Squash and stretch around the feet, plus a little bob while rolling.
    var sq = reduceMotion ? 0.0 : _squash;
    if (!reduceMotion && !s.onGround && s.phase == RunPhase.running) {
      sq += (-s.vy / 4000).clamp(-0.12, 0.12);
    }
    final rolling = s.onGround && s.phase == RunPhase.running;
    final bob = rolling && !reduceMotion
        ? sin(s.x / 14).abs() * 2.5 * scale
        : 0.0;
    canvas
      ..save()
      ..translate(x, y - bob);
    if (s.phase == RunPhase.bumped) {
      canvas.rotate(0.08 * sin(_clock * 30)); // comic wobble (FEEL-01)
    }
    canvas
      ..scale(1 + sq, 1 - sq)
      ..translate(-w / 2, -h)
      ..scale(artScale);
    RobotArt.draw(canvas, look);
    canvas.restore();
  }

  void _particles(
    Canvas canvas,
    double Function(double) sx,
    double Function(double) sy,
    double scale,
  ) {
    for (final p in effects.particles) {
      final at = Offset(sx(p.x), sy(p.y));
      final alpha = p.t.clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: alpha);
      final size = p.size * scale * 1.4;
      switch (p.kind) {
        case ParticleKind.dot:
          canvas.drawCircle(at, size * (0.6 + 0.4 * p.t), paint);
        case ParticleKind.spark:
          final d = Offset(p.vx, -p.vy) / 60;
          canvas.drawLine(
            at,
            at - d,
            paint
              ..strokeWidth = size * 0.6
              ..strokeCap = StrokeCap.round,
          );
        case ParticleKind.confetti:
          canvas
            ..save()
            ..translate(at.dx, at.dy)
            ..rotate(p.angle)
            ..drawRect(
              Rect.fromCenter(
                center: Offset.zero,
                width: size,
                height: size * 0.55,
              ),
              paint,
            )
            ..restore();
        case ParticleKind.ring:
          canvas.drawCircle(
            at,
            size * (1 + 2 * (1 - p.t)),
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4 * p.t + 1,
          );
        case ParticleKind.label:
          final tp = TextPainter(
            text: TextSpan(
              text: p.label,
              style: AppText.button.copyWith(
                fontSize: size,
                color: p.color.withValues(alpha: alpha),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  /// A speech bubble above the robot's head that pops in.
  void _speech(Canvas canvas, double x, double y, double scale, Size screen) {
    final key = exclaimer.currentAt(_clock);
    final text = key == null ? null : lines[key];
    if (text == null) return;
    final tp = TextPainter(
      text: TextSpan(text: text, style: AppText.button),
      textDirection: TextDirection.ltr,
    )..layout();
    const pad = 12.0;
    final w = tp.width + pad * 2;
    final h = tp.height + pad;
    final head = y - controller.tuning.robotHeight * 1.3 * scale - 18;
    final left = (x - w / 2).clamp(8.0, screen.width - w - 8);
    final box = Rect.fromLTWH(left, head - h, w, h);
    final age = Exclaimer.showFor - (exclaimer.untilAt - _clock);
    final pop = reduceMotion
        ? 1.0
        : Curves.easeOutBack.transform((age / 0.2).clamp(0.0, 1.0));
    canvas
      ..save()
      ..translate(x, box.bottom)
      ..scale(pop)
      ..translate(-x, -box.bottom);
    final bubble = RRect.fromRectAndRadius(box, const Radius.circular(18));
    final tail = Path()
      ..moveTo(x - 8, box.bottom - 1)
      ..lineTo(x, box.bottom + 10)
      ..lineTo(x + 8, box.bottom - 1)
      ..close();
    final fill = Paint()..color = AppColors.white;
    final line = Paint()
      ..color = AppColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas
      ..drawRRect(bubble, fill)
      ..drawRRect(bubble, line)
      ..drawPath(tail, fill)
      ..drawLine(Offset(x - 8, box.bottom), Offset(x, box.bottom + 10), line)
      ..drawLine(Offset(x + 8, box.bottom), Offset(x, box.bottom + 10), line);
    tp.paint(canvas, Offset(box.left + pad, box.top + pad / 2));
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
