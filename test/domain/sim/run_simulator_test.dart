import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/models/stats.dart';
import 'package:little_builder_robots/domain/sim/input_event.dart';
import 'package:little_builder_robots/domain/sim/run_simulator.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';

import '../../helpers/game_data.dart';
import 'course_solver.dart';

void main() {
  final tuning = loadTuning();
  final catalog = loadCatalog();
  final hz = tuning.stepsPerSecond;

  Stats stats({
    int speed = 2,
    int climb = 0,
    int jump = 0,
    int weight = 1,
    int fuel = 0,
    Set<Ability> abilities = const {},
  }) => Stats(
    speed: speed,
    climb: climb,
    jump: jump,
    weight: weight,
    fuel: fuel,
    abilities: abilities,
  );

  final jetpack = stats(speed: 3, fuel: 3, abilities: {Ability.jetpack});

  Course course({
    double length = 2000,
    List<Obstacle> obstacles = const [],
    List<Checkpoint> checkpoints = const [Checkpoint(x: 0)],
    List<BoltSpot> bolts = const [],
  }) => Course(
    id: 'test',
    world: 1,
    index: 1,
    hintKey: 'hint',
    lengthPx: length,
    obstacles: obstacles,
    checkpoints: checkpoints,
    bolts: bolts,
  );

  RunSimulator sim(
    Course c,
    Stats s, {
    PlayStyle style = PlayStyle.big,
  }) => RunSimulator(course: c, stats: s, tuning: tuning, playStyle: style);

  /// Steps until [until] is true or [seconds] of steps pass; returns every
  /// event. With [autopilot] it taps at every gap edge.
  List<RunEvent> play(
    RunSimulator s, {
    double seconds = 30,
    bool autopilot = false,
    bool Function(RunSimulator)? until,
  }) {
    final events = <RunEvent>[];
    for (var i = 0; i < seconds * hz; i++) {
      if (until?.call(s) ?? s.phase == RunPhase.finished) break;
      if (autopilot && s.atGapEdge) s.input(InputEvent.press);
      events.addAll(s.step());
    }
    return events;
  }

  group('flat ground (RUN-01, RUN-09)', () {
    test('speed is 120 + 40 x Speed px/s', () {
      for (final speed in [0, 2, 4]) {
        final s = sim(course(), stats(speed: speed));
        play(s);
        expect(s.phase, RunPhase.finished);
        expect(
          s.state.elapsedSeconds,
          closeTo(2000 / (120 + 40 * speed), 0.02),
        );
      }
    });

    test('finishing fires one finished event and stops', () {
      final s = sim(course(), stats());
      final events = play(s);
      expect(events.whereType<FinishedEvent>(), hasLength(1));
      final x = s.state.x;
      expect(s.step(), isEmpty);
      expect(s.state.x, x);
    });

    test('runs are deterministic: same build and taps, same result', () {
      List<RunState> trace() {
        final s = sim(
          course(obstacles: [const Obstacle.gap(x: 600, width: 100)]),
          stats(),
        );
        final states = <RunState>[];
        for (var i = 0; i < 6 * hz; i++) {
          if (i == 150 || i == 400) s.input(InputEvent.press);
          s.step();
          states.add(s.state);
        }
        return states;
      }

      expect(trace(), trace());
    });
  });

  group('jump (RUN-02, SRS 4.1)', () {
    test('peak height is 60 + 30 x Jump px', () {
      for (final jump in [0, 3]) {
        final s = sim(course(), stats(jump: jump))..input(InputEvent.press);
        var peak = 0.0;
        for (var i = 0; i < hz; i++) {
          s.step();
          if (s.state.y > peak) peak = s.state.y;
        }
        expect(peak, closeTo(60 + 30 * jump, 2));
      }
    });

    test('a tap just before landing still jumps (buffer)', () {
      final s = sim(course(), stats())..input(InputEvent.press);
      play(s, until: (s) => s.state.vy < 0 && s.state.y < 5);
      s.input(InputEvent.press);
      final events = play(s, seconds: 0.2);
      expect(events.whereType<JumpedEvent>(), hasLength(1));
    });
  });

  group('steps (RUN-03, SRS 4.3)', () {
    final steps = course(
      obstacles: [
        const Obstacle.steps(
          x: 600,
          stepWidth: 160,
          stepHeights: [48, 48],
          topWidth: 200,
        ),
      ],
    );

    test('Climb 2 (48 px) climbs 48 px steps', () {
      final s = sim(steps, stats(climb: 2));
      final events = play(s);
      expect(s.phase, RunPhase.finished);
      expect(events.whereType<BumpedEvent>(), isEmpty);
    });

    test('Climb 1 bumps, then rolls back after 1.5 s', () {
      final s = sim(steps, stats(climb: 1));
      final events = play(s, until: (s) => s.phase == RunPhase.bumped);
      expect(s.state.x + tuning.robotHalfWidth, closeTo(600, 0.01));
      expect(events, isNot(contains(isA<FellEvent>())));
      final after = play(s, seconds: 1.6, until: (_) => false);
      expect(after.first, const RunEvent.respawned(0));
      expect(s.state.bumps, 1);
      expect(s.state.falls, 0);
    });

    test('the bump counts against the steps for the hint ladder', () {
      final s = sim(steps, stats());
      final events = play(s, until: (s) => s.phase == RunPhase.bumped);
      expect(events.last, const RunEvent.bumped(0));
    });

    test('jumping into a step face bumps, even with Climb', () {
      final s = sim(steps, stats(climb: 5, jump: 5));
      play(s, until: (s) => s.state.x > 520);
      s.input(InputEvent.press);
      play(s, until: (s) => s.phase != RunPhase.running);
      expect(s.phase, RunPhase.bumped);
    });

    test('walking off the top drops safely to the ground', () {
      final s = sim(steps, stats(climb: 2));
      final events = play(s);
      expect(events.whereType<LandedEvent>(), hasLength(1));
      expect(s.state.falls, 0);
    });
  });

  group('gaps (RUN-04, SRS 4.4)', () {
    final gap = course(
      obstacles: [const Obstacle.gap(x: 600, width: 100)],
      checkpoints: const [Checkpoint(x: 0), Checkpoint(x: 300)],
    );

    test('no jump: falls, returns to the checkpoint after 1 s', () {
      final s = sim(gap, stats());
      final events = play(s, until: (s) => s.phase == RunPhase.fallen);
      expect(events.last, const RunEvent.fell(0));
      expect(s.state.falls, 1);
      final waited = play(s, until: (s) => s.phase == RunPhase.running);
      expect(waited.single, const RunEvent.respawned(1));
      expect(s.state.x, 300);
      expect(s.state.onGround, isTrue);
    });

    test('a jump at the edge clears it', () {
      final s = sim(gap, stats());
      play(s, autopilot: true);
      expect(s.phase, RunPhase.finished);
      expect(s.state.falls, 0);
    });

    test('a gap too wide for the jump still fails', () {
      // Speed 5, Jump 5 carries about 310 px, plus the robot's width.
      final wide = course(obstacles: [const Obstacle.gap(x: 600, width: 400)]);
      final s = sim(wide, stats(speed: 5, jump: 5));
      play(s, autopilot: true, until: (s) => s.phase == RunPhase.fallen);
      expect(s.phase, RunPhase.fallen);
    });
  });

  group('timed gates (SRS 4.3)', () {
    final gate = course(
      length: 1600,
      obstacles: [
        const Obstacle.timedGate(plateX: 300, x: 1000, openSeconds: 3.1),
      ],
    );

    test('Speed 3 gets through, Speed 2 bumps at the gate', () {
      final fast = sim(gate, stats(speed: 3));
      final events = play(fast);
      expect(fast.phase, RunPhase.finished);
      expect(events, contains(const RunEvent.gateOpened(0)));

      final slow = sim(gate, stats());
      final slowEvents = play(
        slow,
        until: (s) => s.phase == RunPhase.bumped,
      );
      expect(slowEvents.last, const RunEvent.bumped(0));
    });

    test('the gate resets after a respawn', () {
      final s = sim(gate, stats());
      play(s, until: (s) => s.phase == RunPhase.bumped);
      play(s, until: (s) => s.phase == RunPhase.running);
      expect(s.state.openGates, isEmpty);
      final again = play(s, seconds: 2);
      expect(again, contains(const RunEvent.gateOpened(0)));
    });

    test('state reports the time left on an open gate', () {
      final s = sim(gate, stats(speed: 3));
      play(s, until: (s) => s.state.x >= 300 + 240);
      expect(s.state.openGates[0], closeTo(2.1, 0.02));
    });
  });

  group('pit stops (RUN-11)', () {
    final pit = course(
      checkpoints: const [Checkpoint(x: 0), Checkpoint(x: 800, pitStop: true)],
    );

    test('parks on the pad, then goes on with the new stats', () {
      final s = sim(pit, stats());
      final events = play(s, until: (s) => s.phase == RunPhase.parked);
      expect(events.last, const RunEvent.parked(1));
      expect(s.state.x, 800);
      expect(play(s, seconds: 1, until: (_) => false), isEmpty);

      s.resumeFromPitStop(stats(speed: 4));
      final before = s.state.x;
      s.step();
      expect(s.state.x - before, closeTo(280 / hz, 1e-9));
    });

    test('a respawn at the pit stop does not park again', () {
      final c = course(
        obstacles: [const Obstacle.gap(x: 1200, width: 100)],
        checkpoints: const [
          Checkpoint(x: 0),
          Checkpoint(x: 800, pitStop: true),
        ],
      );
      final s = sim(c, stats());
      play(s, until: (s) => s.phase == RunPhase.parked);
      s.resumeFromPitStop(stats());
      play(s, until: (s) => s.phase == RunPhase.fallen);
      final events = play(s, autopilot: true);
      expect(events, contains(const RunEvent.respawned(1)));
      expect(events.whereType<ParkedEvent>(), isEmpty);
      expect(s.phase, RunPhase.finished);
    });

    test('resuming when not parked throws', () {
      expect(
        () => sim(pit, stats()).resumeFromPitStop(stats()),
        throwsStateError,
      );
    });
  });

  group('bolts (RUN-06)', () {
    test('collected on contact, once, and kept after a fall', () {
      final c = course(
        obstacles: [const Obstacle.gap(x: 600, width: 100)],
        bolts: const [BoltSpot(x: 300, y: 24), BoltSpot(x: 900, y: 24)],
      );
      final s = sim(c, stats());
      final events = play(s, until: (s) => s.phase == RunPhase.fallen);
      expect(events, contains(const RunEvent.boltCollected(0)));
      play(s, until: (s) => s.phase == RunPhase.running);
      expect(s.state.collectedBolts, {0});
      final rest = play(s, autopilot: true);
      expect(rest.whereType<BoltCollectedEvent>().single.boltIndex, 1);
      expect(s.outcome.boltsCollected, 2);
      expect(s.outcome.falls, 1);
    });

    test('a bolt above the robot is missed without a jump', () {
      final c = course(bolts: const [BoltSpot(x: 300, y: 120)]);
      final s = sim(c, stats());
      play(s);
      expect(s.outcome.boltsCollected, 0);
    });
  });

  group('Helper mode (HLP-02, HLP-04, HLP-05)', () {
    final gap = course(obstacles: [const Obstacle.gap(x: 600, width: 100)]);

    test('jumps gaps by itself', () {
      final s = sim(gap, stats(), style: PlayStyle.little);
      play(s);
      expect(s.phase, RunPhase.finished);
      expect(s.state.falls, 0);
    });

    test('still falls when the stats cannot clear the gap', () {
      final wide = course(obstacles: [const Obstacle.gap(x: 600, width: 300)]);
      final s = sim(wide, stats(), style: PlayStyle.little);
      final events = play(s, until: (s) => s.phase == RunPhase.fallen);
      expect(events, contains(const RunEvent.jumped()));
      expect(s.phase, RunPhase.fallen);
    });

    test('runs at 80% speed', () {
      final big = sim(course(), stats());
      final little = sim(course(), stats(), style: PlayStyle.little);
      play(big);
      play(little, seconds: 60);
      expect(little.state.tick / big.state.tick, closeTo(1 / 0.8, 0.01));
      expect(
        little.state.elapsedSeconds,
        closeTo(big.state.elapsedSeconds, 0.02),
      );
    });

    test('a tap is a happy hop that changes nothing', () {
      final s = sim(course(), stats(), style: PlayStyle.little)
        ..input(InputEvent.press);
      final events = s.step();
      expect(events, [const RunEvent.happyHop()]);
      expect(s.state.onGround, isTrue);
    });
  });

  group('Jetpack (RUN-02, SRS 4.1)', () {
    final wide = course(obstacles: [const Obstacle.gap(x: 600, width: 400)]);

    test('holding keeps thrust on until fuel (Fuel x 0.6 s) runs out', () {
      final s = sim(course(length: 6000), jetpack)..input(InputEvent.press);
      final events = play(s, until: (s) => s.state.fuel == 0);
      expect(events.whereType<JetpackOnEvent>(), hasLength(1));
      expect(s.state.elapsedSeconds, closeTo(1.8, 0.02));
      expect(s.state.y, greaterThan(300));
    });

    test('fuel refills on landing', () {
      final s = sim(course(length: 6000), jetpack)..input(InputEvent.press);
      play(s, until: (s) => s.state.fuel == 0);
      s.input(InputEvent.release);
      play(s, until: (s) => s.state.onGround);
      expect(s.state.fuel, s.state.fuelMax);
    });

    test('the autopilot hovers across a gap no jump can clear', () {
      final s = sim(wide, jetpack, style: PlayStyle.little);
      play(s);
      expect(s.phase, RunPhase.finished);
      expect(s.state.falls, 0);
    });

    test('hitting a ceiling ends thrust until landing (SRS 4.3)', () {
      final c = course(
        length: 6000,
        obstacles: [const Obstacle.lowCeiling(x: 0, width: 3000, height: 200)],
      );
      final s = sim(c, jetpack)..input(InputEvent.press);
      final events = play(
        s,
        until: (s) => s.state.onGround && s.state.tick > 5,
      );
      expect(events, contains(const RunEvent.ceilingBonk()));
      expect(events.whereType<JetpackOnEvent>(), hasLength(1));
    });
  });

  group('bars, switches, mud, leaves and ramps (SRS 4.3)', () {
    test('Grabber arms swing across a bar gap; a jump falls short', () {
      final c = course(obstacles: [const Obstacle.barGap(x: 600, width: 400)]);
      final grab = sim(c, stats(abilities: {Ability.grab}));
      final events = play(grab, autopilot: true);
      expect(grab.phase, RunPhase.finished);
      expect(events.whereType<SwungEvent>(), hasLength(1));
      expect(events.whereType<JumpedEvent>(), isEmpty);

      final jumper = sim(c, stats(speed: 3, jump: 3));
      play(jumper, autopilot: true, until: (s) => s.phase == RunPhase.fallen);
      expect(jumper.phase, RunPhase.fallen);
    });

    final door = course(
      obstacles: [const Obstacle.heavySwitch(plateX: 400, x: 800)],
    );

    test('Weight 4 presses a heavy switch and opens the door', () {
      final s = sim(door, stats(weight: 4));
      final events = play(s);
      expect(events, contains(const RunEvent.switchPressed(0)));
      expect(s.phase, RunPhase.finished);
    });

    test('a light robot bumps at the shut door', () {
      final s = sim(door, stats(weight: 3));
      final events = play(s, until: (s) => s.phase == RunPhase.bumped);
      expect(events.last, const RunEvent.bumped(0));
    });

    final mud = course(obstacles: [const Obstacle.mud(x: 600, width: 400)]);

    test('Weight 3 or less crosses mud', () {
      final s = sim(mud, stats(weight: 3));
      play(s);
      expect(s.phase, RunPhase.finished);
    });

    test('Weight 4 sinks in mud, unless mudproof', () {
      final heavy = sim(mud, stats(weight: 4));
      final events = play(heavy, until: (s) => s.phase == RunPhase.bumped);
      expect(events.last, const RunEvent.bumped(0));
      expect(heavy.state.falls, 0);

      final tracks = sim(mud, stats(weight: 4, abilities: {Ability.mudproof}));
      play(tracks);
      expect(tracks.phase, RunPhase.finished);
    });

    final leaves = course(
      obstacles: [const Obstacle.leafPile(x: 800, width: 60, height: 170)],
    );

    test('leaf piles stop a robot that can neither blow nor fly', () {
      final s = sim(leaves, stats(speed: 3, jump: 3));
      play(s, autopilot: true, until: (s) => s.phase == RunPhase.bumped);
      expect(s.phase, RunPhase.bumped);
    });

    test('Fan arms blow leaves away; a Jetpack flies over them', () {
      final fan = sim(leaves, stats(abilities: {Ability.fan}));
      final events = play(fan);
      expect(events, contains(const RunEvent.leavesBlown(0)));
      expect(fan.phase, RunPhase.finished);

      final flyer = sim(leaves, jetpack, style: PlayStyle.little);
      play(flyer);
      expect(flyer.phase, RunPhase.finished);
      expect(flyer.state.bumps, 0);
    });

    test('a ramp throws fast robots further', () {
      final c = course(
        obstacles: [
          const Obstacle.ramp(x: 400, width: 200),
          const Obstacle.gap(x: 600, width: 280),
        ],
      );
      final fast = sim(c, stats(speed: 4));
      final events = play(fast, autopilot: true);
      expect(events, contains(const RunEvent.rampLaunch(0)));
      expect(fast.phase, RunPhase.finished);

      final slow = sim(c, stats(speed: 3, jump: 3));
      play(slow, autopilot: true, until: (s) => s.phase == RunPhase.fallen);
      expect(slow.phase, RunPhase.fallen);
    });
  });

  group('tutorial (ONB-02)', () {
    test('waits at the first gap until the child taps', () {
      final c = course(obstacles: [const Obstacle.gap(x: 600, width: 100)]);
      final s = RunSimulator(
        course: c,
        stats: stats(),
        tuning: tuning,
        waitAtFirstGap: true,
      );
      play(s, seconds: 10, until: (s) => s.state.waitingForTap);
      final x = s.state.x;
      play(s, seconds: 3, until: (_) => false);
      expect(s.state.x, x);
      expect(s.state.waitingForTap, isTrue);
      s.input(InputEvent.press);
      play(s);
      expect(s.phase, RunPhase.finished);
      expect(s.state.falls, 0);
    });
  });

  test('can start from a pit stop without parking there', () {
    final c = course(
      checkpoints: const [Checkpoint(x: 0), Checkpoint(x: 800, pitStop: true)],
    );
    final s = RunSimulator(
      course: c,
      stats: stats(),
      tuning: tuning,
      startCheckpoint: 1,
    );
    expect(s.state.x, 800);
    final events = play(s);
    expect(events.whereType<ParkedEvent>(), isEmpty);
    expect(s.phase, RunPhase.finished);
  });

  group('World 1 courses need their intended parts (SRS 4.5)', () {
    final solver = CourseSolver(catalog: catalog, tuning: tuning);
    final courses = {for (final c in loadWorld1()) c.index: c};
    final base = catalog.defaultRobot;

    bool finishes(int index, List<String> moves) => solver
        .run(courses[index]!, [
          for (final id in moves) base.copyWith(movesId: id),
        ], PlayStyle.big)
        .outcome
        .finished;

    test('course 2: Wheels cannot climb the steps', () {
      expect(finishes(2, ['moves_wheels']), isFalse);
    });

    test('course 4: Legs alone are too slow for the gate', () {
      expect(finishes(4, ['moves_legs', 'moves_legs']), isFalse);
      expect(finishes(4, ['moves_wheels', 'moves_wheels']), isFalse);
    });

    bool finishesWith(int index, RobotConfig robot) =>
        solver.run(courses[index]!, [robot], PlayStyle.big).outcome.finished;

    test('course 6: Wheels fly off the ramp; Spring feet fall short', () {
      expect(finishes(6, ['moves_wheels']), isTrue);
      expect(finishes(6, ['moves_spring_feet']), isFalse);
      expect(finishes(6, ['moves_legs']), isFalse);
    });

    test('course 7: only the Jetpack crosses the wide gaps', () {
      expect(finishes(7, ['moves_spring_feet']), isFalse);
      expect(finishes(7, ['moves_wheels']), isFalse);
    });

    test('course 10: only a heavy robot opens the doors', () {
      expect(finishes(10, ['moves_wheels']), isFalse);
      expect(
        finishesWith(10, base.copyWith(bodyId: 'body_heavy_frame')),
        isTrue,
      );
    });

    test('course 11: Heavy frame alone sinks in the mud', () {
      expect(
        finishesWith(11, base.copyWith(bodyId: 'body_heavy_frame')),
        isFalse,
      );
    });

    test('course 12: bars need Grabber arms (or a Jetpack)', () {
      expect(finishes(12, ['moves_spring_feet']), isFalse);
      expect(finishesWith(12, base.copyWith(armsId: 'arms_grabber')), isTrue);
    });

    test('course 13: leaf piles need a Jetpack or Fan arms', () {
      expect(finishes(13, ['moves_spring_feet']), isFalse);
      expect(finishesWith(13, base.copyWith(armsId: 'arms_fan')), isTrue);
    });

    test('course 5: only Spring feet clear the big gaps', () {
      expect(finishes(5, ['moves_wheels']), isFalse);
      expect(finishes(5, ['moves_legs']), isFalse);
      expect(finishes(5, ['moves_spring_feet']), isTrue);
    });
  });
}
