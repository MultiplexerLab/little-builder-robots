import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:little_builder_robots/domain/models/part.dart';

part 'robot_config.freezed.dart';
part 'robot_config.g.dart';

/// What the child built: one part per slot, plus paint and decal (SRS 7.3).
@freezed
abstract class RobotConfig with _$RobotConfig {
  const factory RobotConfig({
    required String headId,
    required String bodyId,
    required String armsId,
    required String movesId,
    required String colour,
    String? decalId,
  }) = _RobotConfig;

  const RobotConfig._();

  factory RobotConfig.fromJson(Map<String, dynamic> json) =>
      _$RobotConfigFromJson(json);

  String partIdFor(Slot slot) => switch (slot) {
    Slot.head => headId,
    Slot.body => bodyId,
    Slot.arms => armsId,
    Slot.moves => movesId,
  };

  Iterable<String> get partIds => Slot.values.map(partIdFor);

  /// Returns a copy with [partId] in [slot].
  RobotConfig withPart(Slot slot, String partId) => switch (slot) {
    Slot.head => copyWith(headId: partId),
    Slot.body => copyWith(bodyId: partId),
    Slot.arms => copyWith(armsId: partId),
    Slot.moves => copyWith(movesId: partId),
  };
}
