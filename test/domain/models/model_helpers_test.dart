import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/models/stats.dart';

void main() {
  group('Obstacle.start and end', () {
    test('span along the course for every type', () {
      const cases = <(Obstacle, double, double)>[
        (
          Obstacle.steps(
            x: 100,
            stepWidth: 50,
            stepHeights: [24, 24],
            topWidth: 30,
          ),
          100,
          230,
        ),
        (Obstacle.gap(x: 10, width: 90), 10, 100),
        (Obstacle.barGap(x: 10, width: 400), 10, 410),
        (Obstacle.mud(x: 5, width: 50), 5, 55),
        (Obstacle.leafPile(x: 5, width: 60, height: 170), 5, 65),
        (Obstacle.lowCeiling(x: 5, width: 300, height: 200), 5, 305),
        (Obstacle.ramp(x: 5, width: 200), 5, 205),
        // Plate-and-door obstacles span from the plate to the door.
        (Obstacle.timedGate(plateX: 100, x: 700, openSeconds: 3), 100, 700),
        (Obstacle.heavySwitch(plateX: 200, x: 600), 200, 600),
      ];
      for (final (o, start, end) in cases) {
        expect(o.start, start, reason: '$o');
        expect(o.end, end, reason: '$o');
      }
    });
  });

  group('RobotConfig', () {
    const robot = RobotConfig(
      headId: 'h',
      bodyId: 'b',
      armsId: 'a',
      movesId: 'm',
      colour: 'sunny',
      decalId: 'd',
    );

    test('partIdFor and partIds follow slot order', () {
      expect(Slot.values.map(robot.partIdFor), ['h', 'b', 'a', 'm']);
      expect(robot.partIds, ['h', 'b', 'a', 'm']);
    });

    test('withPart changes one slot and keeps paint and decal', () {
      for (final slot in Slot.values) {
        final changed = robot.withPart(slot, 'x');
        expect(changed.partIdFor(slot), 'x');
        for (final other in Slot.values.where((s) => s != slot)) {
          expect(changed.partIdFor(other), robot.partIdFor(other));
        }
        expect(changed.colour, 'sunny');
        expect(changed.decalId, 'd');
      }
    });
  });

  test('Stats.valueOf and StatMods.valueOf read each stat', () {
    const stats = Stats(speed: 1, climb: 2, jump: 3, weight: 4, fuel: 5);
    const mods = StatMods(speed: -1, climb: 2, jump: 3, weight: 4, fuel: 5);
    expect(Stat.values.map(stats.valueOf), [1, 2, 3, 4, 5]);
    expect(Stat.values.map(mods.valueOf), [-1, 2, 3, 4, 5]);
    expect(
      const Stats(
        speed: 0,
        climb: 0,
        jump: 0,
        weight: 0,
        fuel: 0,
        abilities: {Ability.fan},
      ).has(Ability.fan),
      isTrue,
    );
  });

  test('Settings.helperMode follows play style (HLP-01)', () {
    expect(const Settings(playStyle: PlayStyle.little).helperMode, isTrue);
    expect(const Settings().helperMode, isFalse);
  });

  test('ProfileData.resultFor defaults to an empty result', () {
    const profile = ProfileData(
      robot: RobotConfig(
        headId: 'h',
        bodyId: 'b',
        armsId: 'a',
        movesId: 'm',
        colour: 'sunny',
      ),
      courseResults: {'c1': CourseResult(stars: 2, completed: true)},
    );
    expect(profile.resultFor('c1').stars, 2);
    expect(profile.resultFor('nope'), const CourseResult());
    expect(const Progress(profiles: [profile]).profile, profile);
  });
}
