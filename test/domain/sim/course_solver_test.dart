import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/rules/star_rules.dart';

import '../../helpers/game_data.dart';
import 'course_solver.dart';

/// NFR-18 and SRS 4.7: every course can be finished with the parts the
/// child owns when it unlocks, the intended builds earn 3 stars, and Helper
/// mode never changes which builds win.
void main() {
  final catalog = loadCatalog();
  final tuning = loadTuning();
  final solver = CourseSolver(catalog: catalog, tuning: tuning);
  final courses = loadWorld1();

  /// Start parts plus the rewards of every earlier course. Bolt-bought
  /// parts are left out, so no course needs bolts to be beaten.
  Set<String> ownedAtUnlock(Course course) => {
    for (final part in catalog.parts)
      if (part.unlock is StartUnlock) part.id,
    for (final MapEntry(key: index, value: (_, partId, _))
        in world1Table.entries)
      if (index < course.index && partId != null) partId,
  };

  String describe(List<RobotConfig> plan) =>
      plan.map((r) => '${r.movesId}/${r.bodyId}/${r.armsId}').join(' > ');

  test('World 1 course files exist', () {
    expect(courses, isNotEmpty);
  });

  for (final course in courses) {
    group(course.id, () {
      final owned = ownedAtUnlock(course);

      for (final style in PlayStyle.values) {
        test('is solvable with owned parts (${style.name})', () {
          expect(
            solver.solve(course, owned, style),
            isNotNull,
            reason: 'No owned build finishes ${course.id}',
          );
        });
      }

      test('has intended builds made of owned parts', () {
        expect(course.intendedBuilds, isNotEmpty);
        for (final intended in course.intendedBuilds) {
          final ids = [
            ...intended.parts,
            ...intended.pitStops.expand((s) => s),
          ];
          for (final id in ids) {
            expect(owned, contains(id), reason: id);
          }
        }
      });

      test('intended builds earn 3 stars in 20 to 40 s (SRS 4.5)', () {
        for (final intended in course.intendedBuilds) {
          final plan = solver.expand(intended);
          for (final style in PlayStyle.values) {
            final result = solver.run(course, plan, style);
            expect(
              starsFor(result.outcome).count,
              3,
              reason: '${describe(plan)} (${style.name}): ${result.outcome}',
            );
          }
          final seconds = solver.run(course, plan, PlayStyle.big).seconds;
          expect(
            seconds,
            inInclusiveRange(20, 40),
            reason: describe(plan),
          );
        }
      });

      test('Helper mode never changes which builds win (SRS 4.7)', () {
        for (final start in solver.segmentStarts(course)) {
          for (final build in solver.buildsFrom(owned)) {
            expect(
              solver.passes(course, start, build, PlayStyle.little),
              solver.passes(course, start, build, PlayStyle.big),
              reason: 'from checkpoint $start: ${describe([build])}',
            );
          }
        }
      });
    });
  }
}
