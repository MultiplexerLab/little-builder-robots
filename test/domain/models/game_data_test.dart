import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/models/stats.dart';

import '../../helpers/game_data.dart';

void main() {
  final catalog = loadCatalog();

  group('parts.json (SRS 4.1, 4.2)', () {
    test('base stats and range', () {
      expect(
        catalog.baseStats,
        const StatMods(speed: 2),
      );
      expect(catalog.statMax, 5);
    });

    test('has 11 gameplay parts and 6 heads with unique ids', () {
      final ids = catalog.parts.map((part) => part.id);
      expect(ids.toSet(), hasLength(ids.length));
      expect(catalog.inSlot(Slot.moves), hasLength(5));
      expect(catalog.inSlot(Slot.body), hasLength(3));
      expect(catalog.inSlot(Slot.arms), hasLength(3));
      expect(catalog.inSlot(Slot.head), hasLength(6));
    });

    test('heads are style only: 2 at start, 3 for 20 bolts, gold from 15', () {
      final heads = catalog.inSlot(Slot.head);
      expect(heads.every((h) => h.mods == const StatMods()), isTrue);
      expect(heads.every((h) => h.ability == null), isTrue);
      expect(heads.where((h) => h.unlock is StartUnlock), hasLength(2));
      expect(
        heads.where((h) => h.unlock == const PartUnlock.bolts(cost: 20)),
        hasLength(3),
      );
      expect(
        catalog.byId('head_gold').unlock,
        const PartUnlock.reward(courseId: 'w1_c15'),
      );
    });

    test('bolt prices match the economy (SRS 4.6)', () {
      expect(
        catalog.byId('moves_tank_tracks').unlock,
        const PartUnlock.bolts(cost: 40),
      );
      expect(
        catalog.byId('body_battery').unlock,
        const PartUnlock.bolts(cost: 30),
      );
      expect(
        catalog.byId('arms_fan').unlock,
        const PartUnlock.bolts(cost: 35),
      );
    });

    test('reward parts match the World 1 course rewards (SRS 4.5)', () {
      for (final course in world1Courses()) {
        if (course.rewardPartId case final partId?) {
          expect(
            catalog.byId(partId).unlock,
            PartUnlock.reward(courseId: course.id),
            reason: partId,
          );
        }
      }
    });

    test('default robot uses start parts in the right slots', () {
      final robot = catalog.defaultRobot;
      for (final slot in Slot.values) {
        final part = catalog.byId(robot.partIdFor(slot));
        expect(part.slot, slot);
        expect(part.unlock, isA<StartUnlock>());
      }
    });

    test('unknown part id throws', () {
      expect(() => catalog.byId('nope'), throwsArgumentError);
    });
  });

  test('decals.json: 8 decals, 2 free, the rest about 130 bolts (SRS 4.6)', () {
    final decals = loadDecals();
    expect(decals, hasLength(8));
    expect(decals.where((d) => d.cost == 0), hasLength(2));
    final paid = decals.where((d) => d.cost > 0).map((d) => d.cost);
    expect(paid.every((cost) => cost >= 15 && cost <= 30), isTrue);
    expect(paid.reduce((a, b) => a + b), 130);
  });

  group('JSON round trips for saved models (SAV-01)', () {
    test('Progress with a profile', () {
      final progress = Progress(
        profiles: [
          ProfileData(
            robot: catalog.defaultRobot.copyWith(decalId: 'decal_stars'),
            unlockedPartIds: {'moves_wheels', 'moves_legs'},
            bolts: 12,
            courseResults: {
              'w1_c01': const CourseResult(
                stars: 2,
                bestBolts: 5,
                completed: true,
                rewardClaimed: true,
              ),
            },
            playSecondsByDay: {'2026-10-31': 600},
          ),
        ],
      );
      expect(Progress.fromJson(_deep(progress)), progress);
    });

    test('Settings', () {
      const settings = Settings(
        playStyle: PlayStyle.little,
        haptics: false,
        dailyLimitMinutes: 30,
        onboardingDone: true,
      );
      expect(Settings.fromJson(_deep(settings)), settings);
      expect(settings.helperMode, isTrue);
      expect(const Settings().helperMode, isFalse);
    });

    test('RobotConfig.withPart swaps one slot', () {
      final robot = catalog.defaultRobot.withPart(Slot.moves, 'moves_legs');
      expect(robot.movesId, 'moves_legs');
      expect(robot.headId, catalog.defaultRobot.headId);
      expect(
        RobotConfig.fromJson(_deep(robot)),
        robot,
      );
    });
  });
}

/// Round-trips through a JSON string, as the save file will.
Map<String, dynamic> _deep(Object model) =>
    jsonDecode(jsonEncode(model)) as Map<String, dynamic>;
