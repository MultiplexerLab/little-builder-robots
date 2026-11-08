import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/models/stats.dart';

part 'part_catalog.freezed.dart';
part 'part_catalog.g.dart';

/// Everything in assets/data/parts.json: stat tuning, the default robot and
/// all parts (SRS 4.1, 4.2).
@freezed
abstract class PartCatalog with _$PartCatalog {
  const factory PartCatalog({
    required StatMods baseStats,
    required int statMax,
    required RobotConfig defaultRobot,
    required List<Part> parts,
  }) = _PartCatalog;

  const PartCatalog._();

  factory PartCatalog.fromJson(Map<String, dynamic> json) =>
      _$PartCatalogFromJson(json);

  /// Throws [ArgumentError] for an unknown id: a RobotConfig must only ever
  /// name parts from the catalog.
  Part byId(String id) => parts.firstWhere(
    (part) => part.id == id,
    orElse: () => throw ArgumentError.value(id, 'id', 'Unknown part'),
  );

  /// Parts for one slot, in catalog order (the Workshop tile order).
  List<Part> inSlot(Slot slot) =>
      parts.where((part) => part.slot == slot).toList();
}
