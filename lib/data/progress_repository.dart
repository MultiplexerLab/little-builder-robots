import 'package:little_builder_robots/core/storage/key_value_store.dart';
import 'package:little_builder_robots/data/save_slot.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/part_catalog.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/rules/unlock_rules.dart';

/// The child's progress on this device (SAV-01 to SAV-04).
class ProgressRepository {
  ProgressRepository({
    required KeyValueStore store,
    required UnlockRules rules,
    Map<int, Migration> migrations = const {},
  }) : _catalog = rules.catalog,
       _slot = SaveSlot(
         store: store,
         key: 'progress',
         version: schemaVersion,
         migrations: migrations,
         fromJson: Progress.fromJson,
         toJson: (progress) => progress.toJson(),
         defaults: () => Progress(profiles: [rules.newProfile()]),
       );

  /// Bump this and add a migration whenever the saved shape changes.
  static const schemaVersion = 1;

  final PartCatalog _catalog;
  final SaveSlot<Progress> _slot;

  /// Never throws: a broken save falls back to the backup, then to a fresh
  /// start (SAV-03).
  ({Progress progress, LoadSource source}) load() {
    final (:value, :source) = _slot.load();
    return (progress: _withKnownParts(value), source: source);
  }

  Future<void> save(Progress progress) => _slot.save(progress);

  /// An app update may drop or rename a part. Forget unknown parts and put
  /// the default part back in any slot that used one, so the robot always
  /// draws and the stats always resolve (SAV-02).
  Progress _withKnownParts(Progress progress) {
    final known = {for (final part in _catalog.parts) part.id};
    final fallback = _catalog.defaultRobot;
    ProfileData clean(ProfileData profile) {
      var robot = profile.robot;
      for (final slot in Slot.values) {
        final id = robot.partIdFor(slot);
        if (!known.contains(id) || _catalog.byId(id).slot != slot) {
          robot = robot.withPart(slot, fallback.partIdFor(slot));
        }
      }
      return profile.copyWith(
        robot: robot,
        unlockedPartIds: {
          ...profile.unlockedPartIds.where(known.contains),
          ...robot.partIds,
        },
      );
    }

    final profiles = progress.profiles.map(clean).toList();
    final active = progress.activeProfile;
    return progress.copyWith(
      profiles: profiles,
      activeProfile: active >= 0 && active < profiles.length ? active : 0,
    );
  }
}
