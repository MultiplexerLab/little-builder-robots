import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations_en.dart';
import 'package:little_builder_robots/core/l10n/l10n_lookup.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/run_outcome.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/models/stats.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';
import 'package:little_builder_robots/domain/rules/star_rules.dart';
import 'package:little_builder_robots/domain/sim/input_event.dart';
import 'package:little_builder_robots/domain/sim/run_simulator.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';
import 'package:little_builder_robots/features/run/run_screen.dart';

import '../helpers/game_data.dart';

void main() {
  final tuning = loadTuning();

  Stats stats({int speed = 2, int jump = 0}) =>
      Stats(speed: speed, climb: 0, jump: jump, weight: 1, fuel: 0);

  const flat = Course(
    id: 'g',
    world: 1,
    index: 1,
    hintKey: 'h',
    lengthPx: 2000,
    gear: BoltSpot(x: 1000, y: 200),
  );

  RunSimulator autopilot(Course c, Stats s) =>
      RunSimulator(course: c, stats: s, tuning: tuning, autopilot: true);

  List<RunEvent> play(RunSimulator s) {
    final events = <RunEvent>[];
    for (var i = 0; i < 30 * tuning.stepsPerSecond; i++) {
      if (s.phase == RunPhase.finished) break;
      events.addAll(s.step());
    }
    return events;
  }

  group('RUN-16 golden gears', () {
    test('a high jump reaches the gear; a low one cannot', () {
      final springy = autopilot(flat, stats(speed: 3, jump: 3));
      final events = play(springy);
      expect(events, contains(const RunEvent.gearFound()));
      expect(springy.outcome.foundGear, isTrue);
      expect(springy.state.falls + springy.state.bumps, 0);

      final wheels = autopilot(flat, stats(speed: 4));
      play(wheels);
      expect(wheels.outcome.foundGear, isFalse);
      expect(wheels.phase, RunPhase.finished);
    });

    test('a Big Builder tap at the right moment reaches it too', () {
      final s = RunSimulator(
        course: flat,
        stats: stats(speed: 3, jump: 3),
        tuning: tuning,
      );
      final events = <RunEvent>[];
      for (var i = 0; i < 30 * tuning.stepsPerSecond; i++) {
        if (s.phase == RunPhase.finished) break;
        if ((s.state.x - 900).abs() < 2) s.input(InputEvent.press);
        events.addAll(s.step());
      }
      expect(events, contains(const RunEvent.gearFound()));
    });

    test('the autopilot never jumps for a gear near an obstacle', () {
      const risky = Course(
        id: 'r',
        world: 1,
        index: 1,
        hintKey: 'h',
        lengthPx: 2000,
        gear: BoltSpot(x: 1000, y: 200),
        obstacles: [
          Obstacle.steps(x: 1080, stepWidth: 160, stepHeights: [48]),
        ],
      );
      // Able to climb the step, so only a jump into its face would bump.
      final s = autopilot(
        risky,
        const Stats(speed: 3, climb: 2, jump: 3, weight: 1, fuel: 0),
      );
      play(s);
      expect(s.state.bumps, 0, reason: 'jumping into the step would bump');
      expect(s.phase, RunPhase.finished);
    });

    test('a gear counts once the course is finished, and stays found', () {
      const found = RunOutcome(
        finished: true,
        boltsCollected: 0,
        boltsOnCourse: 0,
        falls: 0,
        foundGear: true,
      );
      final best = bestResult(const CourseResult(), found);
      expect(best.foundGear, isTrue);
      final later = bestResult(best, found.copyWith(foundGear: false));
      expect(later.foundGear, isTrue);
      final unfinished = bestResult(
        const CourseResult(),
        found.copyWith(finished: false),
      );
      expect(unfinished.foundGear, isFalse);
    });
  });

  test('climbing never falls through a step, whatever the speed', () {
    // Speed 3 moves exactly 2 px a step, so the front lands right on the
    // edge at x = 1080. This used to drop the robot through the step.
    for (final x in [1080.0, 1081.0, 1079.5]) {
      for (final speed in [2, 3, 4]) {
        final c = Course(
          id: 's',
          world: 1,
          index: 1,
          hintKey: 'h',
          lengthPx: 2000,
          obstacles: [
            Obstacle.steps(x: x, stepWidth: 160, stepHeights: const [48]),
          ],
        );
        final s = RunSimulator(
          course: c,
          stats: Stats(speed: speed, climb: 2, jump: 0, weight: 1, fuel: 0),
          tuning: tuning,
        );
        play(s);
        expect(s.phase, RunPhase.finished, reason: 'x=$x speed=$speed');
        expect(s.state.falls + s.state.bumps, 0, reason: 'x=$x speed=$speed');
      }
    }
  });

  group('hints: puzzles for Big Builder, answers for Little Builder', () {
    final l10n = AppLocalizationsEn();
    final courses = loadWorld1();

    test('every course has both hint versions, with voice clips', () {
      for (final c in courses) {
        for (final style in PlayStyle.values) {
          final key = courseHintKey(c, style);
          expect(lookup(l10n, key), isNot(key), reason: key);
          expect(
            File('assets/audio/voice/en_GB/$key.m4a').existsSync(),
            isTrue,
            reason: key,
          );
        }
        expect(
          courseHintKey(c, PlayStyle.big),
          isNot(courseHintKey(c, PlayStyle.little)),
        );
      }
    });

    test('every need has a puzzle hint, and timing tips exist', () {
      for (final need in Need.values) {
        final key = puzzleHintKey(need);
        expect(lookup(l10n, key), isNot(key), reason: key);
        expect(
          File('assets/audio/voice/en_GB/$key.m4a').existsSync(),
          isTrue,
          reason: key,
        );
      }
      for (final key in ['hintJumpTiming', 'hintFlyTiming', 'sayGear']) {
        expect(lookup(l10n, key), isNot(key), reason: key);
        expect(
          File('assets/audio/voice/en_GB/$key.m4a').existsSync(),
          isTrue,
          reason: key,
        );
      }
    });

    test('puzzle hints describe the problem without naming a part', () {
      const parts = [
        'Legs', 'legs', 'Wheels', 'wheels', 'Spring', 'springy', //
        'Jetpack', 'Grabber', 'Fan', 'arms',
      ];
      final texts = [
        for (final c in courses) lookup(l10n, courseHintKey(c, PlayStyle.big)),
        for (final need in Need.values) lookup(l10n, puzzleHintKey(need)),
      ];
      for (final text in texts) {
        for (final part in parts) {
          expect(text, isNot(contains(part)), reason: text);
        }
      }
    });
  });
}
