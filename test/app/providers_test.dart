import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/core/storage/key_value_store.dart';
import 'package:little_builder_robots/domain/models/run_outcome.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/rules/star_rules.dart';
import 'package:little_builder_robots/domain/rules/sticker_rules.dart';

import '../helpers/app_harness.dart';

void main() {
  late MemoryKeyValueStore store;
  late ProviderContainer c;

  setUp(() {
    store = MemoryKeyValueStore();
    c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWithValue(testData),
        storeProvider.overrideWithValue(store),
      ],
    );
    addTearDown(c.dispose);
  });

  ProgressController progress() => c.read(progressProvider.notifier);

  /// What a fresh load from the store would see (SAV-01).
  String savedMoves() =>
      c.read(progressRepositoryProvider).load().progress.profile.robot.movesId;

  const finish = RunOutcome(
    finished: true,
    boltsCollected: 3,
    boltsOnCourse: 5,
    falls: 0,
  );

  group('ProgressController', () {
    test('starts with a fresh profile', () {
      final profile = c.read(profileProvider);
      expect(profile.robot, testData.catalog.defaultRobot);
      expect(profile.bolts, 0);
    });

    test('equip saves at once (WRK-03, SAV-01)', () {
      progress().equip(testData.catalog.byId('moves_legs'));
      expect(c.read(profileProvider).robot.movesId, 'moves_legs');
      expect(savedMoves(), 'moves_legs');
    });

    test('a new head earns the head-swap sticker (STK-01)', () {
      progress().equip(testData.catalog.byId('head_square'));
      expect(c.read(profileProvider).stickerIds, contains('sticker_headSwap'));
    });

    test('buyPart spends bolts and equips, or refuses (WRK-05)', () {
      final tracks = testData.catalog.byId('moves_tank_tracks');
      expect(progress().buyPart(tracks), isFalse);
      progress().applyRun(testData.courses.first, finish, const {});
      // 3 run bolts + 5 reward bolts is not enough for 40.
      expect(progress().buyPart(tracks), isFalse);
      for (var i = 0; i < 12; i++) {
        progress().applyRun(testData.courses.first, finish, const {});
      }
      expect(progress().buyPart(tracks), isTrue);
      final profile = c.read(profileProvider);
      expect(profile.robot.movesId, 'moves_tank_tracks');
      expect(profile.bolts, 8 + 12 * 3 - 40);
      expect(profile.stickerIds, contains('sticker_newPart'));
    });

    test('paint and decals change the robot and earn stickers', () {
      progress().paint('mint');
      progress().wearDecal('decal_stars');
      final profile = c.read(profileProvider);
      expect(profile.robot.colour, 'mint');
      expect(profile.robot.decalId, 'decal_stars');
      expect(
        profile.stickerIds,
        containsAll(['sticker_paint', 'sticker_decal']),
      );
      progress().wearDecal(null);
      expect(c.read(profileProvider).robot.decalId, isNull);
    });

    test('buyDecal needs enough bolts (WRK-10)', () {
      final gears = testData.decals.firstWhere((d) => d.id == 'decal_gears');
      expect(progress().buyDecal(gears), isFalse);
    });

    test('applyRun reports stars, bolts, stickers and the old best', () {
      final first = progress().applyRun(testData.courses.first, finish, {
        Fact.jump,
      });
      expect(first.stars.count, 2);
      expect(first.runBolts, 3);
      expect(first.rewardBolts, 5);
      expect(first.previousStars, 0);
      expect(first.newStickerIds, contains('sticker_jump'));

      final again = progress().applyRun(testData.courses.first, finish, {
        Fact.jump,
      });
      expect(again.previousStars, 2);
      expect(again.rewardBolts, 0);
      expect(again.newStickerIds, isEmpty);
    });

    test('markStickersRevealed empties the reveal queue (STK-02)', () {
      progress().addFacts({Fact.hint});
      expect(c.read(profileProvider).unrevealedStickerIds, isNotEmpty);
      progress().markStickersRevealed();
      expect(c.read(profileProvider).unrevealedStickerIds, isEmpty);
      expect(c.read(profileProvider).stickerIds, contains('sticker_hint'));
    });

    test('play time and bonus time add up per day (PAR-07)', () {
      progress()
        ..addPlaySeconds('2026-10-31', 60)
        ..addPlaySeconds('2026-10-31', 30)
        ..addBonusSeconds('2026-10-31', 600);
      final profile = c.read(profileProvider);
      expect(profile.playSecondsByDay['2026-10-31'], 90);
      expect(profile.bonusSecondsByDay['2026-10-31'], 600);
    });

    test('reset starts over and saves (PAR-04)', () {
      progress()
        ..equip(testData.catalog.byId('moves_legs'))
        ..reset();
      expect(c.read(profileProvider).robot, testData.catalog.defaultRobot);
      expect(savedMoves(), 'moves_wheels');
    });
  });

  test('SettingsController saves every change (PAR-04)', () {
    c
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(playStyle: PlayStyle.little, music: false));
    final saved = c.read(settingsRepositoryProvider).load().settings;
    expect(saved.playStyle, PlayStyle.little);
    expect(saved.music, isFalse);
  });

  group('SelectedCourseController.nextCourse (HOM-03)', () {
    test('the first unplayed course, or the last when all are done', () {
      final courses = testData.courses;
      expect(c.read(selectedCourseProvider), courses.first.id);
      progress().applyRun(courses.first, finish, const {});
      expect(
        SelectedCourseController.nextCourse(courses, c.read(profileProvider)),
        courses[1],
      );
      for (final course in courses) {
        progress().applyRun(course, finish, const {});
      }
      expect(
        SelectedCourseController.nextCourse(courses, c.read(profileProvider)),
        courses.last,
      );
    });

    test('select changes the course', () {
      c.read(selectedCourseProvider.notifier).select('w1_c05');
      expect(c.read(selectedCourseDataProvider).index, 5);
    });
  });

  test('robotStatsProvider follows the equipped parts', () {
    expect(c.read(robotStatsProvider).speed, 4);
    progress().equip(testData.catalog.byId('moves_legs'));
    expect(c.read(robotStatsProvider).climb, 3);
  });
}
