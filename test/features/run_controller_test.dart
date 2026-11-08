import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';
import 'package:little_builder_robots/domain/rules/stat_calculator.dart';
import 'package:little_builder_robots/domain/sim/input_event.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';
import 'package:little_builder_robots/features/run/run_controller.dart';

import '../helpers/game_data.dart';

void main() {
  final catalog = loadCatalog();
  final tuning = loadTuning();
  final courses = {for (final c in loadWorld1()) c.index: c};
  final start = {
    for (final p in catalog.parts)
      if (p.unlock is StartUnlock) p.id,
  };

  RunController controller(
    Course course, {
    PlayStyle style = PlayStyle.big,
    bool loop = false,
    List<RunEvent>? events,
  }) => RunController(
    course: course,
    robot: catalog.defaultRobot,
    calculator: StatCalculator(catalog),
    coach: ObstacleCoach(catalog: catalog, tuning: tuning),
    tuning: tuning,
    playStyle: style,
    owned: start,
    onEvent: events?.add,
    loop: loop,
  );

  /// Real seconds of frames at 60 fps.
  void run(RunController c, double seconds, {bool Function()? until}) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      if (until?.call() ?? false) return;
      c.advance(1 / 60);
    }
  }

  group('RUN-13 hint ladder', () {
    test('parts that cannot pass: a shrug, then straight to new parts', () {
      // Wheels can't climb course 2's steps, so retrying is pointless.
      final c = controller(courses[2]!);
      final steps = <int>[];
      for (var i = 0; i < 3; i++) {
        run(c, 30, until: () => c.state.phase == RunPhase.bumped);
        steps.add(c.hint!.step);
        run(c, 3, until: () => c.state.phase == RunPhase.running);
      }
      expect(steps, [1, 3, 3]);
      expect(c.hint!.need, (need: Need.climb, pips: 2));
      expect(c.hint!.suggestion?.id, 'moves_legs');
    });

    test('Little Builder gets new parts at the first bump', () {
      final c = controller(courses[2]!, style: PlayStyle.little);
      run(c, 40, until: () => c.state.phase == RunPhase.bumped);
      expect(c.hint!.step, 3);
      expect(c.hint!.suggestion?.id, 'moves_legs');
    });

    test('parts that can pass: a timing tip, never a push for new parts', () {
      // Wheels can jump course 3's gaps; without a tap the robot falls.
      final c = controller(courses[3]!);
      final steps = <int>[];
      for (var i = 0; i < 3; i++) {
        run(c, 30, until: () => c.state.phase == RunPhase.fallen);
        steps.add(c.hint!.step);
        expect(c.hint!.timing, i > 0);
        run(c, 3, until: () => c.state.phase == RunPhase.running);
      }
      expect(steps, [1, 2, 2]);
    });

    test('tapping elsewhere dismisses the bubble', () {
      final c = controller(courses[2]!);
      run(c, 30, until: () => c.state.phase == RunPhase.bumped);
      c.dismissHint();
      expect(c.hint, isNull);
    });
  });

  group('RUN-11 pit stops', () {
    test('parks, swaps without touching the saved build, then goes', () {
      final c = controller(courses[4]!);
      // Wheels can't climb: swap to Legs is not possible before the pit
      // stop, so start course 4 from its pit stop instead.
      final legs = RunController(
        course: courses[4]!,
        robot: catalog.defaultRobot.withPart(Slot.moves, 'moves_legs'),
        calculator: StatCalculator(catalog),
        coach: ObstacleCoach(catalog: catalog, tuning: tuning),
        tuning: tuning,
        playStyle: PlayStyle.big,
        owned: start,
      );
      run(legs, 30, until: () => legs.state.phase == RunPhase.parked);
      expect(legs.state.phase, RunPhase.parked);
      legs.swapPart(catalog.byId('moves_wheels'));
      expect(legs.robot.movesId, 'moves_wheels');
      expect(legs.swappedAtPitStop, isTrue);
      legs.leavePitStop();
      run(legs, 30, until: () => legs.state.phase == RunPhase.finished);
      expect(legs.state.phase, RunPhase.finished);
      expect(c.robot, catalog.defaultRobot);
    });

    test('locked parts cannot be swapped in', () {
      final c = controller(courses[4]!)
        ..swapPart(catalog.byId('moves_jetpack'));
      expect(c.robot.movesId, 'moves_wheels');
    });
  });

  test('pause stops time; restart starts over', () {
    final c = controller(courses[1]!);
    run(c, 1);
    final x = c.state.x;
    c.pause();
    run(c, 1);
    expect(c.state.x, x);
    c
      ..resume()
      ..restart(catalog.defaultRobot);
    expect(c.state.x, 0);
  });

  test('RUN-14: the preview runs first and a tap skips it', () {
    final c = RunController(
      course: courses[1]!,
      robot: catalog.defaultRobot,
      calculator: StatCalculator(catalog),
      coach: ObstacleCoach(catalog: catalog, tuning: tuning),
      tuning: tuning,
      playStyle: PlayStyle.big,
      owned: start,
      preview: true,
    )..startPreview();
    run(c, 1);
    expect(c.previewing, isTrue);
    expect(c.state.x, 0);
    c.input(InputEvent.press);
    expect(c.previewing, isFalse);
  });

  test('TRK-02: Test Track loops at the flag', () {
    final events = <RunEvent>[];
    final c = controller(courses[1]!, loop: true, events: events);
    run(c, 60);
    expect(c.laps, greaterThanOrEqualTo(2));
    expect(events.whereType<FinishedEvent>().length, c.laps);
    expect(c.state.phase, RunPhase.running);
  });
}
