import 'package:freezed_annotation/freezed_annotation.dart';

part 'stats.freezed.dart';
part 'stats.g.dart';

/// The five robot stats (SRS 4.1). Each runs 0 to the catalog's statMax.
enum Stat { speed, climb, jump, weight, fuel }

/// Special abilities a part can give (SRS 4.2, 4.3).
enum Ability { jetpack, grab, fan, mudproof }

/// Stat modifiers on a part, and the base stats of every robot (SRS 4.1).
@freezed
abstract class StatMods with _$StatMods {
  const factory StatMods({
    @Default(0) int speed,
    @Default(0) int climb,
    @Default(0) int jump,
    @Default(0) int weight,
    @Default(0) int fuel,
  }) = _StatMods;

  const StatMods._();

  factory StatMods.fromJson(Map<String, dynamic> json) =>
      _$StatModsFromJson(json);

  int valueOf(Stat stat) => switch (stat) {
    Stat.speed => speed,
    Stat.climb => climb,
    Stat.jump => jump,
    Stat.weight => weight,
    Stat.fuel => fuel,
  };
}

/// A robot's resolved stats. Derived by StatCalculator, never stored
/// (SRS 7.3).
@freezed
abstract class Stats with _$Stats {
  const factory Stats({
    required int speed,
    required int climb,
    required int jump,
    required int weight,
    required int fuel,
    @Default(<Ability>{}) Set<Ability> abilities,
  }) = _Stats;

  const Stats._();

  int valueOf(Stat stat) => switch (stat) {
    Stat.speed => speed,
    Stat.climb => climb,
    Stat.jump => jump,
    Stat.weight => weight,
    Stat.fuel => fuel,
  };

  bool has(Ability ability) => abilities.contains(ability);
}
