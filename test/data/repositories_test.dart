import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:little_builder_robots/core/storage/key_value_store.dart';
import 'package:little_builder_robots/data/game_data_repository.dart';
import 'package:little_builder_robots/data/progress_repository.dart';
import 'package:little_builder_robots/data/save_slot.dart';
import 'package:little_builder_robots/data/settings_repository.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/run_outcome.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/rules/unlock_rules.dart';

import '../helpers/game_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalog = loadCatalog();
  final rules = UnlockRules(
    catalog: catalog,
    courses: world1Courses(),
    decals: loadDecals(),
  );

  group('GameDataRepository (bundled assets)', () {
    final repo = GameDataRepository(rootBundle);

    test('loads parts, physics and decals', () async {
      expect(await repo.loadParts(), catalog);
      expect(await repo.loadTuning(), loadTuning());
      expect(await repo.loadDecals(), hasLength(8));
    });

    test('loads every World 1 course file in map order', () async {
      final courses = await repo.loadWorld(1);
      expect(courses, loadWorld1());
      expect(
        courses.map((c) => c.index),
        List.generate(courses.length, (i) => i + 1),
      );
    });
  });

  group('ProgressRepository', () {
    late MemoryKeyValueStore store;
    ProgressRepository repo() => ProgressRepository(store: store, rules: rules);

    setUp(() => store = MemoryKeyValueStore());

    test('first launch: one fresh profile', () {
      final (:progress, :source) = repo().load();
      expect(source, LoadSource.defaults);
      expect(progress.profiles, [rules.newProfile()]);
      expect(progress.activeProfile, 0);
    });

    test('saves and loads a played profile (SAV-01)', () async {
      final played = rules
          .applyRun(
            rules.newProfile(),
            world1Courses().first,
            const RunOutcome(
              finished: true,
              boltsCollected: 4,
              boltsOnCourse: 5,
              falls: 0,
            ),
          )
          .profile;
      await repo().save(Progress(profiles: [played]));
      final (:progress, :source) = repo().load();
      expect(source, LoadSource.primary);
      expect(progress.profile, played);
    });

    test('profiles are stored as a list (SAV-04)', () async {
      await repo().save(Progress(profiles: [rules.newProfile()]));
      final json = jsonDecode(store.values['progress']!) as Map;
      expect(json['profiles'], isA<List<dynamic>>());
      expect(json['schemaVersion'], ProgressRepository.schemaVersion);
    });

    test('parts removed in an update fall back to defaults (SAV-02)', () async {
      final profile = rules.newProfile();
      await repo().save(
        Progress(
          profiles: [
            profile.copyWith(
              robot: profile.robot.copyWith(
                movesId: 'moves_rocket',
                headId: 'arms_short', // a real part in the wrong slot
              ),
              unlockedPartIds: {...profile.unlockedPartIds, 'moves_rocket'},
            ),
          ],
          activeProfile: 3,
        ),
      );
      final progress = repo().load().progress;
      expect(progress.activeProfile, 0);
      expect(progress.profile.robot, catalog.defaultRobot);
      expect(progress.profile.unlockedPartIds, isNot(contains('moves_rocket')));
    });
  });

  test('SettingsRepository saves and loads', () async {
    final store = MemoryKeyValueStore();
    final repo = SettingsRepository(store: store);
    expect(repo.load().settings, const Settings());
    const changed = Settings(playStyle: PlayStyle.little, music: false);
    await repo.save(changed);
    expect(SettingsRepository(store: store).load().settings, changed);
  });

  test('saves survive closing and reopening Hive (SAV-02)', () async {
    final dir = await Directory.systemTemp.createTemp('lbr_hive');
    addTearDown(() => dir.delete(recursive: true));
    Hive.init(dir.path);

    final first = await HiveKeyValueStore.open();
    final profile = rules.newProfile().copyWith(bolts: 42);
    await ProgressRepository(
      store: first,
      rules: rules,
    ).save(Progress(profiles: [profile]));
    await Hive.close();

    final reopened = await HiveKeyValueStore.open();
    final loaded = ProgressRepository(store: reopened, rules: rules).load();
    expect(loaded.source, LoadSource.primary);
    expect(loaded.progress.profile.bolts, 42);
    await Hive.close();
  });
}
