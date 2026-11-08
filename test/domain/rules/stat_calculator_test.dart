import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/stats.dart';
import 'package:little_builder_robots/domain/rules/stat_calculator.dart';

import '../../helpers/game_data.dart';

void main() {
  final catalog = loadCatalog();
  final calculator = StatCalculator(catalog);
  final base = catalog.defaultRobot;

  Stats statsWith({String? moves, String? body, String? arms}) =>
      calculator.statsFor(
        base.copyWith(
          movesId: moves ?? base.movesId,
          bodyId: body ?? base.bodyId,
          armsId: arms ?? base.armsId,
        ),
      );

  group('SRS 4.2 common builds (Light frame, Short arms)', () {
    // Moves part: speed, climb, jump, weight, fuel.
    const table = {
      'moves_wheels': (4, 0, 0, 1, 0),
      'moves_legs': (2, 3, 0, 1, 0),
      'moves_spring_feet': (3, 0, 3, 1, 0),
      'moves_jetpack': (3, 0, 0, 0, 3),
      'moves_tank_tracks': (3, 2, 0, 3, 0),
    };
    for (final MapEntry(key: moves, value: row) in table.entries) {
      test(moves, () {
        final stats = statsWith(moves: moves);
        expect(
          (stats.speed, stats.climb, stats.jump, stats.weight, stats.fuel),
          row,
        );
      });
    }
  });

  test('stats clamp at statMax', () {
    // Weight 0 + Heavy frame 4 + Tank tracks 2 = 6, shown as 5.
    final stats = statsWith(
      moves: 'moves_tank_tracks',
      body: 'body_heavy_frame',
    );
    expect(stats.weight, 5);
  });

  test('stats clamp at 0', () {
    // Jetpack alone: weight 0 - 1.
    final stats = calculator.statsForParts([catalog.byId('moves_jetpack')]);
    expect(stats.weight, 0);
  });

  test('Heavy frame slows Wheels by one', () {
    expect(statsWith(body: 'body_heavy_frame').speed, 3);
  });

  test('abilities come from equipped parts', () {
    expect(statsWith().abilities, isEmpty);
    final stats = statsWith(moves: 'moves_jetpack', arms: 'arms_grabber');
    expect(stats.abilities, {Ability.jetpack, Ability.grab});
    expect(stats.has(Ability.jetpack), isTrue);
    expect(statsWith(moves: 'moves_tank_tracks').has(Ability.mudproof), isTrue);
  });

  test('heads never change stats', () {
    final plain = calculator.statsFor(base);
    for (final head in catalog.inSlot(Slot.head)) {
      expect(
        calculator.statsFor(base.copyWith(headId: head.id)),
        plain,
        reason: head.id,
      );
    }
  });

  group('WRK-05 changesIfEquipped', () {
    test('Wheels to Legs: lose speed, gain climb', () {
      final changes = calculator.changesIfEquipped(
        base,
        catalog.byId('moves_legs'),
      );
      expect(changes, {
        Stat.speed: (before: 4, after: 2),
        Stat.climb: (before: 0, after: 3),
      });
    });

    test('same part changes nothing', () {
      expect(
        calculator.changesIfEquipped(base, catalog.byId(base.movesId)),
        isEmpty,
      );
    });

    test('a style-only head changes nothing', () {
      expect(
        calculator.changesIfEquipped(base, catalog.byId('head_gold')),
        isEmpty,
      );
    });
  });

  test('unknown part in a RobotConfig throws', () {
    expect(
      () => calculator.statsFor(base.copyWith(movesId: 'rocket')),
      throwsArgumentError,
    );
  });
}
