import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/decal.dart';
import 'package:little_builder_robots/domain/models/part_catalog.dart';
import 'package:little_builder_robots/domain/models/sim_tuning.dart';
import 'package:little_builder_robots/domain/models/sticker.dart';
import 'package:little_builder_robots/domain/models/test_track.dart';

/// Every bundled game data file, loaded once at start-up (NFR-15).
class GameData {
  const GameData({
    required this.catalog,
    required this.tuning,
    required this.decals,
    required this.stickers,
    required this.courses,
    required this.testTrack,
  });

  final PartCatalog catalog;
  final SimTuning tuning;
  final List<Decal> decals;
  final List<Sticker> stickers;

  /// World 1 courses in map order.
  final List<Course> courses;
  final TestTrackData testTrack;

  Course courseById(String id) => courses.firstWhere((c) => c.id == id);
}
