import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/rules/sticker_rules.dart';
import 'package:little_builder_robots/domain/rules/test_track_builder.dart';
import 'package:little_builder_robots/domain/rules/unlock_rules.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';

import '../../helpers/game_data.dart';

void main() {
  final catalog = loadCatalog();
  final courses = loadWorld1();
  final stickers = loadStickers();
  final rules = StickerRules(
    stickers: stickers,
    catalog: catalog,
    courses: courses,
  );
  final fresh = UnlockRules(catalog: catalog, courses: courses).newProfile();

  group('STK-01 to STK-04', () {
    test('24 stickers, each with a known rule and clue', () {
      expect(stickers, hasLength(25));
      expect(stickers.map((s) => s.id).toSet(), hasLength(25));
      const facts = {
        Fact.jump, Fact.bolt, Fact.splash, Fact.boing, Fact.mud, //
        Fact.jetpack, Fact.heavySwitch, Fact.swing, Fact.leaves, Fact.ramp,
        Fact.ceiling, Fact.gate, Fact.pitStop, Fact.hop, Fact.hint,
        Fact.testTrackLap, Fact.paint, Fact.decal, Fact.headSwap,
        Fact.newPart, Fact.allMoves, Fact.threeStars, Fact.goldHead,
        Fact.world1,
        Fact.gear,
      };
      expect(stickers.map((s) => s.rule).toSet(), facts);
    });

    test('run events become facts', () {
      final steps = courses[1]; // course 2 starts with steps
      final facts = rules.factsFromRun(steps, const [
        RunEvent.jumped(),
        RunEvent.boltCollected(0),
        RunEvent.bumped(0),
      ]);
      expect(facts, {Fact.jump, Fact.bolt, Fact.boing});
    });

    test('falling in water is a splash; a dry gap is not', () {
      final c6 = courses[5]; // obstacle 4 is a water gap, 2 is dry
      expect(rules.factsFromRun(c6, const [RunEvent.fell(4)]), {Fact.splash});
      expect(rules.factsFromRun(c6, const [RunEvent.fell(2)]), isEmpty);
      expect(
        rules.factsFromRun(c6, const [RunEvent.gearFound()]),
        {Fact.gear},
      );
    });

    test('award adds new stickers once and queues them for reveal', () {
      final once = rules.award(fresh, {Fact.jump});
      expect(once.stickerIds, {'sticker_jump'});
      expect(once.unrevealedStickerIds, {'sticker_jump'});
      final twice = rules.award(once, {Fact.jump});
      expect(twice, once);
    });

    test('progress facts: 3 stars, gold head, all moves', () {
      final p = fresh.copyWith(
        courseResults: {'w1_c01': const CourseResult(stars: 3)},
        robot: fresh.robot.copyWith(headId: 'head_gold'),
        partsTried: {
          'moves_wheels',
          'moves_legs',
          'moves_spring_feet',
          'moves_jetpack',
          'moves_tank_tracks',
        },
      );
      expect(rules.factsFromProgress(p), {
        Fact.threeStars,
        Fact.goldHead,
        Fact.allMoves,
      });
    });
  });

  group('Test Track (TRK-01 to TRK-04)', () {
    final builder = TestTrackBuilder(data: loadTestTrack(), courses: courses);

    ProfileData finished(int upTo) => fresh.copyWith(
      courseResults: {
        for (final c in courses)
          if (c.index <= upTo)
            c.id: const CourseResult(stars: 1, completed: true),
      },
    );

    test('locked until course 3 is finished', () {
      expect(builder.isUnlocked(finished(2)), isFalse);
      expect(builder.isUnlocked(finished(3)), isTrue);
    });

    test('one section per obstacle type met, each followed by a pit stop', () {
      final lap = builder.lap(finished(3));
      expect(builder.metTypes(finished(3)), {'steps', 'gap'});
      expect(lap.obstacles, hasLength(2));
      expect(lap.checkpoints.where((c) => c.pitStop), hasLength(2));
      expect(lap.bolts, isEmpty);
    });

    test('every obstacle type has a section after World 1', () {
      final lap = builder.lap(finished(15));
      expect(builder.metTypes(finished(15)), hasLength(9));
      expect(lap.checkpoints.where((c) => c.pitStop), hasLength(9));
    });
  });
}
