import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';

part 'progress.freezed.dart';
part 'progress.g.dart';

/// The best result so far on one course (RES-06).
@freezed
abstract class CourseResult with _$CourseResult {
  const factory CourseResult({
    @Default(0) int stars,
    @Default(0) int bestBolts,
    @Default(false) bool completed,
    @Default(false) bool rewardClaimed,

    /// The golden gear has been found on this course (RUN-16).
    @Default(false) bool foundGear,
  }) = _CourseResult;

  factory CourseResult.fromJson(Map<String, dynamic> json) =>
      _$CourseResultFromJson(json);
}

/// One player's game data (SRS 7.3).
@freezed
abstract class ProfileData with _$ProfileData {
  const factory ProfileData({
    required RobotConfig robot,
    @Default(<String>{}) Set<String> unlockedPartIds,
    @Default(<String>{}) Set<String> unlockedDecalIds,
    @Default(0) int bolts,
    @Default(<String, CourseResult>{}) Map<String, CourseResult> courseResults,
    @Default(<String>{}) Set<String> stickerIds,
    @Default(<String>{}) Set<String> partsTried,

    /// Play time per local calendar day, keyed yyyy-mm-dd (PAR-05, PAR-07).
    @Default(<String, int>{}) Map<String, int> playSecondsByDay,

    /// Extra time a grown-up gave on a day ("10 more minutes", PAR-07).
    @Default(<String, int>{}) Map<String, int> bonusSecondsByDay,

    /// Stickers earned but not shown yet (STK-02).
    @Default(<String>{}) Set<String> unrevealedStickerIds,
  }) = _ProfileData;

  const ProfileData._();

  factory ProfileData.fromJson(Map<String, dynamic> json) =>
      _$ProfileDataFromJson(json);

  CourseResult resultFor(String courseId) =>
      courseResults[courseId] ?? const CourseResult();
}

/// The saved root. v1.0 has one profile, kept in a list so v1.1 can add more
/// without migrating game data (SAV-04). The schema version is written next
/// to it by SaveSlot (SAV-02).
@freezed
abstract class Progress with _$Progress {
  const factory Progress({
    required List<ProfileData> profiles,
    @Default(0) int activeProfile,
  }) = _Progress;

  const Progress._();

  factory Progress.fromJson(Map<String, dynamic> json) =>
      _$ProgressFromJson(json);

  ProfileData get profile => profiles[activeProfile];
}
