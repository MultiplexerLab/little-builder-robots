import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/stats.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';
import 'package:little_builder_robots/domain/rules/stat_calculator.dart';
import 'package:little_builder_robots/features/course_map/course_map_screen.dart';
import 'package:little_builder_robots/features/course_map/course_node.dart';
import 'package:little_builder_robots/features/run/run_screen.dart';
import 'package:little_builder_robots/features/workshop/good_at_panel.dart';
import 'package:little_builder_robots/features/workshop/part_tile.dart';

import '../helpers/game_data.dart';

void main() {
  final catalog = loadCatalog();
  final calc = StatCalculator(catalog);
  Stats statsWith(String movesId, {String? bodyId, String? armsId}) =>
      calc.statsFor(
        catalog.defaultRobot.copyWith(
          movesId: movesId,
          bodyId: bodyId ?? catalog.defaultRobot.bodyId,
          armsId: armsId ?? catalog.defaultRobot.armsId,
        ),
      );

  group('goodAtKey (WRK-04)', () {
    test('names the strongest point of each common build', () {
      expect(goodAtKey(statsWith('moves_wheels')), 'goodAtSpeed');
      expect(goodAtKey(statsWith('moves_legs')), 'goodAtClimb');
      expect(goodAtKey(statsWith('moves_spring_feet')), 'goodAtJump');
      expect(
        goodAtKey(statsWith('moves_wheels', bodyId: 'body_heavy_frame')),
        'goodAtHeavy',
      );
    });

    test('abilities come first', () {
      expect(goodAtKey(statsWith('moves_jetpack')), 'goodAtJetpack');
      expect(goodAtKey(statsWith('moves_tank_tracks')), 'goodAtMudproof');
      expect(
        goodAtKey(statsWith('moves_wheels', armsId: 'arms_grabber')),
        'goodAtGrab',
      );
      expect(
        goodAtKey(statsWith('moves_wheels', armsId: 'arms_fan')),
        'goodAtFan',
      );
    });
  });

  test('needHintKey names a hint for every need (RUN-13)', () {
    expect(needHintKey(Need.climb), 'hintClimb');
    expect(needHintKey(Need.light), 'hintLight');
    expect(Need.values.map(needHintKey).toSet(), hasLength(Need.values.length));
  });

  test('stat and ability icons are all different (DES-10)', () {
    expect(Stat.values.map(statIcon).toSet(), hasLength(Stat.values.length));
    expect(
      Ability.values.map(abilityIcon).toSet(),
      hasLength(Ability.values.length),
    );
  });

  group('mapPoints (MAP-01, MAP-08)', () {
    const size = Size(812, 358); // landscape iPhone minus safe area
    final points = mapPoints(15, size, top: 96);

    test('15 nodes, all fully on screen', () {
      expect(points, hasLength(15));
      const half = CourseNode.slot / 2;
      for (final p in points) {
        expect(p.dx - half, greaterThanOrEqualTo(0));
        expect(p.dx + half, lessThanOrEqualTo(size.width));
        expect(p.dy - half, greaterThanOrEqualTo(96 - half));
        expect(p.dy + half, lessThanOrEqualTo(size.height + half));
      }
    });

    test('the path snakes: rows of 5, alternating direction', () {
      for (var i = 0; i < 4; i++) {
        expect(points[i + 1].dx, greaterThan(points[i].dx)); // row 1 →
        expect(points[i + 6].dx, lessThan(points[i + 5].dx)); // row 2 ←
        expect(points[i + 11].dx, greaterThan(points[i + 10].dx)); // row 3 →
      }
      // Each row turns where the last one ended.
      expect(points[5].dx, closeTo(points[4].dx, 0.001));
      expect(points[10].dx, closeTo(points[9].dx, 0.001));
    });

    test('nodes never overlap (64 pt nodes, NFR-05)', () {
      for (var i = 0; i < points.length; i++) {
        for (var j = i + 1; j < points.length; j++) {
          expect(
            (points[i] - points[j]).distance,
            greaterThanOrEqualTo(AppSizes.childTarget),
            reason: '$i and $j',
          );
        }
      }
    });
  });

  test('slotArea zooms inside the robot box, head above moves', () {
    const box = Rect.fromLTWH(0, 0, 100, 130);
    for (final slot in Slot.values) {
      final area = slotArea(slot);
      expect(box.intersect(area), area, reason: '$slot');
    }
    expect(slotArea(Slot.head).top, lessThan(slotArea(Slot.moves).top));
  });
}
