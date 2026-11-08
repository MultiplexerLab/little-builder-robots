import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/decal.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/part_catalog.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/run_outcome.dart';
import 'package:little_builder_robots/domain/rules/star_rules.dart';

/// Whether a part or decal can be bought right now.
enum BuyCheck {
  /// Enough bolts: show the kid-level confirm (WRK-05).
  canBuy,

  /// Not enough bolts: shake the counter, nothing is lost (WRK-11).
  needMoreBolts,

  /// Already unlocked.
  owned,

  /// Only earned as a course reward.
  notForSale,
}

/// What a finished run paid out, for the Result screen (RES-03, RES-04).
typedef RunReward = ({
  ProfileData profile,
  StarAward stars,
  int runBolts,
  int rewardBolts,
  String? newPartId,
});

/// Ownership, buying, equipping, course unlocks and run payouts
/// (SRS 4.2, 4.6, MAP-03, RES-02 to RES-06).
class UnlockRules {
  UnlockRules({
    required this.catalog,
    required List<Course> courses,
    this.decals = const [],
  }) : _courses = {
         for (final course in courses) (course.world, course.index): course,
       };

  final PartCatalog catalog;
  final List<Decal> decals;
  final Map<(int, int), Course> _courses;

  /// A fresh profile: start parts, free decals and the default robot.
  ProfileData newProfile() => ProfileData(
    robot: catalog.defaultRobot,
    unlockedPartIds: {
      for (final part in catalog.parts)
        if (part.unlock is StartUnlock) part.id,
    },
    unlockedDecalIds: {
      for (final decal in decals)
        if (decal.cost == 0) decal.id,
    },
    partsTried: catalog.defaultRobot.partIds.toSet(),
  );

  bool ownsPart(ProfileData profile, String partId) =>
      profile.unlockedPartIds.contains(partId);

  BuyCheck checkPart(ProfileData profile, Part part) {
    if (ownsPart(profile, part.id)) return BuyCheck.owned;
    return switch (part.unlock) {
      BoltsUnlock(:final cost) => _checkCost(profile, cost),
      StartUnlock() || RewardUnlock() => BuyCheck.notForSale,
    };
  }

  /// Spends bolts on [part]. Throws [StateError] unless [checkPart] says
  /// [BuyCheck.canBuy].
  ProfileData buyPart(ProfileData profile, Part part) {
    final check = checkPart(profile, part);
    if (check != BuyCheck.canBuy) {
      throw StateError('Cannot buy ${part.id}: ${check.name}');
    }
    final cost = (part.unlock as BoltsUnlock).cost;
    return profile.copyWith(
      bolts: profile.bolts - cost,
      unlockedPartIds: {...profile.unlockedPartIds, part.id},
    );
  }

  BuyCheck checkDecal(ProfileData profile, Decal decal) {
    if (profile.unlockedDecalIds.contains(decal.id)) return BuyCheck.owned;
    return _checkCost(profile, decal.cost);
  }

  /// Spends bolts on [decal]. Throws [StateError] unless [checkDecal] says
  /// [BuyCheck.canBuy].
  ProfileData buyDecal(ProfileData profile, Decal decal) {
    final check = checkDecal(profile, decal);
    if (check != BuyCheck.canBuy) {
      throw StateError('Cannot buy ${decal.id}: ${check.name}');
    }
    return profile.copyWith(
      bolts: profile.bolts - decal.cost,
      unlockedDecalIds: {...profile.unlockedDecalIds, decal.id},
    );
  }

  /// Puts an owned part on the robot (WRK-03). Throws [StateError] for a
  /// locked part.
  ProfileData equip(ProfileData profile, Part part) {
    if (!ownsPart(profile, part.id)) {
      throw StateError('Cannot equip locked part ${part.id}');
    }
    return profile.copyWith(
      robot: profile.robot.withPart(part.slot, part.id),
      partsTried: {...profile.partsTried, part.id},
    );
  }

  /// MAP-03: the first course of a world is always open; any other opens
  /// when the one before it has at least 1 star.
  bool isCourseUnlocked(ProfileData profile, Course course) {
    if (course.index == 1) return true;
    final previous = _courses[(course.world, course.index - 1)];
    if (previous == null) {
      throw StateError('No course before ${course.id}');
    }
    return profile.resultFor(previous.id).stars >= 1;
  }

  /// Pays out a run (RES-02 to RES-06). Collected bolts are always kept, even
  /// when the child leaves before the flag (Pause to Restart, Workshop, Map
  /// or Home). Stars, reward bolts and the reward part need a finish, and the
  /// rewards pay only on the first one.
  RunReward applyRun(ProfileData profile, Course course, RunOutcome outcome) {
    if (!outcome.finished) {
      return (
        profile: profile.copyWith(
          bolts: profile.bolts + outcome.boltsCollected,
        ),
        stars: starsFor(outcome),
        runBolts: outcome.boltsCollected,
        rewardBolts: 0,
        newPartId: null,
      );
    }
    final previous = profile.resultFor(course.id);
    final firstFinish = !previous.rewardClaimed;
    final rewardBolts = firstFinish ? course.rewardBolts : 0;
    final rewardPartId = course.rewardPartId;
    final newPartId =
        firstFinish && rewardPartId != null && !ownsPart(profile, rewardPartId)
        ? catalog.byId(rewardPartId).id
        : null;

    return (
      profile: profile.copyWith(
        bolts: profile.bolts + outcome.boltsCollected + rewardBolts,
        unlockedPartIds: {...profile.unlockedPartIds, ?newPartId},
        courseResults: {
          ...profile.courseResults,
          course.id: bestResult(
            previous,
            outcome,
          ).copyWith(rewardClaimed: true),
        },
      ),
      stars: starsFor(outcome),
      runBolts: outcome.boltsCollected,
      rewardBolts: rewardBolts,
      newPartId: newPartId,
    );
  }

  BuyCheck _checkCost(ProfileData profile, int cost) =>
      profile.bolts >= cost ? BuyCheck.canBuy : BuyCheck.needMoreBolts;
}
