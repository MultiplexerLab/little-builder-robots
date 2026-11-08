import 'dart:convert';

import 'package:little_builder_robots/core/storage/key_value_store.dart';

/// Upgrades a saved map from one schema version to the next.
typedef Migration = Map<String, dynamic> Function(Map<String, dynamic> json);

/// Where a load came from, so tests (and a debug overlay) can tell.
enum LoadSource { primary, backup, defaults }

/// One saved value with a schema version, migrations and a backup copy
/// (SAV-01 to SAV-03).
///
/// The JSON is stored under [key] with a `schemaVersion` field. Each save
/// first copies the last good save to `key.backup`. A load tries the main
/// copy, then the backup, then falls back to [defaults]; it never throws.
class SaveSlot<T> {
  SaveSlot({
    required this.store,
    required this.key,
    required this.version,
    required this.fromJson,
    required this.toJson,
    required this.defaults,
    this.migrations = const {},
  });

  static const _versionKey = 'schemaVersion';

  final KeyValueStore store;
  final String key;

  /// The schema version this build writes.
  final int version;

  /// `migrations[n]` turns a version n save into version n + 1.
  final Map<int, Migration> migrations;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T value) toJson;
  final T Function() defaults;

  String get _backupKey => '$key.backup';

  /// Whether the main copy last loaded cleanly. A broken main copy is never
  /// moved over a good backup.
  bool _mainIsGood = false;

  ({T value, LoadSource source}) load() {
    final main = _decode(store.read(key));
    _mainIsGood = main != null;
    if (main != null) return (value: main, source: LoadSource.primary);
    final backup = _decode(store.read(_backupKey));
    if (backup != null) return (value: backup, source: LoadSource.backup);
    return (value: defaults(), source: LoadSource.defaults);
  }

  Future<void> save(T value) async {
    final previous = store.read(key);
    if (_mainIsGood && previous != null) {
      await store.write(_backupKey, previous);
    }
    final json = {...toJson(value), _versionKey: version};
    await store.write(key, jsonEncode(json));
    _mainIsGood = true;
  }

  /// Null for a missing, corrupt or unreadable save. A save from a newer
  /// build than this one counts as unreadable.
  T? _decode(String? raw) {
    if (raw == null) return null;
    try {
      var json = jsonDecode(raw) as Map<String, dynamic>;
      var from = json[_versionKey] as int;
      if (from > version) return null;
      while (from < version) {
        json = migrations[from]!(json);
        from++;
      }
      return fromJson(json);
    } on Object {
      return null;
    }
  }
}
