import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:little_builder_robots/core/storage/key_value_store.dart';
import 'package:little_builder_robots/data/game_data.dart';
import 'package:little_builder_robots/data/progress_repository.dart';
import 'package:little_builder_robots/data/settings_repository.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/decal.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/run_outcome.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/models/stats.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';
import 'package:little_builder_robots/domain/rules/star_rules.dart';
import 'package:little_builder_robots/domain/rules/stat_calculator.dart';
import 'package:little_builder_robots/domain/rules/sticker_rules.dart';
import 'package:little_builder_robots/domain/rules/test_track_builder.dart';
import 'package:little_builder_robots/domain/rules/unlock_rules.dart';

/// Loaded in main() and overridden in the ProviderScope.
final gameDataProvider = Provider<GameData>(
  (ref) => throw UnimplementedError('Override gameDataProvider at start-up'),
);

/// The save store, opened in main() and overridden in the ProviderScope.
final storeProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('Override storeProvider at start-up'),
);

final unlockRulesProvider = Provider<UnlockRules>((ref) {
  final data = ref.watch(gameDataProvider);
  return UnlockRules(
    catalog: data.catalog,
    courses: data.courses,
    decals: data.decals,
  );
});

final statCalculatorProvider = Provider<StatCalculator>(
  (ref) => StatCalculator(ref.watch(gameDataProvider).catalog),
);

final stickerRulesProvider = Provider<StickerRules>((ref) {
  final data = ref.watch(gameDataProvider);
  return StickerRules(
    stickers: data.stickers,
    catalog: data.catalog,
    courses: data.courses,
  );
});

final obstacleCoachProvider = Provider<ObstacleCoach>((ref) {
  final data = ref.watch(gameDataProvider);
  return ObstacleCoach(catalog: data.catalog, tuning: data.tuning);
});

final testTrackBuilderProvider = Provider<TestTrackBuilder>((ref) {
  final data = ref.watch(gameDataProvider);
  return TestTrackBuilder(data: data.testTrack, courses: data.courses);
});

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(
    store: ref.watch(storeProvider),
    rules: ref.watch(unlockRulesProvider),
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(store: ref.watch(storeProvider)),
);

/// What a run paid out, for the Result screen (RES-01 to RES-04).
class RunReport {
  const RunReport({
    required this.courseId,
    required this.outcome,
    required this.stars,
    required this.runBolts,
    required this.rewardBolts,
    required this.newPartId,
    required this.newStickerIds,
    required this.previousStars,
  });

  final String courseId;
  final RunOutcome outcome;
  final StarAward stars;
  final int runBolts;
  final int rewardBolts;
  final String? newPartId;
  final Set<String> newStickerIds;
  final int previousStars;
}

/// The saved progress. Every change is saved at once (SAV-01).
class ProgressController extends Notifier<Progress> {
  @override
  Progress build() => ref.read(progressRepositoryProvider).load().progress;

  UnlockRules get _rules => ref.read(unlockRulesProvider);
  StickerRules get _stickers => ref.read(stickerRulesProvider);
  ProfileData get profile => state.profile;

  void _set(ProfileData profile, {Set<String> facts = const {}}) {
    final awarded = _stickers.award(profile, facts);
    final profiles = [...state.profiles];
    profiles[state.activeProfile] = awarded;
    state = state.copyWith(profiles: profiles);
    unawaited(ref.read(progressRepositoryProvider).save(state));
  }

  /// WRK-03.
  void equip(Part part) {
    final before = profile.robot;
    _set(
      _rules.equip(profile, part),
      facts: {
        if (part.slot == Slot.head && part.id != before.headId) Fact.headSwap,
      },
    );
  }

  /// WRK-05: buys and equips. Returns false if it could not be bought.
  bool buyPart(Part part) {
    if (_rules.checkPart(profile, part) != BuyCheck.canBuy) return false;
    final bought = _rules.buyPart(profile, part);
    _set(_rules.equip(bought, part), facts: {Fact.newPart});
    return true;
  }

  /// WRK-10: buys and wears a decal.
  bool buyDecal(Decal decal) {
    if (_rules.checkDecal(profile, decal) != BuyCheck.canBuy) return false;
    final bought = _rules.buyDecal(profile, decal);
    _set(
      bought.copyWith(robot: bought.robot.copyWith(decalId: decal.id)),
      facts: {Fact.decal},
    );
    return true;
  }

  /// WRK-06.
  void paint(String colour) => _set(
    profile.copyWith(robot: profile.robot.copyWith(colour: colour)),
    facts: {Fact.paint},
  );

  /// WRK-10: wears an owned decal, or none.
  void wearDecal(String? decalId) => _set(
    profile.copyWith(robot: profile.robot.copyWith(decalId: decalId)),
    facts: {if (decalId != null) Fact.decal},
  );

