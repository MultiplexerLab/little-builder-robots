import 'package:freezed_annotation/freezed_annotation.dart';

part 'course.freezed.dart';
part 'course.g.dart';

/// A restart flag. Pit stops have a garage pad for swapping parts (RUN-11).
@freezed
abstract class Checkpoint with _$Checkpoint {
  const factory Checkpoint({
    required double x,
    @Default(false) bool pitStop,
  }) = _Checkpoint;

  factory Checkpoint.fromJson(Map<String, dynamic> json) =>
      _$CheckpointFromJson(json);
}

/// A bolt pickup. [y] is the bolt centre above ground level 0.
@freezed
abstract class BoltSpot with _$BoltSpot {
  const factory BoltSpot({required double x, required double y}) = _BoltSpot;

  factory BoltSpot.fromJson(Map<String, dynamic> json) =>
      _$BoltSpotFromJson(json);
}

/// One obstacle (SRS 4.3), stored with a `type` key. Positions are px from
/// the course start; heights are px above ground level 0.
@Freezed(unionKey: 'type')
sealed class Obstacle with _$Obstacle {
  /// A staircase. Each entry of [stepHeights] is the rise of one step,
  /// [stepWidth] px apart. After the last step the top runs on for
  /// [topWidth] px, then drops back to ground level.
  const factory Obstacle.steps({
    required double x,
    required double stepWidth,
    required List<double> stepHeights,
    @Default(0) double topWidth,
  }) = StepsObstacle;

  /// A hole in the ground [width] px wide. [water] only changes the look and
  /// the splash (RUN-04).
  const factory Obstacle.gap({
    required double x,
    required double width,
    @Default(false) bool water,
  }) = GapObstacle;

  /// A pressure plate at [plateX] opens the gate at [x] for [openSeconds].
  const factory Obstacle.timedGate({
    required double plateX,
    required double x,
    required double openSeconds,
  }) = TimedGateObstacle;

  /// A gap too wide to jump with a bar over it; Grabber arms swing across.
  const factory Obstacle.barGap({required double x, required double width}) =
      BarGapObstacle;

  /// A heavy switch at [plateX] opens the door at [x] for a heavy robot.
  const factory Obstacle.heavySwitch({
    required double plateX,
    required double x,
  }) = HeavySwitchObstacle;

  /// Sticky mud: a heavy robot sinks unless it is mudproof.
  const factory Obstacle.mud({required double x, required double width}) =
      MudObstacle;

  /// A leaf pile [height] px tall: blown away by Fan arms or flown over.
  const factory Obstacle.leafPile({
    required double x,
    required double width,
    required double height,
  }) = LeafPileObstacle;

  /// A low ceiling [height] px above ground over [width] px. It can sit over
  /// other obstacles, such as a gap.
  const factory Obstacle.lowCeiling({
    required double x,
    required double width,
    required double height,
  }) = LowCeilingObstacle;

  /// A ramp ending at a gap: leaving it launches the robot upwards in
  /// proportion to its speed.
  const factory Obstacle.ramp({required double x, required double width}) =
      RampObstacle;

  const Obstacle._();

  factory Obstacle.fromJson(Map<String, dynamic> json) =>
      _$ObstacleFromJson(json);

  /// Where the obstacle starts and ends along the course.
  double get start => switch (this) {
    StepsObstacle(:final x) ||
    GapObstacle(:final x) ||
    BarGapObstacle(:final x) ||
    MudObstacle(:final x) ||
    LeafPileObstacle(:final x) ||
    LowCeilingObstacle(:final x) ||
    RampObstacle(:final x) => x,
    TimedGateObstacle(:final plateX) ||
    HeavySwitchObstacle(:final plateX) => plateX,
  };

  double get end => switch (this) {
    StepsObstacle(
      :final x,
      :final stepWidth,
      :final stepHeights,
      :final topWidth,
    ) =>
      x + stepWidth * stepHeights.length + topWidth,
    GapObstacle(:final x, :final width) ||
    BarGapObstacle(:final x, :final width) ||
    MudObstacle(:final x, :final width) ||
    LeafPileObstacle(:final x, :final width) ||
    LowCeilingObstacle(:final x, :final width) ||
    RampObstacle(:final x, :final width) => x + width,
    TimedGateObstacle(:final x) || HeavySwitchObstacle(:final x) => x,
  };
}

/// A build the course is designed for, checked by the solver test (NFR-18).
/// [parts] go onto the default robot; each [pitStops] entry is the parts
/// swapped in at the next pit stop.
@freezed
abstract class IntendedBuild with _$IntendedBuild {
  const factory IntendedBuild({
    @Default(<String>[]) List<String> parts,
    @Default(<List<String>>[]) List<List<String>> pitStops,
  }) = _IntendedBuild;

  factory IntendedBuild.fromJson(Map<String, dynamic> json) =>
      _$IntendedBuildFromJson(json);
}

/// One course (SRS 4.5, 7.3), loaded from assets/data/world1/course_NN.json.
@freezed
abstract class Course with _$Course {
  const factory Course({
    required String id,
    required int world,

    /// 1-based position on the world map (MAP-01).
    required int index,
    required String hintKey,
    @Default(0) int rewardBolts,
    String? rewardPartId,

    /// The finish flag's x.
    @Default(0) double lengthPx,

    /// Sorted by x; the first is the start.
    @Default(<Checkpoint>[Checkpoint(x: 0)]) List<Checkpoint> checkpoints,
    @Default(<BoltSpot>[]) List<BoltSpot> bolts,
    @Default(<Obstacle>[]) List<Obstacle> obstacles,
    @Default(<IntendedBuild>[]) List<IntendedBuild> intendedBuilds,

    /// A hidden golden gear, often out of reach of the intended build so
    /// there is a reason to come back with new parts (RUN-16).
    BoltSpot? gear,
  }) = _Course;

  factory Course.fromJson(Map<String, dynamic> json) => _$CourseFromJson(json);
}
