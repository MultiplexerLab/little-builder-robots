import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:little_builder_robots/data/game_data.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/decal.dart';
import 'package:little_builder_robots/domain/models/part_catalog.dart';
import 'package:little_builder_robots/domain/models/sim_tuning.dart';
import 'package:little_builder_robots/domain/models/sticker.dart';
import 'package:little_builder_robots/domain/models/test_track.dart';

/// Loads the bundled game data in assets/data (NFR-15). Nothing is
/// downloaded.
class GameDataRepository {
  GameDataRepository(this._bundle);

  final AssetBundle _bundle;

  Future<Map<String, dynamic>> _json(String path) async =>
      jsonDecode(await _bundle.loadString(path)) as Map<String, dynamic>;

  Future<PartCatalog> loadParts() async =>
      PartCatalog.fromJson(await _json('assets/data/parts.json'));

  Future<SimTuning> loadTuning() async =>
      SimTuning.fromJson(await _json('assets/data/physics.json'));

  Future<List<Decal>> loadDecals() async => [
    for (final json
        in (await _json('assets/data/decals.json'))['decals'] as List)
      Decal.fromJson(json as Map<String, dynamic>),
  ];

  Future<List<Sticker>> loadStickers() async => [
    for (final json
        in (await _json('assets/data/stickers.json'))['stickers'] as List)
      Sticker.fromJson(json as Map<String, dynamic>),
  ];

  Future<TestTrackData> loadTestTrack() async =>
      TestTrackData.fromJson(await _json('assets/data/test_track.json'));

  /// Everything the game needs, loaded once at start-up.
  Future<GameData> loadAll() async => GameData(
    catalog: await loadParts(),
    tuning: await loadTuning(),
    decals: await loadDecals(),
    stickers: await loadStickers(),
    courses: await loadWorld(1),
    testTrack: await loadTestTrack(),
  );

  /// Every course file in assets/data/world[world]/, in map order.
  Future<List<Course>> loadWorld(int world) async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final prefix = 'assets/data/world$world/';
    final paths =
        manifest
            .listAssets()
            .where((p) => p.startsWith(prefix) && p.endsWith('.json'))
            .toList()
          ..sort();
    final courses = [
      for (final path in paths) Course.fromJson(await _json(path)),
    ]..sort((a, b) => a.index.compareTo(b.index));
    return courses;
  }
}
