import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/stats.dart';
import 'package:little_builder_robots/domain/sim/run_simulator.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';
import 'package:little_builder_robots/domain/sim/terrain.dart';

import '../../helpers/game_data.dart';

Course _course(List<Obstacle> obstacles, {List<Checkpoint>? checkpoints}) =>
    Course(
      id: 't',
      world: 1,
      index: 1,
      hintKey: 'h',
      lengthPx: 3000,
      obstacles: obstacles,
      checkpoints: checkpoints ?? const [Checkpoint(x: 0)],
    );

void main() {
  group('Terrain.fromCourse', () {
    test('flat ground is level 0 everywhere', () {
      final t = Terrain.fromCourse(_course(const []));
      expect(t.supportUnder(-50, 50), 0);
      expect(t.supportUnder(2000, 2100), 0);
      expect(t.hasHole(0, 3000), isFalse);
      expect(t.segments, hasLength(1));
    });

    test('steps rise by each height and drop back after the top', () {
      final t = Terrain.fromCourse(
        _course(const [
          Obstacle.steps(
            x: 100,
            stepWidth: 50,
            stepHeights: [10, 20],
            topWidth: 30,
          ),
        ]),
      );
      expect(t.supportUnder(60, 90), 0); // before
      expect(t.supportUnder(110, 140), 10); // first step
      expect(t.supportUnder(160, 190), 30); // second step: 10 + 20
      expect(t.supportUnder(205, 225), 30); // top
      expect(t.supportUnder(240, 260), 0); // back down at 230
      // A span over two levels stands on the higher one.
      expect(t.supportUnder(140, 160), 30);
    });

    test('a gap is a hole; a span half over it still stands', () {
      final t = Terrain.fromCourse(
        _course(const [Obstacle.gap(x: 100, width: 100)]),
      );
      expect(t.supportUnder(120, 180), isNull);
      expect(t.hasHole(120, 180), isTrue);
      expect(t.supportUnder(80, 120), 0);
      expect(t.hasHole(80, 120), isTrue);
      expect(t.hasHole(0, 100), isFalse); // touching the edge is not over it
    });

    test('a bar gap holds up only a robot that can grab', () {
      final t = Terrain.fromCourse(
        _course(const [Obstacle.barGap(x: 100, width: 200)]),
      );
      expect(t.supportUnder(150, 200), isNull);
      expect(t.supportUnder(150, 200, grab: true), 0);
      expect(t.hasHole(150, 200, grab: true), isFalse);
      expect(t.onBar(150, 200), isTrue);
      expect(t.onBar(350, 400), isFalse);
    });

    test('obstacles that do not change the ground leave it flat', () {
      final t = Terrain.fromCourse(
        _course(const [
          Obstacle.timedGate(plateX: 100, x: 400, openSeconds: 2),
          Obstacle.heavySwitch(plateX: 500, x: 800),
          Obstacle.mud(x: 900, width: 200),
          Obstacle.leafPile(x: 1200, width: 60, height: 170),
          Obstacle.lowCeiling(x: 1400, width: 300, height: 200),
          Obstacle.ramp(x: 1800, width: 200),
        ]),
      );
      expect(t.segments, hasLength(1));
      expect(t.supportUnder(0, 3000), 0);
    });
  });

  group('Terrain.risingEdge', () {
    final t = Terrain.fromCourse(
      _course(const [
        Obstacle.steps(x: 100, stepWidth: 50, stepHeights: [24]),
        Obstacle.gap(x: 400, width: 100),
      ]),
    );

    test('finds a step face higher than the feet', () {
      expect(t.risingEdge(90, 110, 0), (x: 100.0, height: 24.0));
    });

    test('ignores edges outside (from, to] and ground at or below y', () {
      expect(t.risingEdge(100, 110, 0), isNull);
      expect(t.risingEdge(80, 99, 0), isNull);
      expect(t.risingEdge(90, 110, 24), isNull);
    });

    test('airborne, any step face counts, however high the robot is', () {
      expect(t.risingEdge(90, 110, 200, airborne: true), isNotNull);
    });

    test("a gap's far wall counts only when below the far ground", () {
      expect(t.risingEdge(490, 510, -5), (x: 500.0, height: 0.0));
      expect(t.risingEdge(490, 510, 5, airborne: true), isNull);
    });
  });

  group('RunSimulator.returnToPitStop (RUN-13 step 3)', () {
    final tuning = loadTuning();
    const stats = Stats(speed: 2, climb: 0, jump: 0, weight: 1, fuel: 0);
    final course = _course(
      const [],
      checkpoints: const [
        Checkpoint(x: 0),
        Checkpoint(x: 500, pitStop: true),
        Checkpoint(x: 1000),
      ],
    );

    RunSimulator sim() =>
        RunSimulator(course: course, stats: stats, tuning: tuning);

    test('no pit stop behind at the start', () {
      expect(sim().pitStopBehind, isNull);
    });

    test('parks again at a pit stop already passed', () {
      final s = sim();
      while (s.phase != RunPhase.parked) {
        s.step();
      }
      s.resumeFromPitStop(stats);
      while (s.state.checkpointIndex < 2) {
        s.step();
      }
      expect(s.pitStopBehind, 1);
      s.returnToPitStop(1);
      expect(s.phase, RunPhase.parked);
      expect(s.state.x, 500);
      expect(s.state.checkpointIndex, 1);
    });

    test('refuses a checkpoint that is not a pit stop, or is ahead', () {
      final s = sim();
      expect(() => s.returnToPitStop(0), throwsStateError);
      expect(() => s.returnToPitStop(1), throwsStateError);
    });
  });
}
