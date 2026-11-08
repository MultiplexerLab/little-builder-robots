import 'package:little_builder_robots/core/storage/key_value_store.dart';
import 'package:little_builder_robots/data/save_slot.dart';
import 'package:little_builder_robots/domain/models/settings.dart';

/// Grown-ups settings on this device (SAV-01 to SAV-03, PAR-04).
class SettingsRepository {
  SettingsRepository({
    required KeyValueStore store,
    Map<int, Migration> migrations = const {},
  }) : _slot = SaveSlot(
         store: store,
         key: 'settings',
         version: schemaVersion,
         migrations: migrations,
         fromJson: Settings.fromJson,
         toJson: (settings) => settings.toJson(),
         defaults: Settings.new,
       );

  static const schemaVersion = 1;

  final SaveSlot<Settings> _slot;

  ({Settings settings, LoadSource source}) load() {
    final (:value, :source) = _slot.load();
    return (settings: value, source: source);
  }

  Future<void> save(Settings settings) => _slot.save(settings);
}