  /// RES-02 to RES-06 and STK: pays out a run and awards its stickers.
  RunReport applyRun(Course course, RunOutcome outcome, Set<String> facts) {
    final before = profile;
    final reward = _rules.applyRun(profile, course, outcome);
    _set(
      reward.profile,
      facts: {...facts, if (reward.newPartId != null) Fact.newPart},
    );
    return RunReport(
      courseId: course.id,
      outcome: outcome,
      stars: reward.stars,
      runBolts: reward.runBolts,
      rewardBolts: reward.rewardBolts,
      newPartId: reward.newPartId,
      newStickerIds: profile.unrevealedStickerIds.difference(
        before.unrevealedStickerIds,
      ),
      previousStars: before.resultFor(course.id).stars,
    );
  }

  /// Records discoveries outside a course run (Test Track, hints).
  void addFacts(Set<String> facts) => _set(profile, facts: facts);

  /// STK-02: the reveal has been shown.
  void markStickersRevealed() =>
      _set(profile.copyWith(unrevealedStickerIds: const {}));

  /// PAR-05, PAR-07: adds play time to today's total.
  void addPlaySeconds(String day, int seconds) {
    final days = {...profile.playSecondsByDay};
    days[day] = (days[day] ?? 0) + seconds;
    _set(profile.copyWith(playSecondsByDay: days));
  }

  /// PAR-07: "10 more minutes" from a grown-up.
  void addBonusSeconds(String day, int seconds) {
    final days = {...profile.bonusSecondsByDay};
    days[day] = (days[day] ?? 0) + seconds;
    _set(profile.copyWith(bonusSecondsByDay: days));
  }

  /// PAR-04: reset progress, after the second confirm.
  void reset() {
    state = Progress(profiles: [_rules.newProfile()]);
    unawaited(ref.read(progressRepositoryProvider).save(state));
  }
}

final progressProvider = NotifierProvider<ProgressController, Progress>(
  ProgressController.new,
);

final profileProvider = Provider<ProfileData>(
  (ref) => ref.watch(progressProvider).profile,
);

/// The robot's stats, for the "Good at" panel and the run.
final robotStatsProvider = Provider<Stats>(
  (ref) => ref
      .watch(statCalculatorProvider)
      .statsFor(ref.watch(profileProvider).robot),
);

/// Grown-ups settings, saved on every change (PAR-04).
class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => ref.read(settingsRepositoryProvider).load().settings;

  void update(Settings Function(Settings) change) {
    state = change(state);
    unawaited(ref.read(settingsRepositoryProvider).save(state));
  }
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);

/// The course the Workshop and run are set up for (HOM-03, MAP-04).
class SelectedCourseController extends Notifier<String> {
  @override
  String build() => nextCourse(
    ref.read(gameDataProvider).courses,
    ref.read(profileProvider),
  ).id;

  // A plain method reads better at call sites than a setter here.
  // ignore: use_setters_to_change_properties
  void select(String courseId) => state = courseId;

  /// HOM-03: the next unplayed course, or course 15 when all are done.
  static Course nextCourse(List<Course> courses, ProfileData profile) =>
      courses.firstWhere(
        (c) => !profile.resultFor(c.id).completed,
        orElse: () => courses.last,
      );
}

final selectedCourseProvider =
    NotifierProvider<SelectedCourseController, String>(
      SelectedCourseController.new,
    );

final selectedCourseDataProvider = Provider<Course>(
  (ref) =>
      ref.watch(gameDataProvider).courseById(ref.watch(selectedCourseProvider)),
);

/// A simple settable value, for short-lived UI hand-offs.
class ValueController<T> extends Notifier<T> {
  ValueController(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  void set(T value) {
    // A deferred update may land after the app has closed.
    if (ref.mounted) state = value;
  }
}

/// The last run's payout, read by the Result screen.
final lastRunProvider =
    NotifierProvider<ValueController<RunReport?>, RunReport?>(
      () => ValueController<RunReport?>(null),
    );

/// WRK-12: the part a hint suggested, glowing in the Workshop until tapped.
final suggestedPartProvider =
    NotifierProvider<ValueController<String?>, String?>(
      () => ValueController<String?>(null),
    );

/// PAR-03: set by a correct Parent gate answer; the Grown-ups route checks
/// it and clears it on the way out.
final gatePassedProvider = NotifierProvider<ValueController<bool>, bool>(
  () => ValueController<bool>(false),
);

/// ONB-02: the first Workshop visit shows the hand animation.
final workshopTutorialSeenProvider =
    NotifierProvider<ValueController<bool>, bool>(
      () => ValueController<bool>(false),
    );
