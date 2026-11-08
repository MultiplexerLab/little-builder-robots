import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/part_catalog.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/models/stats.dart';

/// One stat before and after a part swap (WRK-05).
typedef StatChange = ({int before, int after});

/// Turns parts into stats (SRS 4.1). The Workshop, the run, Test Track and
/// the solver test all use this, so no screen computes stats itself.
class StatCalculator {
  const StatCalculator(this.catalog);

  final PartCatalog catalog;

  /// Robot stat = base + sum of equipped part modifiers, clamped to
  /// 0..statMax. Abilities are the union of the parts' abilities.
  Stats statsFor(RobotConfig robot) =>
      statsForParts(robot.partIds.map(catalog.byId));

  Stats statsForParts(Iterable<Part> parts) {
    final equipped = parts.toList();
    int total(Stat stat) => equipped
        .fold(
          catalog.baseStats.valueOf(stat),
          (sum, part) => sum + part.mods.valueOf(stat),
        )
        .clamp(0, catalog.statMax);

    return Stats(
      speed: total(Stat.speed),
      climb: total(Stat.climb),
      jump: total(Stat.jump),
      weight: total(Stat.weight),
      fuel: total(Stat.fuel),
      abilities: {for (final part in equipped) ?part.ability},
    );
  }

  /// The stats that change if [candidate] replaces the part in its slot,
  /// for the unlock confirm (WRK-05). Unchanged stats are left out.
  Map<Stat, StatChange> changesIfEquipped(RobotConfig robot, Part candidate) {
    final before = statsFor(robot);
    final after = statsFor(robot.withPart(candidate.slot, candidate.id));
    return {
      for (final stat in Stat.values)
        if (before.valueOf(stat) != after.valueOf(stat))
          stat: (before: before.valueOf(stat), after: after.valueOf(stat)),
    };
  }
}
