import 'dart:math';
import 'dart:ui';

import 'package:little_builder_robots/app/theme.dart';

/// One short-lived piece of feedback: a spark, dust puff, droplet, confetti
/// piece or floating number. Effects only draw; they never touch the run
/// (SRS 4.7), so their randomness can't change a result.
class Particle {
  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.color,
    required this.size,
    this.gravity = 0,
    this.kind = ParticleKind.dot,
    this.spin = 0,
    this.label,
  }) : maxLife = life;

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final Color color;
  final double size;
  final double gravity;
  final ParticleKind kind;
  final double spin;
  final String? label;
  double angle = 0;

  /// 1 when new, 0 when gone.
  double get t => (life / maxLife).clamp(0, 1);
}

enum ParticleKind { dot, spark, confetti, ring, label }

/// A small pool of particles in world units (px, y up from the ground).
/// Capped so a busy moment can never cost frames (NFR-01).
class Effects {
  Effects({int seed = 7}) : _random = Random(seed);

  static const _max = 220;

  final Random _random;
  final List<Particle> particles = [];

  /// Remaining screen shake, in seconds.
  double shake = 0;

  double _r(double a, double b) => a + _random.nextDouble() * (b - a);

  void _add(Particle p) {
    if (particles.length >= _max) particles.removeAt(0);
    particles.add(p);
  }

  /// A bolt is picked up: a ring, gold sparks and a floating "+1".
  void boltCollected(double x, double y) {
    _add(
      Particle(
        x: x,
        y: y,
        vx: 0,
        vy: 0,
        life: 0.35,
        color: AppColors.sunny,
        size: 18,
        kind: ParticleKind.ring,
      ),
    );
    for (var i = 0; i < 10; i++) {
      final a = i * pi / 5 + _r(-0.2, 0.2);
      final speed = _r(140, 260);
      _add(
        Particle(
          x: x,
          y: y,
          vx: cos(a) * speed,
          vy: sin(a) * speed,
          life: _r(0.3, 0.55),
          color: i.isEven ? AppColors.sunny : AppColors.white,
          size: _r(3, 6),
          kind: ParticleKind.spark,
        ),
      );
    }
    _add(
      Particle(
        x: x,
        y: y + 20,
        vx: 0,
        vy: 90,
        life: 0.8,
        color: AppColors.navy,
        size: 26,
        kind: ParticleKind.label,
        label: '+1',
      ),
    );
  }

  /// Feet hit the ground: a soft puff either side.
  void dust(double x, double y, {int count = 8, double power = 1}) {
    for (var i = 0; i < count; i++) {
      final dir = i.isEven ? 1 : -1;
      _add(
        Particle(
          x: x + dir * _r(4, 18),
          y: y + 2,
          vx: dir * _r(40, 120) * power,
          vy: _r(20, 70) * power,
          life: _r(0.35, 0.6),
          color: AppColors.cloud,
          size: _r(5, 10),
          gravity: -60,
        ),
      );
    }
  }

  /// A little trail behind a rolling robot.
  void trail(double x, double y) => _add(
    Particle(
      x: x + _r(-4, 4),
      y: y + 2,
      vx: _r(-60, -20),
      vy: _r(10, 40),
      life: _r(0.25, 0.4),
      color: AppColors.cloud,
      size: _r(3, 6),
    ),
  );

  void jetpack(double x, double y) => _add(
    Particle(
      x: x + _r(-3, 3),
      y: y,
      vx: _r(-40, 10),
      vy: _r(-220, -140),
      life: _r(0.2, 0.35),
      color: _random.nextBool() ? AppColors.sunny : AppColors.tangerine,
      size: _r(4, 8),
    ),
  );

  void splash(double x, double y) {
    for (var i = 0; i < 16; i++) {
      _add(
        Particle(
          x: x + _r(-20, 20),
          y: y,
          vx: _r(-150, 150),
          vy: _r(220, 480),
          life: _r(0.6, 1),
          color: i % 3 == 0 ? AppColors.white : AppColors.roboBlue,
          size: _r(4, 9),
          gravity: -1200,
        ),
      );
    }
  }

  /// A bump: stars around the robot's head and a short screen shake.
  void bump(double x, double y, {bool shakeScreen = true}) {
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3;
      _add(
        Particle(
          x: x,
          y: y,
          vx: cos(a) * 110,
          vy: sin(a) * 110 + 40,
          life: 0.5,
          color: AppColors.sunny,
          size: 7,
          kind: ParticleKind.spark,
        ),
      );
    }
    if (shakeScreen) shake = 0.25;
  }

  /// Leaves fly, or a gate or door opens.
  void burst(double x, double y, Color color, {int count = 14}) {
    for (var i = 0; i < count; i++) {
      _add(
        Particle(
          x: x + _r(-20, 20),
          y: y + _r(0, 60),
          vx: _r(80, 320),
          vy: _r(60, 260),
          life: _r(0.6, 1.1),
          color: color,
          size: _r(6, 11),
          gravity: -500,
          kind: ParticleKind.confetti,
          spin: _r(-8, 8),
        ),
      );
    }
  }

  /// Confetti over the flag. Short, so celebrations stay under 4 s (NFR-21).
  void confetti(double x, double y) {
    const colours = [
      AppColors.sunny,
      AppColors.tangerine,
      AppColors.mint,
      AppColors.roboBlue,
      AppColors.white,
    ];
    for (var i = 0; i < 60; i++) {
      _add(
        Particle(
          x: x + _r(-60, 60),
          y: y,
          vx: _r(-260, 260),
          vy: _r(300, 700),
          life: _r(1.4, 2.4),
          color: colours[i % colours.length],
          size: _r(6, 11),
          gravity: -700,
          kind: ParticleKind.confetti,
          spin: _r(-10, 10),
        ),
      );
    }
  }

  void update(double dt) {
    shake = max(0, shake - dt);
    for (final p in particles) {
      p
        ..life -= dt
        ..vy += p.gravity * dt
        ..x += p.vx * dt
        ..y += p.vy * dt
        ..angle += p.spin * dt;
      if (p.kind == ParticleKind.spark || p.kind == ParticleKind.dot) {
        p
          ..vx *= 0.94
          ..vy *= 0.94;
      }
    }
    particles.removeWhere((p) => p.life <= 0);
  }

  void clear() {
    particles.clear();
    shake = 0;
  }
}
