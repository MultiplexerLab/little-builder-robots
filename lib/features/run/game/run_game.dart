import 'dart:ui';

import 'package:flame/game.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/features/run/game/world_painter.dart';
import 'package:little_builder_robots/features/run/run_controller.dart';

/// The Flame game for a run (SRS 7.1): it advances the controller every
/// frame and renders its state. All rules live in the RunSimulator.
class RunGame extends FlameGame {
  RunGame(this.controller) : _painter = WorldPainter(controller);

  final RunController controller;
  final WorldPainter _painter;

  @override
  Color backgroundColor() => AppColors.sky;

  @override
  void update(double dt) {
    super.update(dt);
    controller.advance(dt);
    _painter.tick(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _painter.paint(canvas, Size(size.x, size.y));
  }
}
