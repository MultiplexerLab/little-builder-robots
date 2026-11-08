import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:little_builder_robots/domain/models/stats.dart';

part 'part.freezed.dart';
part 'part.g.dart';

/// The four Workshop slots (WRK-01).
enum Slot { head, body, arms, moves }

/// How a part is unlocked (SRS 4.2). Stored in parts.json with a `type` key.
@Freezed(unionKey: 'type')
sealed class PartUnlock with _$PartUnlock {
  /// Owned from the first launch.
  const factory PartUnlock.start() = StartUnlock;

  /// Awarded on the first finish of [courseId] (RES-04).
  const factory PartUnlock.reward({required String courseId}) = RewardUnlock;

  /// Bought in the Workshop for [cost] bolts (WRK-05).
  const factory PartUnlock.bolts({required int cost}) = BoltsUnlock;

  factory PartUnlock.fromJson(Map<String, dynamic> json) =>
      _$PartUnlockFromJson(json);
}

@freezed
abstract class Part with _$Part {
  const factory Part({
    required String id,
    required Slot slot,
    required String nameKey,
    required String spriteAsset,
    required PartUnlock unlock,
    @Default(StatMods()) StatMods mods,
    Ability? ability,
  }) = _Part;

  factory Part.fromJson(Map<String, dynamic> json) => _$PartFromJson(json);
}
