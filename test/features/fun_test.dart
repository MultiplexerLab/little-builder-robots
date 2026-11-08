import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/core/widgets/robot_show_off.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';
import 'package:little_builder_robots/features/run/exclaimer.dart';
import 'package:little_builder_robots/features/run/game/effects.dart';

import '../helpers/game_data.dart';

void main() {
  const course = Course(
    id: 't',
    world: 1,
    index: 1,
    hintKey: 'h',
    obstacles: [
      Obstacle.gap(x: 100, width: 100, water: true),
      Obstacle.gap(x: 400, width: 100),
    ],
  );

  group('Exclaimer: when the robot shouts', () {
    test('fun moments get a shout', () {
      final e = Exclaimer(course);
      expect(e.react(const RunEvent.rampLaunch(0), 0), 'sayWhee');
      expect(e.react(const RunEvent.jetpackOn(), 2), 'sayWhoosh');
      expect(e.react(const RunEvent.swung(0), 4), 'saySwing');
      expect(e.react(const RunEvent.switchPressed(0), 6), 'sayClunk');
      expect(e.react(const RunEvent.gateOpened(0), 8), 'sayZoom');
    });

    test('a cooldown stops chatter, but the finish always cheers', () {
      final e = Exclaimer(course);
      expect(e.react(const RunEvent.rampLaunch(0), 0), 'sayWhee');
      expect(e.react(const RunEvent.jetpackOn(), 1), isNull);
      expect(e.react(const RunEvent.finished(), 1.1), 'sayHooray');
    });

    test('"Yum, bolts!" only for the first bolt', () {
      final e = Exclaimer(course);
      expect(e.react(const RunEvent.boltCollected(0), 0), 'sayYum');
      expect(e.react(const RunEvent.boltCollected(1), 5), isNull);
      e.reset();
      expect(e.react(const RunEvent.boltCollected(0), 0), 'sayYum');
    });

    test(
      'failures shout only the first time, so hints are not talked over',
      () {
        final e = Exclaimer(course);
        expect(e.react(const RunEvent.bumped(0), 0), isNull);
        expect(
          e.react(const RunEvent.bumped(0), 0, firstFailure: true),
          'sayBoing',
        );
        expect(
          e.react(const RunEvent.fell(0), 5, firstFailure: true),
          'saySplash',
        );
        expect(
          e.react(const RunEvent.fell(1), 10, firstFailure: true),
          'sayWhoops',
        );
      },
    );

    test('a bubble shows for a moment, then goes', () {
      final e = Exclaimer(course)..react(const RunEvent.finished(), 3);
      expect(e.currentAt(3.5), 'sayHooray');
      expect(e.currentAt(3 + Exclaimer.showFor + 0.01), isNull);
    });
  });

  test('every part has a trick that shows what it does', () {
    expect(trickFor('moves_wheels'), Trick.zoom);
    expect(trickFor('moves_legs'), Trick.march);
    expect(trickFor('moves_spring_feet'), Trick.boing);
    expect(trickFor('moves_jetpack'), Trick.liftOff);
    expect(trickFor('moves_tank_tracks'), Trick.rumble);
    expect(trickFor('body_heavy_frame'), Trick.thud);
    expect(trickFor('arms_grabber'), Trick.wave);
    expect(trickFor('head_gold'), Trick.spin);
    for (final part in loadCatalog().parts) {
      expect(trickFor(part.id), isA<Trick>(), reason: part.id);
    }
  });

  testWidgets('RobotShowOff plays every trick and settles back', (
    tester,
  ) async {
    final robot = loadCatalog().defaultRobot;
    for (final (i, trick) in Trick.values.indexed) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RobotShowOff(config: robot, trick: trick, play: i),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RobotShowOff(config: robot, trick: trick, play: i + 1),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(RobotShowOff.duration);
      expect(tester.takeException(), isNull, reason: '$trick');
    }
  });

  test('effects stay capped and clear away', () {
    final fx = Effects();
    for (var i = 0; i < 20; i++) {
      fx
        ..confetti(0, 0)
        ..boltCollected(0, 0);
    }
    expect(fx.particles.length, lessThanOrEqualTo(220));
    fx.bump(0, 0);
    expect(fx.shake, greaterThan(0));
    for (var i = 0; i < 300; i++) {
      fx.update(1 / 60);
    }
    expect(fx.particles, isEmpty);
    expect(fx.shake, 0);
  });

  test('every exclamation has a voice clip (AUD-02)', () {
    const keys = [
      'sayWhee', 'sayBoing', 'saySplash', 'sayWhoops', 'sayWhoosh', //
      'saySwing', 'sayClunk', 'sayZoom', 'sayHooray', 'sayYum',
    ];
    for (final key in keys) {
      expect(
        File('assets/audio/voice/en_GB/$key.m4a').existsSync(),
        isTrue,
        reason: key,
      );
    }
  });
}
