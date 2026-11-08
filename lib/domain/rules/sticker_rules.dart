import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/part_catalog.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/sticker.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';

/// Fact names a sticker's `rule` can name (STK-01). Every one is a
/// discovery; none counts time or days played (STK-04).
abstract final class Fact {
  // In a run.
  static const jump = 'jump';
  static const bolt = 'bolt';
  static const splash = 'splash';
  static const boing = 'boing';
  static const mud = 'mud';
  static const jetpack = 'jetpack';
  static const heavySwitch = 'switch';
  static const swing = 'swing';
  static const leaves = 'leaves';
  static const ramp = 'ramp';
  static const ceiling = 'ceiling';
  static const gate = 'gate';
  static const pitStop = 'pitStop';
  static const hop = 'hop';
  static const hint = 'hint';
  static const testTrackLap = 'testTrackLap';

  // In the Workshop.
  static const paint = 'paint';
  static const decal = 'decal';
  static const headSwap = 'headSwap';
  static const newPart = 'newPart';

  // Read from progress.
  static const allMoves = 'allMoves';
  static const threeStars = 'threeStars';
  static const goldHead = 'goldHead';
  static const world1 = 'world1';
}

class StickerRules {
  const StickerRules({
    required this.stickers,
    required this.catalog,
    required this.courses,
  });

  final List<Sticker> stickers;
  final PartCatalog catalog;
  final List<Course> courses;

  /// Facts from one run's events.
  Set<String> factsFromRun(Course course, Iterable<RunEvent> events) {
    final facts = <String>{};
    for (final event in events) {
      switch (event) {
        case JumpedEvent():
          facts.add(Fact.jump);
        case BoltCollectedEvent():
          facts.add(Fact.bolt);
        case FellEvent(:final obstacleIndex):
          final obstacle = obstacleIndex == null
              ? null
              : course.obstacles[obstacleIndex];
          if (obstacle is GapObstacle && obstacle.water) facts.add(Fact.splash);
        case BumpedEvent(:final obstacleIndex) when obstacleIndex != null:
          switch (course.obstacles[obstacleIndex]) {
            case StepsObstacle():
              facts.add(Fact.boing);
            case MudObstacle():
              facts.add(Fact.mud);
            default:
              break;
          }
        case JetpackOnEvent():
          facts.add(Fact.jetpack);
        case SwitchPressedEvent():
          facts.add(Fact.heavySwitch);
        case SwungEvent():
          facts.add(Fact.swing);
        case LeavesBlownEvent():
          facts.add(Fact.leaves);
        case RampLaunchEvent():
          facts.add(Fact.ramp);
        case CeilingBonkEvent():
          facts.add(Fact.ceiling);
        case GateOpenedEvent():
          facts.add(Fact.gate);
        case HappyHopEvent():
          facts.add(Fact.hop);
        default:
          break;
      }
    }
    return facts;
  }

  /// Facts that follow from saved progress.
  Set<String> factsFromProgress(ProfileData profile) {
    final moves = catalog.inSlot(Slot.moves).map((p) => p.id);
    final world1 = courses.where((c) => c.world == 1);
    return {
      if (moves.every(profile.partsTried.contains)) Fact.allMoves,
      if (profile.courseResults.values.any((r) => r.stars >= 3))
        Fact.threeStars,
      if (profile.robot.headId == 'head_gold') Fact.goldHead,
      if (world1.isNotEmpty &&
          world1.every((c) => profile.resultFor(c.id).completed))
        Fact.world1,
    };
  }

  /// Adds stickers for [facts] (plus progress facts) that the profile does
  /// not have yet. New ones wait in unrevealedStickerIds for the next Result
  /// or Workshop visit, never mid-run (STK-02).
  ProfileData award(ProfileData profile, Set<String> facts) {
    final all = {...facts, ...factsFromProgress(profile)};
    final earned = {
      for (final sticker in stickers)
        if (all.contains(sticker.rule) &&
            !profile.stickerIds.contains(sticker.id))
          sticker.id,
    };
    if (earned.isEmpty) return profile;
    return profile.copyWith(
      stickerIds: {...profile.stickerIds, ...earned},
      unrevealedStickerIds: {...profile.unrevealedStickerIds, ...earned},
    );
  }
}
