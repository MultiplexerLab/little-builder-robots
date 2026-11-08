import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/domain/models/course.dart';

import '../../helpers/game_data.dart';

/// Checks every course JSON against SRS 4.5 and against layouts the
/// simulator can't handle fairly.
void main() {
  final tuning = loadTuning();
  final catalog = loadCatalog();

  for (final course in loadWorld1()) {
    group(course.id, () {
      final (rewardBolts, rewardPartId, boltCount) = world1Table[course.index]!;

      test('matches the SRS 4.5 table', () {
        expect(course.id, 'w1_c${course.index.toString().padLeft(2, '0')}');
        expect(course.world, 1);
        expect(course.rewardBolts, rewardBolts);
        expect(course.rewardPartId, rewardPartId);
        expect(course.bolts, hasLength(boltCount));
        if (rewardPartId != null) catalog.byId(rewardPartId);
      });

      test('obstacles are in order and do not overlap', () {
        // A low ceiling may hang over another obstacle; a ramp ends where
        // its gap begins.
        final ground = course.obstacles
            .where((o) => o is! LowCeilingObstacle)
            .toList();
        for (var i = 1; i < ground.length; i++) {
          expect(
            ground[i].start,
            greaterThanOrEqualTo(ground[i - 1].end),
            reason: 'obstacle $i',
          );
          if (ground[i - 1] is RampObstacle) {
            expect(ground[i], isA<GapObstacle>(), reason: 'after a ramp');
            expect(ground[i].start, ground[i - 1].end);
          }
        }
        if (course.obstacles.isNotEmpty) {
          expect(course.obstacles.last.end, lessThan(course.lengthPx));
        }
      });

      test('ceilings leave room to hover under them', () {
        for (final ceiling
            in course.obstacles.whereType<LowCeilingObstacle>()) {
          expect(
            ceiling.height,
            greaterThan(
              tuning.robotHeight + tuning.hoverHeight + tuning.ceilingMargin,
            ),
          );
        }
      });

      test('gaps are wider than the robot, so it can fall in', () {
        for (final gap in course.obstacles) {
          if (gap
              case GapObstacle(:final width) || BarGapObstacle(:final width)) {
            expect(width, greaterThan(2 * tuning.robotHalfWidth));
          }
        }
      });

      test('checkpoints start at 0, are in order, on open ground', () {
        final xs = course.checkpoints.map((c) => c.x).toList();
        expect(xs.first, 0);
        expect(xs, orderedEquals([...xs]..sort()));
        expect(course.checkpoints.first.pitStop, isFalse);
        for (final x in xs) {
          for (final obstacle in course.obstacles) {
            final inside =
                x + tuning.robotHalfWidth > obstacle.start &&
                x - tuning.robotHalfWidth < obstacle.end;
            expect(inside, isFalse, reason: 'checkpoint at $x');
          }
        }
      });
    });
  }
}
