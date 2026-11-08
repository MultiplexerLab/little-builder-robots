import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/run_outcome.dart';
import 'package:little_builder_robots/domain/rules/star_rules.dart';

void main() {
  RunOutcome run({bool finished = true, int bolts = 6, int falls = 0}) =>
      RunOutcome(
        finished: finished,
        boltsCollected: bolts,
        boltsOnCourse: 6,
        falls: falls,
      );

  group('RES-02 starsFor', () {
    test('finish, all bolts, no falls: 3 stars', () {
      final stars = starsFor(run());
      expect(stars, (finish: true, allBolts: true, noFalls: true));
      expect(stars.count, 3);
    });

    test('missing a bolt loses only the bolt star', () {
      final stars = starsFor(run(bolts: 5));
      expect(stars, (finish: true, allBolts: false, noFalls: true));
      expect(stars.count, 2);
    });

    test('a fall loses only the no-falls star', () {
      final stars = starsFor(run(falls: 1));
      expect(stars, (finish: true, allBolts: true, noFalls: false));
    });

    test('finishing alone is always worth 1 star', () {
      expect(starsFor(run(bolts: 0, falls: 4)).count, 1);
    });

    test('an unfinished run earns nothing', () {
      expect(starsFor(run(finished: false)).count, 0);
    });

    test('a course with no bolts gives the bolt star', () {
      const outcome = RunOutcome(
        finished: true,
        boltsCollected: 0,
        boltsOnCourse: 0,
        falls: 0,
      );
      expect(starsFor(outcome).allBolts, isTrue);
    });
  });

  group('RES-06 bestResult', () {
    test('first finish records stars and bolts', () {
      final result = bestResult(const CourseResult(), run(bolts: 5));
      expect(
        result,
        const CourseResult(stars: 2, bestBolts: 5, completed: true),
      );
    });

    test('a worse replay never lowers stars or bolts', () {
      const best = CourseResult(stars: 3, bestBolts: 6, completed: true);
      expect(bestResult(best, run(bolts: 1, falls: 2)), best);
    });

    test('a better replay raises stars', () {
      const earlier = CourseResult(stars: 1, bestBolts: 2, completed: true);
      expect(
        bestResult(earlier, run()),
        const CourseResult(stars: 3, bestBolts: 6, completed: true),
      );
    });

    test('rewardClaimed is kept', () {
      const earlier = CourseResult(
        stars: 1,
        completed: true,
        rewardClaimed: true,
      );
      expect(bestResult(earlier, run()).rewardClaimed, isTrue);
    });
  });
}
