import 'dart:math';

import 'package:flutter/material.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';

/// The robot's face. Never sad or hurt: a bump gives spiral eyes, never X
/// eyes (FEEL-01).
enum RobotFace { happy, cheer, spiral, sleep }

/// How to draw the robot right now.
class RobotLook {
  const RobotLook(
    this.config, {
    this.face = RobotFace.happy,
    this.armsUp = false,
    this.flame = false,
    this.wheelTurn = 0,
  });

  final RobotConfig config;
  final RobotFace face;

  /// Hanging from a bar, or cheering.
  final bool armsUp;

  /// Jetpack thrust is on.
  final bool flame;

  /// Wheel and track rotation, in turns.
  final double wheelTurn;
}

/// The one robot renderer (WRK-13), used by `RobotView` and by the Flame run.
/// It draws in a 100 x 130 unit box with the feet at the bottom middle.
abstract final class RobotArt {
  static const width = 100.0;
  static const height = 130.0;

  static final _outline = Paint()
    ..color = AppColors.navy
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  static Paint _fill(Color color) => Paint()..color = color;

  static void _shape(Canvas canvas, Path path, Color fill) {
    canvas
      ..drawPath(path, _fill(fill))
      ..drawPath(path, _outline);
  }

  static Path _rrect(double l, double t, double w, double h, double r) =>
      Path()..addRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r)),
      );

  /// Draws [look] into a box of [size], keeping proportions, feet on the
  /// bottom edge.
  static void paintInto(Canvas canvas, Size size, RobotLook look) {
    final scale = min(size.width / width, size.height / height);
    canvas
      ..save()
      ..translate(
        (size.width - width * scale) / 2,
        size.height - height * scale,
      )
      ..scale(scale);
    draw(canvas, look);
    canvas.restore();
  }

  /// Draws in unit space (100 x 130, feet at y = 130).
  static void draw(Canvas canvas, RobotLook look) {
    final config = look.config;
    final paint = AppColors.paints[config.colour] ?? AppColors.sunny;
    if (config.movesId == 'moves_jetpack') _jetpackPack(canvas, look.flame);
    _arms(canvas, config.armsId, look.armsUp, behind: true);
    _moves(canvas, config.movesId, look.wheelTurn);
    _body(
      canvas,
      config.bodyId,
      paint,
      config.colour,
      brace: config.decalId == null,
    );
    if (config.decalId != null) _decal(canvas, config.decalId!);
    _arms(canvas, config.armsId, look.armsUp, behind: false);
    _head(canvas, config.headId, paint, look.face);
  }

  // Moves: y 96..130.
  static void _moves(Canvas canvas, String id, double turn) {
    switch (id) {
      case 'moves_wheels':
        for (final cx in [32.0, 68.0]) {
          final wheel = Path()
            ..addOval(Rect.fromCircle(center: Offset(cx, 116), radius: 13));
          _shape(canvas, wheel, AppColors.navy);
          final hub = Path()
            ..addOval(Rect.fromCircle(center: Offset(cx, 116), radius: 5));
          _shape(canvas, hub, AppColors.cloud);
          final a = turn * 2 * pi;
          canvas.drawLine(
            Offset(cx + 9 * cos(a), 116 + 9 * sin(a)),
            Offset(cx - 9 * cos(a), 116 - 9 * sin(a)),
            _outline..color = AppColors.cloud,
          );
          _outline.color = AppColors.navy;
        }
      case 'moves_legs':
        for (final x in [34.0, 58.0]) {
          _shape(canvas, _rrect(x, 96, 9, 26, 4), AppColors.cloud);
          _shape(canvas, _rrect(x - 5, 120, 19, 9, 4), AppColors.roboBlue);
        }
      case 'moves_spring_feet':
        for (final x in [38.0, 62.0]) {
          final spring = Path()..moveTo(x, 96);
          for (var i = 0; i < 6; i++) {
            spring.lineTo(x + (i.isEven ? 7 : -7), 99 + i * 3.6);
          }
          canvas.drawPath(spring, _outline);
          _shape(canvas, _rrect(x - 10, 120, 20, 9, 4), AppColors.tangerine);
        }
      case 'moves_jetpack':
        for (final x in [36.0, 56.0]) {
          _shape(canvas, _rrect(x, 100, 8, 20, 4), AppColors.cloud);
          _shape(canvas, _rrect(x - 3, 119, 14, 10, 4), AppColors.roboBlue);
        }
      case 'moves_tank_tracks':
        _shape(canvas, _rrect(16, 104, 68, 25, 12), AppColors.navy);
        for (var i = 0; i < 4; i++) {
          final cx = 27 + i * 15.0;
          final wheel = Path()
            ..addOval(Rect.fromCircle(center: Offset(cx, 116.5), radius: 5));
          _shape(canvas, wheel, AppColors.cloud);
        }
      default:
        _shape(canvas, _rrect(30, 100, 40, 28, 6), AppColors.cloud);
    }
  }

  static void _jetpackPack(Canvas canvas, bool flame) {
    _shape(canvas, _rrect(70, 52, 18, 36, 6), AppColors.cloud);
    if (flame) {
      final f = Path()
        ..moveTo(72, 88)
        ..quadraticBezierTo(79, 116, 86, 88)
        ..close();
      _shape(canvas, f, AppColors.tangerine);
      final inner = Path()
        ..moveTo(75, 88)
        ..quadraticBezierTo(79, 104, 83, 88)
        ..close();
      canvas.drawPath(inner, _fill(AppColors.sunny));
    }
  }

  // Body: y 56..100.
  static void _body(
    Canvas canvas,
    String id,
    Color paint,
    String paintId, {
    required bool brace,
  }) {
    final rect = switch (id) {
      'body_heavy_frame' => const Rect.fromLTWH(14, 54, 72, 48),
      'body_battery' => const Rect.fromLTWH(22, 54, 56, 46),
      _ => const Rect.fromLTWH(24, 56, 52, 42),
    };
    final shape = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)));
    canvas
      ..drawPath(shape, _fill(paint))
      ..save()
      ..clipPath(shape);
    _pattern(canvas, rect, paintId);
    canvas
      ..restore()
      ..drawPath(shape, _outline);
    switch (id) {
      case 'body_heavy_frame':
        for (final x in [rect.left + 8, rect.right - 8]) {
          for (final y in [rect.top + 8, rect.bottom - 8]) {
            canvas.drawCircle(Offset(x, y), 2.5, _fill(AppColors.navy));
          }
        }
      case 'body_battery':
        _shape(canvas, _rrect(44, 48, 12, 7, 2), AppColors.cloud);
        final bolt = Path()
          ..moveTo(52, 62)
          ..lineTo(42, 79)
          ..lineTo(50, 79)
          ..lineTo(47, 93)
          ..lineTo(58, 74)
          ..lineTo(50, 74)
          ..close();
        _shape(canvas, bolt, AppColors.sunny);
      default:
        // The Light frame's brace; hidden under a decal.
        if (!brace) break;
        canvas.drawLine(
          Offset(rect.left + 6, rect.bottom - 6),
          Offset(rect.right - 6, rect.top + 6),
          _outline,
        );
    }
  }

  /// A pattern per paint, so colour is never the only signal (WRK-06,
  /// DES-10).
  static void _pattern(Canvas canvas, Rect r, String paintId) {
    final ink = Paint()
      ..color = AppColors.navy.withValues(alpha: 0.18)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    switch (paintId) {
      case 'roboBlue': // stripes
        for (var x = r.left - r.height; x < r.right; x += 10) {
          canvas.drawLine(
            Offset(x, r.bottom),
            Offset(x + r.height, r.top),
            ink,
          );
        }
      case 'tangerine': // dots
        for (var y = r.top + 6; y < r.bottom; y += 10) {
          for (var x = r.left + 6; x < r.right; x += 10) {
            canvas.drawCircle(Offset(x, y), 2, ink..style = PaintingStyle.fill);
          }
        }
      case 'mint': // zigzag
        for (var y = r.top + 8; y < r.bottom; y += 12) {
          final z = Path()..moveTo(r.left, y);
          for (var x = r.left; x < r.right; x += 8) {
            z
              ..lineTo(x + 4, y - 4)
              ..lineTo(x + 8, y);
          }
          canvas.drawPath(z, ink);
        }
      case 'grass': // checks
        for (var y = r.top; y < r.bottom; y += 10) {
          for (var x = r.left; x < r.right; x += 10) {
            if (((x - r.left) ~/ 10 + (y - r.top) ~/ 10).isEven) {
              canvas.drawRect(
                Rect.fromLTWH(x, y, 10, 10),
                ink..style = PaintingStyle.fill,
              );
            }
          }
        }
      case 'cloud': // rings
        for (var rad = 8.0; rad < r.width; rad += 10) {
          canvas.drawCircle(r.center, rad, ink);
        }
      default: // sunny: plain
        break;
    }
  }

  static void _decal(Canvas canvas, String id) {
    const c = Offset(50, 77);
    final fill = _fill(AppColors.white);
    switch (id) {
      case 'decal_stars':
        _shape(canvas, _star(c, 9, 4), AppColors.white);
      case 'decal_stripes':
        canvas
          ..drawRect(const Rect.fromLTWH(30, 70, 40, 4), fill)
          ..drawRect(const Rect.fromLTWH(30, 80, 40, 4), fill);
      case 'decal_lightning':
        final p = Path()
          ..moveTo(54, 64)
          ..lineTo(44, 79)
          ..lineTo(51, 79)
          ..lineTo(46, 91)
          ..lineTo(58, 75)
          ..lineTo(51, 75)
          ..close();
        _shape(canvas, p, AppColors.white);
      case 'decal_flowers':
        for (var i = 0; i < 5; i++) {
          final a = i * 2 * pi / 5;
          canvas.drawCircle(c + Offset(cos(a), sin(a)) * 6, 4, fill);
        }
        canvas.drawCircle(c, 3.5, _fill(AppColors.sunny));
      case 'decal_eyes':
        for (final dx in [-8.0, 8.0]) {
          canvas
            ..drawCircle(c + Offset(dx, 0), 6, fill)
            ..drawCircle(c + Offset(dx, 1), 2.5, _fill(AppColors.navy));
        }
      case 'decal_hearts':
        final h = Path()
          ..moveTo(50, 88)
          ..cubicTo(36, 78, 40, 64, 50, 72)
          ..cubicTo(60, 64, 64, 78, 50, 88);
        _shape(canvas, h, AppColors.white);
      case 'decal_dots':
        for (final dx in [-10.0, 0.0, 10.0]) {
          canvas.drawCircle(c + Offset(dx, 0), 3.5, fill);
        }
      case 'decal_gears':
        _shape(canvas, _star(c, 10, 7, points: 8), AppColors.white);
        canvas.drawCircle(c, 3, _fill(AppColors.navy));
      default:
        break;
    }
  }

  static Path _star(Offset c, double outer, double inner, {int points = 5}) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -pi / 2 + i * pi / points;
      final p = c + Offset(cos(a), sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  static void _arms(
    Canvas canvas,
    String id,
    bool up, {
    required bool behind,
  }) {
    for (final side in behind ? [1.0] : [-1.0]) {
      final shoulder = Offset(50 + side * 28, 64);
      final hand = up
          ? shoulder + Offset(side * 6, -30)
          : shoulder + Offset(side * 10, 20);
      final arm = Paint()
        ..color = AppColors.navy
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(shoulder, hand, arm)
        ..drawLine(
          shoulder,
          hand,
          Paint()
            ..color = AppColors.cloud
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
      switch (id) {
        case 'arms_grabber':
          final claw = Path()
            ..moveTo(hand.dx - 7, hand.dy + (up ? -6 : 6))
            ..lineTo(hand.dx, hand.dy)
            ..lineTo(hand.dx + 7, hand.dy + (up ? -6 : 6));
          canvas.drawPath(claw, _outline..strokeWidth = 4);
          _outline.strokeWidth = 3;
        case 'arms_fan':
          for (var i = 0; i < 3; i++) {
            final a = i * 2 * pi / 3;
            final blade = Path()
              ..addOval(
                Rect.fromCenter(
                  center: hand + Offset(cos(a), sin(a)) * 6,
                  width: 10,
                  height: 6,
                ),
              );
            _shape(canvas, blade, AppColors.roboBlue);
          }
        default:
          final fist = Path()
            ..addOval(Rect.fromCircle(center: hand, radius: 5));
          _shape(canvas, fist, AppColors.cloud);
      }
    }
  }

  // Head: y 4..56.
  static void _head(Canvas canvas, String id, Color paint, RobotFace face) {
    final gold = id == 'head_gold';
    final fill = gold ? AppColors.sunny : AppColors.cloud;
    final Path shape;
    switch (id) {
      case 'head_square':
        shape = _rrect(24, 12, 52, 42, 6);
      case 'head_dome':
        shape = Path()
          ..moveTo(22, 54)
          ..lineTo(22, 36)
          ..arcToPoint(const Offset(78, 36), radius: const Radius.circular(28))
          ..lineTo(78, 54)
          ..close();
      case 'head_tv':
        canvas
          ..drawLine(const Offset(42, 14), const Offset(32, 2), _outline)
          ..drawLine(const Offset(58, 14), const Offset(68, 2), _outline);
        shape = _rrect(20, 14, 60, 40, 8);
      case 'head_antenna':
        canvas
          ..drawLine(const Offset(50, 14), const Offset(50, 2), _outline)
          ..drawCircle(const Offset(50, 3), 4, _fill(AppColors.tangerine));
        shape = _rrect(24, 14, 52, 40, 20);
      default: // round and gold
        shape = Path()..addOval(const Rect.fromLTWH(24, 8, 52, 48));
    }
    _shape(canvas, shape, fill);
    if (gold) {
      _shape(canvas, _star(const Offset(50, 8), 8, 3.5), AppColors.sunny);
    }

    // Face plate in the robot's paint, eyes in Mint (DES-01).
    _shape(canvas, _rrect(32, 24, 36, 22, 9), AppColors.navy);
    final eye = _fill(AppColors.mint);
    final eyeLine = Paint()
      ..color = AppColors.mint
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final x in [42.0, 58.0]) {
      switch (face) {
        case RobotFace.happy:
          canvas.drawCircle(Offset(x, 34), 4, eye);
        case RobotFace.cheer:
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x, 36), radius: 4),
            pi,
            pi,
            false,
            eyeLine,
          );
        case RobotFace.spiral:
          final s = Path()..moveTo(x, 34);
          for (var i = 1; i < 14; i++) {
            final a = i * 0.9;
            s.lineTo(x + cos(a) * i * 0.4, 34 + sin(a) * i * 0.4);
          }
          canvas.drawPath(s, eyeLine..strokeWidth = 2);
        case RobotFace.sleep:
          canvas.drawLine(Offset(x - 4, 35), Offset(x + 4, 35), eyeLine);
      }
    }
    // Cheek dots in the robot's paint.
    canvas
      ..drawCircle(const Offset(30, 42), 3, _fill(paint))
      ..drawCircle(const Offset(70, 42), 3, _fill(paint));
  }
}

/// Draws [RobotArt] for a widget.
class RobotPainter extends CustomPainter {
  const RobotPainter(this.look);

  final RobotLook look;

  @override
  void paint(Canvas canvas, Size size) =>
      RobotArt.paintInto(canvas, size, look);

  @override
  bool shouldRepaint(RobotPainter old) =>
      old.look.config != look.config ||
      old.look.face != look.face ||
      old.look.armsUp != look.armsUp ||
      old.look.flame != look.flame ||
      old.look.wheelTurn != look.wheelTurn;
}
