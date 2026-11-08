import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/part_catalog.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/models/run_outcome.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/models/sim_tuning.dart';
import 'package:little_builder_robots/domain/models/stats.dart';
import 'package:little_builder_robots/domain/rules/stat_calculator.dart';
import 'package:little_builder_robots/domain/sim/run_simulator.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';

/// One run's result: how it ended and how long it took in game seconds.
typedef SolverRun = ({RunOutcome outcome, double seconds});

/// Plays courses headless for the solver test (NFR-18), with the
/// simulator's autopilot playing perfectly.
///
/// Pit stops split a course into segments. Respawns never cross a pit stop,
/// so whether a segment can be passed depends only on the build used for
/// it. The solver checks each (segment, build) pair once instead of every
/// combination of builds.
class CourseSolver {
  CourseSolver({required this.catalog, required this.tuning})
    : _calculator = StatCalculator(catalog);

  final PartCatalog catalog;
  final SimTuning tuning;
  final StatCalculator _calculator;

  /// Plays [course] starting with builds.first, swapping to the next build
  /// at each pit stop.
  SolverRun run(
    Course course,
    List<RobotConfig> builds,
    PlayStyle style, {
    double maxSeconds = 180,
  }) {
    final sim = RunSimulator(
      course: course,
      stats: _calculator.statsFor(builds.first),
      tuning: tuning,
      playStyle: style,
      autopilot: true,
    );
    var next = 1;
    final maxSteps = (maxSeconds * tuning.stepsPerSecond).ceil();
    for (var i = 0; i < maxSteps && sim.phase != RunPhase.finished; i++) {
      sim.step();
      if (sim.phase == RunPhase.parked) {
        final build = builds[next < builds.length ? next++ : builds.length - 1];
        sim.resumeFromPitStop(_calculator.statsFor(build));
      }
    }
    return (outcome: sim.outcome, seconds: sim.state.elapsedSeconds);
  }

  /// The checkpoint each segment starts from: the start, then every pit
  /// stop.
  List<int> segmentStarts(Course course) => [
    0,
    for (final (i, checkpoint) in course.checkpoints.indexed)
      if (checkpoint.pitStop) i,
  ];

  /// Whether [build] gets from checkpoint [start] to the next pit stop or
  /// the flag.
  bool passes(
    Course course,
    int start,
    RobotConfig build,
    PlayStyle style, {
    double maxSeconds = 60,
  }) {
    final sim = RunSimulator(
      course: course,
      stats: _calculator.statsFor(build),
      tuning: tuning,
      playStyle: style,
      autopilot: true,
      startCheckpoint: start,
    );
    final maxSteps = (maxSeconds * tuning.stepsPerSecond).ceil();
    for (var i = 0; i < maxSteps; i++) {
      sim.step();
      if (sim.phase == RunPhase.finished || sim.phase == RunPhase.parked) {
        return true;
      }
    }
    return false;
  }

  /// Every build of [owned] parts with one distinct set of stats. Heads are
  /// style only, so the default head is kept.
  List<RobotConfig> buildsFrom(Set<String> owned) {
    List<Part> ownedIn(Slot slot) =>
        catalog.inSlot(slot).where((p) => owned.contains(p.id)).toList();

    final seen = <Stats>{};
    final base = catalog.defaultRobot;
    return [
      for (final moves in ownedIn(Slot.moves))
        for (final body in ownedIn(Slot.body))
          for (final arms in ownedIn(Slot.arms))
            if (base.copyWith(
                  movesId: moves.id,
                  bodyId: body.id,
                  armsId: arms.id,
                )
                case final robot when seen.add(_calculator.statsFor(robot)))
              robot,
    ];
  }

  /// A build per segment that finishes [course] with [owned] parts, or null
  /// if some segment has none.
  List<RobotConfig>? solve(Course course, Set<String> owned, PlayStyle style) {
    final builds = buildsFrom(owned);
    final plan = <RobotConfig>[];
    for (final start in segmentStarts(course)) {
      final build = builds.where((b) => passes(course, start, b, style));
      if (build.isEmpty) return null;
      plan.add(build.first);
    }
    return plan;
  }

  /// An intended build from course JSON as one RobotConfig per stage.
  List<RobotConfig> expand(IntendedBuild intended) {
    var robot = _withParts(catalog.defaultRobot, intended.parts);
    final stages = [robot];
    for (final swap in intended.pitStops) {
      robot = _withParts(robot, swap);
      stages.add(robot);
    }
    return stages;
  }

  RobotConfig _withParts(RobotConfig robot, List<String> partIds) {
    var result = robot;
    for (final id in partIds) {
      result = result.withPart(catalog.byId(id).slot, id);
    }
    return result;
  }
}
