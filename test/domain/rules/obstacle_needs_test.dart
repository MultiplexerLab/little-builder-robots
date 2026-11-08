import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';

import '../../helpers/game_data.dart';

void main() {
  final catalog = loadCatalog();
  final coach = ObstacleCoach(catalog: catalog, tuning: loadTuning());
  final courses = {for (final c in loadWorld1()) c.index: c};
  final start = {
    for (final p in catalog.parts)
      if (p.unlock is StartUnlock) p.id,
  };

  group('RUN-12 needFor', () {
    test('48 px steps need Climb 2', () {
      expect(coach.needFor(courses[2]!, 0), (need: Need.climb, pips: 2));
    });

    test('timed gates need Speed 3 (SRS 4.3)', () {
      expect(coach.needFor(courses[4]!, 2), (need: Need.speed, pips: 3));
    });

    test('small gaps need a jump; 400 px gaps need the Jetpack', () {
      expect(coach.needFor(courses[3]!, 0).need, Need.jump);
      expect(coach.needFor(courses[7]!, 0).need, Need.jetpack);
    });

    test('a ramp and its gap ask for speed', () {
      // Course 6: a hop (0), then a ramp (1) and its gap (2).
      final ramp = coach.needFor(courses[6]!, 1);
      expect(ramp.need, Need.speed);
      expect(ramp.pips, 4);
      expect(coach.needFor(courses[6]!, 2), ramp);
    });

    test('switches, mud, bars, leaves', () {
      expect(coach.needFor(courses[10]!, 0), (need: Need.heavy, pips: 4));
      expect(coach.needFor(courses[9]!, 0), (need: Need.light, pips: 3));
      expect(coach.needFor(courses[12]!, 0).need, Need.grab);
      expect(coach.needFor(courses[13]!, 0).need, Need.fan);
    });

    test('mainNeed picks the most common need (MAP-04)', () {
      expect(coach.mainNeed(courses[1]!), isNull);
      expect(coach.mainNeed(courses[2]!), Need.climb);
      expect(coach.mainNeed(courses[5]!), Need.jump);
    });
  });

  group('RUN-13 suggestPart', () {
    test('Wheels stuck on steps: suggests owned Legs', () {
      final s = coach.suggestPart(
        courses[2]!,
        0,
        catalog.defaultRobot,
        start,
      );
      expect(s?.part.id, 'moves_legs');
      expect(s?.owned, isTrue);
    });

    test('Legs too slow for a gate: suggests Wheels', () {
      final s = coach.suggestPart(
        courses[4]!,
        2,
        catalog.defaultRobot.withPart(Slot.moves, 'moves_legs'),
        start,
      );
      expect(s?.part.id, 'moves_wheels');
    });

    test('nothing owned works: suggests a locked part that would', () {
      final s = coach.suggestPart(
        courses[13]!,
        0,
        catalog.defaultRobot,
        start,
      );
      expect(s?.owned, isFalse);
      expect(['moves_jetpack', 'arms_fan'], contains(s?.part.id));
    });
  });
}
