import 'package:hive_ce/hive_ce.dart';

/// String storage on the device. Saves never leave it (PRV, NFR-13).
abstract interface class KeyValueStore {
  String? read(String key);
  Future<void> write(String key, String value);
}

/// The app's store: one Hive box of JSON strings. Storing JSON instead of
/// Hive type adapters keeps migrations a plain map-to-map step (SAV-02).
class HiveKeyValueStore implements KeyValueStore {
  HiveKeyValueStore(this._box);

  /// Opens the save box. Hive must be initialised first (Hive.init with the
  /// app documents directory).
  static Future<HiveKeyValueStore> open({String name = 'save'}) async =>
      HiveKeyValueStore(await Hive.openBox<String>(name));

  final Box<String> _box;

  @override
  String? read(String key) => _box.get(key);

  @override
  Future<void> write(String key, String value) => _box.put(key, value);
}

/// For tests and previews.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? read(String key) => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
