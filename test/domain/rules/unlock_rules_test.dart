import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/run_outcome.dart';
import 'package:little_builder_robots/domain/rules/star_rules.dart';
import 'package:little_builder_robots/domain/rules/unlock_rules.dart';

import '../../helpers/game_data.dart';

void main() {
  final catalog = loadCatalog();
  final decals = loadDecals();
  final courses = world1Courses();
  final rules = UnlockRules(
    catalog: catalog,
    courses: courses,
    decals: decals,
  );
  final fresh = rules.newProfile();

  RunOutcome finish({int bolts = 3, int falls = 0}) => RunOutcome(
    finished: true,
    boltsCollected: bolts,
    boltsOnCourse: 6,
    falls: falls,
  );

  group('newProfile', () {
    test('owns exactly the start parts', () {
      expect(fresh.unlockedPartIds, {
        'moves_wheels',
        'moves_legs',
        'body_light_frame',
        'arms_short',
        'head_round',
        'head_square',
      });
    });

    test('owns the 2 free decals and has no bolts', () {
      expect(fresh.unlockedDecalIds, {'decal_stars', 'decal_stripes'});
      expect(fresh.bolts, 0);
    });

    test('wears the default robot', () {
      expect(fresh.robot, catalog.defaultRobot);
      expect(fresh.partsTried, catalog.defaultRobot.partIds.toSet());
    });
  });

  group('buying parts (WRK-05, WRK-11, SRS 4.6)', () {
    final tracks = catalog.byId('moves_tank_tracks');

    test('not enough bolts: needMoreBolts and buying throws', () {
      final poor = fresh.copyWith(bolts: 39);
      expect(rules.checkPart(poor, tracks), BuyCheck.needMoreBolts);
      expect(() => rules.buyPart(poor, tracks), throwsStateError);
    });

    test('enough bolts: unlocks and spends', () {
      final rich = fresh.copyWith(bolts: 45);
      expect(rules.checkPart(rich, tracks), BuyCheck.canBuy);
      final after = rules.buyPart(rich, tracks);
      expect(after.bolts, 5);
      expect(rules.ownsPart(after, tracks.id), isTrue);
      expect(rules.checkPart(after, tracks), BuyCheck.owned);
    });

    test('reward parts are never for sale', () {
      final rich = fresh.copyWith(bolts: 999);
      final jetpack = catalog.byId('moves_jetpack');
      expect(rules.checkPart(rich, jetpack), BuyCheck.notForSale);
      expect(() => rules.buyPart(rich, jetpack), throwsStateError);
    });

    test('start parts report owned', () {
      expect(
        rules.checkPart(fresh, catalog.byId('moves_legs')),
        BuyCheck.owned,
      );
    });
  });

  group('buying decals (WRK-10)', () {
    final gears = decals.firstWhere((d) => d.id == 'decal_gears');

    test('free decals are owned', () {
      expect(rules.checkDecal(fresh, decals.first), BuyCheck.owned);
    });

    test('paid decal spends bolts', () {
      expect(rules.checkDecal(fresh, gears), BuyCheck.needMoreBolts);
      final after = rules.buyDecal(fresh.copyWith(bolts: 30), gears);
      expect(after.bolts, 0);
      expect(after.unlockedDecalIds, contains(gears.id));
    });
  });

  group('equip (WRK-03)', () {
    test('equips an owned part and records it as tried', () {
      final after = rules.equip(fresh, catalog.byId('moves_legs'));
      expect(after.robot.movesId, 'moves_legs');
      expect(after.robot.bodyId, fresh.robot.bodyId);
      expect(after.partsTried, contains('moves_legs'));
    });

    test('a locked part cannot be equipped', () {
      expect(
        () => rules.equip(fresh, catalog.byId('moves_jetpack')),
        throwsStateError,
      );
    });
  });

  group('MAP-03 course unlocks', () {
    test('only course 1 is open at first', () {
      expect(
        [for (final c in courses) rules.isCourseUnlocked(fresh, c)],
        [true, ...List.filled(14, false)],
      );
    });

    test('a course opens once the one before has a star', () {
      final profile = fresh.copyWith(
        courseResults: {
          'w1_c01': const CourseResult(stars: 1, completed: true),
        },
      );
      expect(rules.isCourseUnlocked(profile, courses[1]), isTrue);
      expect(rules.isCourseUnlocked(profile, courses[2]), isFalse);
    });
  });

  group('applyRun (RES-02 to RES-06)', () {
    test('first finish pays run bolts plus reward bolts', () {
      final reward = rules.applyRun(fresh, courses[0], finish());
      expect(reward.runBolts, 3);
      expect(reward.rewardBolts, 5);
      expect(reward.newPartId, isNull);
      expect(reward.profile.bolts, 8);
      expect(reward.profile.resultFor('w1_c01').rewardClaimed, isTrue);
      expect(reward.profile.resultFor('w1_c01').stars, 2);
    });

    test('replays pay run bolts only', () {
      final first = rules.applyRun(fresh, courses[0], finish());
      final replay = rules.applyRun(
        first.profile,
        courses[0],
        finish(bolts: 6),
      );
      expect(replay.rewardBolts, 0);
      expect(replay.profile.bolts, 8 + 6);
      expect(replay.profile.resultFor('w1_c01').stars, 3);
    });

    test('a worse replay keeps the best stars (RES-06)', () {
      final best = rules.applyRun(fresh, courses[0], finish(bolts: 6));
      final worse = rules.applyRun(
        best.profile,
        courses[0],
        finish(bolts: 0, falls: 2),
      );
      expect(worse.stars.count, 1);
      expect(worse.profile.resultFor('w1_c01').stars, 3);
    });

    test('course 3 awards Spring feet once (RES-04)', () {
      final first = rules.applyRun(fresh, courses[2], finish());
      expect(first.newPartId, 'moves_spring_feet');
      expect(first.rewardBolts, 0);
      expect(rules.ownsPart(first.profile, 'moves_spring_feet'), isTrue);

      final replay = rules.applyRun(
        first.profile,
        courses[2],
        finish(),
      );
      expect(replay.newPartId, isNull);
    });

    test('finishing a course unlocks the next one', () {
      final reward = rules.applyRun(
        fresh,
        courses[0],
        finish(bolts: 0, falls: 3),
      );
      expect(rules.isCourseUnlocked(reward.profile, courses[1]), isTrue);
    });

    test('leaving early keeps the bolts but nothing else', () {
      const quit = RunOutcome(
        finished: false,
        boltsCollected: 2,
        boltsOnCourse: 6,
        falls: 0,
      );
      final reward = rules.applyRun(fresh, courses[2], quit);
      expect(reward.profile.bolts, 2);
      expect(reward.runBolts, 2);
      expect(reward.stars.count, 0);
      expect(reward.rewardBolts, 0);
      expect(reward.newPartId, isNull);
      expect(reward.profile.courseResults, isEmpty);
      expect(rules.isCourseUnlocked(reward.profile, courses[3]), isFalse);
    });
  });

  test('SRS 4.6: one full pass of rewards gives 100 bolts', () {
    expect(courses.fold(0, (sum, c) => sum + c.rewardBolts), 100);
  });
}
