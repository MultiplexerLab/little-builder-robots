import 'dart:convert';
import 'dart:io';

import 'package:little_builder_robots/data/game_data.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/decal.dart';
import 'package:little_builder_robots/domain/models/part_catalog.dart';
import 'package:little_builder_robots/domain/models/sim_tuning.dart';
import 'package:little_builder_robots/domain/models/sticker.dart';
import 'package:little_builder_robots/domain/models/test_track.dart';

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The real assets/data/parts.json, so tests check the shipped tuning.
PartCatalog loadCatalog() =>
    PartCatalog.fromJson(_readJson('assets/data/parts.json'));

SimTuning loadTuning() =>
    SimTuning.fromJson(_readJson('assets/data/physics.json'));

/// Every course JSON written so far in assets/data/world1, in map order.
List<Course> loadWorld1() {
  final files =
      Directory('assets/data/world1')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .map((f) => f.path)
          .toList()
        ..sort();
  return [for (final path in files) Course.fromJson(_readJson(path))];
}

List<Decal> loadDecals() => [
  for (final json in _readJson('assets/data/decals.json')['decals'] as List)
    Decal.fromJson(json as Map<String, dynamic>),
];

List<Sticker> loadStickers() => [
  for (final json in _readJson('assets/data/stickers.json')['stickers'] as List)
    Sticker.fromJson(json as Map<String, dynamic>),
];

TestTrackData loadTestTrack() =>
    TestTrackData.fromJson(_readJson('assets/data/test_track.json'));

/// All bundled game data, read from disk (no asset bundle needed).
GameData loadGameData() => GameData(
  catalog: loadCatalog(),
  tuning: loadTuning(),
  decals: loadDecals(),
  stickers: loadStickers(),
  courses: loadWorld1(),
  testTrack: loadTestTrack(),
);

/// Course index to (reward bolts, reward part, bolts on course) from the
/// SRS 4.5 table. Course JSON is checked against this.
const world1Table = <int, (int, String?, int)>{
  1: (5, null, 5),
  2: (5, null, 6),
  3: (0, 'moves_spring_feet', 6),
  4: (8, null, 7),
  5: (8, null, 8),
  6: (0, 'moves_jetpack', 8),
  7: (10, null, 9),
  8: (10, null, 9),
  9: (0, 'body_heavy_frame', 9),
  10: (12, null, 10),
  11: (0, 'arms_grabber', 10),
  12: (12, null, 10),
  13: (15, null, 11),
  14: (15, null, 12),
  15: (0, 'head_gold', 12),
};

/// All 15 World 1 courses with SRS 4.5 identity and rewards but no
/// geometry, for rules that do not run courses.
List<Course> world1Courses() {
  return [
    for (final MapEntry(key: index, value: (bolts, partId, _))
        in world1Table.entries)
      Course(
        id: 'w1_c${index.toString().padLeft(2, '0')}',
        world: 1,
        index: index,
        hintKey: 'hintCourse$index',
        rewardBolts: bolts,
        rewardPartId: partId,
      ),
  ];
}
