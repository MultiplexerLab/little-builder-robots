import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:little_builder_robots/domain/models/course.dart';

part 'test_track.freezed.dart';
part 'test_track.g.dart';

/// One Test Track section: the obstacle(s) of one type, positioned from the
/// section start (TRK-02, TRK-04).
@freezed
abstract class TestTrackSection with _$TestTrackSection {
  const factory TestTrackSection({
    /// The obstacle type it shows, as in course JSON (for example "steps").
    required String type,
    required double length,
    required List<Obstacle> obstacles,
  }) = _TestTrackSection;

  factory TestTrackSection.fromJson(Map<String, dynamic> json) =>
      _$TestTrackSectionFromJson(json);
}

/// assets/data/test_track.json: the section order and nothing else (TRK-04).
@freezed
abstract class TestTrackData with _$TestTrackData {
  const factory TestTrackData({
    required double leadIn,
    required List<TestTrackSection> sections,
  }) = _TestTrackData;

  factory TestTrackData.fromJson(Map<String, dynamic> json) =>
      _$TestTrackDataFromJson(json);
}
