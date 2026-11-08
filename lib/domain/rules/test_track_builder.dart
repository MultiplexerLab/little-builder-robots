import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/test_track.dart';

/// Builds one Test Track lap (TRK-01 to TRK-04).
class TestTrackBuilder {
  const TestTrackBuilder({required this.data, required this.courses});

  final TestTrackData data;
  final List<Course> courses;

  /// The course whose finish opens Test Track (TRK-01).
  static const unlockCourseIndex = 3;

  bool isUnlocked(ProfileData profile) => courses.any(
    (c) =>
        c.world == 1 &&
        c.index == unlockCourseIndex &&
        profile.resultFor(c.id).completed,
  );

  /// Obstacle types in every course the child has finished (TRK-02).
  Set<String> metTypes(ProfileData profile) => {
    for (final course in courses)
      if (profile.resultFor(course.id).completed)
        for (final obstacle in course.obstacles) _typeOf(obstacle),
  };

  /// One lap: a section per met obstacle type in data order, each followed
  /// by a pit stop. No bolts and no stars (TRK-03).
  Course lap(ProfileData profile) {
    final met = metTypes(profile);
    final obstacles = <Obstacle>[];
    final checkpoints = <Checkpoint>[const Checkpoint(x: 0)];
    var x = data.leadIn;
    for (final section in data.sections) {
      if (!met.contains(section.type)) continue;
      for (final obstacle in section.obstacles) {
        obstacles.add(_shifted(obstacle, x));
      }
      x += section.length;
      checkpoints.add(Checkpoint(x: x, pitStop: true));
      x += data.leadIn;
    }
    return Course(
      id: 'test_track',
      world: 0,
      index: 0,
      hintKey: 'testTrackHint',
      lengthPx: x,
      checkpoints: checkpoints,
      obstacles: obstacles,
    );
  }

  static String _typeOf(Obstacle o) => switch (o) {
    StepsObstacle() => 'steps',
    GapObstacle() => 'gap',
    TimedGateObstacle() => 'timedGate',
    BarGapObstacle() => 'barGap',
    HeavySwitchObstacle() => 'heavySwitch',
    MudObstacle() => 'mud',
    LeafPileObstacle() => 'leafPile',
    LowCeilingObstacle() => 'lowCeiling',
    RampObstacle() => 'ramp',
  };

  static Obstacle _shifted(Obstacle o, double dx) => switch (o) {
    StepsObstacle() => o.copyWith(x: o.x + dx),
    GapObstacle() => o.copyWith(x: o.x + dx),
    BarGapObstacle() => o.copyWith(x: o.x + dx),
    MudObstacle() => o.copyWith(x: o.x + dx),
    LeafPileObstacle() => o.copyWith(x: o.x + dx),
    LowCeilingObstacle() => o.copyWith(x: o.x + dx),
    RampObstacle() => o.copyWith(x: o.x + dx),
    TimedGateObstacle() => o.copyWith(plateX: o.plateX + dx, x: o.x + dx),
    HeavySwitchObstacle() => o.copyWith(plateX: o.plateX + dx, x: o.x + dx),
  };
}
