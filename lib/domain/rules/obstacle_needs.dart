import 'dart:math';

import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/part_catalog.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/models/sim_tuning.dart';
import 'package:little_builder_robots/domain/rules/stat_calculator.dart';
import 'package:little_builder_robots/domain/sim/run_simulator.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';

/// The stat or ability an obstacle asks for. Each has one icon, shared by
/// the run (RUN-12), the hint bubble (RUN-13), the map hint (MAP-04) and the
/// Workshop's "Good at" panel (WRK-04).
enum Need { speed, climb, jump, heavy, light, jetpack, grab, fan }

/// An obstacle's icon and the pips it needs (0 means "any").
typedef ObstacleNeed = ({Need need, int pips});

/// Works out what each obstacle needs and which owned part would get the
/// robot past it.
class ObstacleCoach {
  ObstacleCoach({required this.catalog, required this.tuning})
    : _calculator = StatCalculator(catalog);

  final PartCatalog catalog;
  final SimTuning tuning;
  final StatCalculator _calculator;

  /// RUN-12: the icon and pips shown on obstacle [index] of [course].
  ObstacleNeed needFor(Course course, int index) {
    final obstacle = course.obstacles[index];
    final hw = tuning.robotHalfWidth;
    int speedPips(double pxPerSecond) => max(
      0,
      ((pxPerSecond - tuning.speedBase) / tuning.speedPerPoint).ceil(),
    );

    switch (obstacle) {
      case StepsObstacle(:final stepHeights):
        final rise = stepHeights.reduce(max);
        return (need: Need.climb, pips: (rise / tuning.climbPerPoint).ceil());
      case GapObstacle(:final width):
        final ramp = index > 0 ? course.obstacles[index - 1] : null;
        if (ramp is RampObstacle && ramp.end == obstacle.x) {
          return needFor(course, index - 1);
        }
        return width - 2 * hw > _bestJumpDistance()
            ? (need: Need.jetpack, pips: 0)
            : (need: Need.jump, pips: 0);
      case RampObstacle():
        final gap = index + 1 < course.obstacles.length
            ? course.obstacles[index + 1]
            : null;
        final distance = gap is GapObstacle ? gap.width - 2 * hw : 0.0;
        // Ramp flight: 2 x launch x speed / g x speed = distance.
        final speed = sqrt(
          distance * tuning.gravity / (2 * tuning.rampLaunchPerSpeed),
        );
        return (need: Need.speed, pips: speedPips(speed));
      case TimedGateObstacle(:final plateX, :final x, :final openSeconds):
        return (
          need: Need.speed,
          pips: speedPips((x - hw - plateX) / openSeconds),
        );
      case BarGapObstacle():
        return (need: Need.grab, pips: 0);
      case HeavySwitchObstacle():
        return (need: Need.heavy, pips: tuning.switchWeight);
      case MudObstacle():
        return (need: Need.light, pips: tuning.mudMaxWeight);
      case LeafPileObstacle():
        return (need: Need.fan, pips: 0);
      case LowCeilingObstacle():
        return (need: Need.jetpack, pips: 0);
    }
  }

  /// The obstacle the map hint talks about (MAP-04): the course's most
  /// common need, or null on a course with no obstacles.
  Need? mainNeed(Course course) {
    final counts = <Need, int>{};
    for (var i = 0; i < course.obstacles.length; i++) {
      final need = needFor(course, i).need;
      counts[need] = (counts[need] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /// The farthest any non-Jetpack part reaches with a jump, to tell a jump
  /// gap from a Jetpack gap.
  double _bestJumpDistance() {
    var best = 0.0;
    for (final moves in catalog.inSlot(Slot.moves)) {
      final stats = _calculator.statsFor(
        catalog.defaultRobot.withPart(Slot.moves, moves.id),
      );
      final speed = tuning.speedBase + tuning.speedPerPoint * stats.speed;
      final height = tuning.jumpBase + tuning.jumpPerPoint * stats.jump;
      final air = 2 * sqrt(2 * tuning.gravity * height) / tuning.gravity;
      best = max(best, speed * air);
    }
    return best;
  }

  /// RUN-13 step 3 and WRK-12: one part swap that gets [robot] past
  /// obstacle [index], tried in the headless simulator. Owned parts come
  /// first; if none works, a locked part that would. Null if nothing does.
  ({Part part, bool owned})? suggestPart(
    Course course,
    int index,
    RobotConfig robot,
    Set<String> owned,
  ) {
    bool passes(RobotConfig build) => canPass(course, index, build);

    const slots = [Slot.moves, Slot.body, Slot.arms];
    for (final wantOwned in [true, false]) {
      for (final slot in slots) {
        for (final part in catalog.inSlot(slot)) {
          if (owned.contains(part.id) != wantOwned) continue;
          if (part.id == robot.partIdFor(slot)) continue;
          if (passes(robot.withPart(slot, part.id))) {
            return (part: part, owned: wantOwned);
          }
        }
      }
    }
    return null;
  }

  /// Whether [robot] can get past obstacle [index] with perfect play, tried
  /// in the headless simulator. If not, retrying is pointless and the hint
  /// ladder offers new parts sooner (RUN-13).
  bool canPass(Course course, int index, RobotConfig robot) {
    final sim = RunSimulator(
      course: _probeCourse(course, index),
      stats: _calculator.statsFor(robot),
      tuning: tuning,
      autopilot: true,
    );
    final limit = 20 * tuning.stepsPerSecond;
    for (var i = 0; i < limit; i++) {
      sim.step();
      if (sim.phase == RunPhase.finished) return true;
      if (sim.phase == RunPhase.bumped || sim.phase == RunPhase.fallen) {
        return false;
      }
    }
    return false;
  }

  /// A short course holding obstacle [index] and anything overlapping it
  /// (a ceiling over a gap, a ramp before its gap), moved to start at 400.
  Course _probeCourse(Course course, int index) {
    final target = course.obstacles[index];
    var start = target.start;
    var end = target.end;
    final group = <Obstacle>[];
    for (final obstacle in course.obstacles) {
      final touches = obstacle.start <= end && obstacle.end >= start;
      if (touches) {
        group.add(obstacle);
        start = min(start, obstacle.start);
        end = max(end, obstacle.end);
      }
    }
    final shift = 400 - start;
    return Course(
      id: '${course.id}_probe',
      world: course.world,
      index: course.index,
      hintKey: course.hintKey,
      lengthPx: end + shift + 400,
      obstacles: [for (final o in group) _shifted(o, shift)],
    );
  }

  Obstacle _shifted(Obstacle o, double dx) => switch (o) {
    StepsObstacle() => o.copyWith(x: o.x + dx),
    GapObstacle() => o.copyWith(x: o.x + dx),
    BarGapObstacle() => o.copyWith(x: o.x + dx),
    MudObstacle() => o.copyWith(x: o.x + dx),
    LeafPileObstacle() => o.copyWith(x: o.x + dx),
    LowCeilingObstacle() => o.copyWith(x: o.x + dx),
    RampObstacle() => o.copyWith(x: o.x + dx),
    TimedGateObstacle() => o.copyWith(plateX: o.plateX + dx, x: o.x + dx),
    HeavySwitchObstacle() => o.copyWith(plateX: o.plateX + dx, x: o.x + dx),
  };
}
