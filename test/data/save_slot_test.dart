import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/core/storage/key_value_store.dart';
import 'package:little_builder_robots/data/save_slot.dart';

/// A tiny saved value for testing the slot on its own.
typedef Saved = ({int bolts});

void main() {
  late MemoryKeyValueStore store;

  SaveSlot<Saved> slot({int version = 1, Map<int, Migration>? migrations}) =>
      SaveSlot(
        store: store,
        key: 'k',
        version: version,
        migrations: migrations ?? const {},
        fromJson: (json) => (bolts: json['bolts'] as int),
        toJson: (box) => {'bolts': box.bolts},
        defaults: () => (bolts: 0),
      );

  Map<String, dynamic> stored(String key) =>
      jsonDecode(store.values[key]!) as Map<String, dynamic>;

  setUp(() => store = MemoryKeyValueStore());

  test('first launch loads defaults', () {
    expect(slot().load(), (value: (bolts: 0), source: LoadSource.defaults));
  });

  test('a save loads back with its schema version (SAV-01, SAV-02)', () async {
    await slot().save((bolts: 7));
    expect(jsonDecode(store.values['k']!), {'bolts': 7, 'schemaVersion': 1});
    expect(slot().load(), (value: (bolts: 7), source: LoadSource.primary));
  });

  test('each save keeps the previous good save as the backup', () async {
    final s = slot();
    await s.save((bolts: 1));
    await s.save((bolts: 2));
    expect(stored('k.backup')['bolts'], 1);
  });

  group('SAV-03 corrupt saves', () {
    Future<void> goodThenCorrupt(String corrupt) async {
      final s = slot();
      await s.save((bolts: 1));
      await s.save((bolts: 2));
      store.values['k'] = corrupt;
    }

    for (final (name, corrupt) in [
      ('not JSON', '{"bolts": 2, "sch'),
      ('wrong types', '{"bolts": "two", "schemaVersion": 1}'),
      ('no version', '{"bolts": 2}'),
      ('not an object', '[1, 2]'),
    ]) {
      test('$name: the backup is tried first', () async {
        await goodThenCorrupt(corrupt);
        expect(slot().load(), (value: (bolts: 1), source: LoadSource.backup));
      });
    }

    test('both broken: defaults, no crash', () {
      store.values['k'] = 'garbage';
      store.values['k.backup'] = 'garbage';
      expect(slot().load().source, LoadSource.defaults);
    });

    test('saving after a corrupt load keeps the good backup', () async {
      await goodThenCorrupt('garbage');
      final s = slot()..load();
      await s.save((bolts: 5));
      expect(stored('k.backup')['bolts'], 1);
      expect(slot().load().value, (bolts: 5));
    });

    test('a save from a newer build is not read', () {
      store.values['k'] = '{"bolts": 9, "schemaVersion": 2}';
      expect(slot().load().source, LoadSource.defaults);
    });
  });

  group('SAV-02 migrations', () {
    final migrations = <int, Migration>{
      // v1 stored "coins"; v2 renamed it to "bolts".
      1: (json) => {...json, 'bolts': json['coins']},
      // v3 doubled every value.
      2: (json) => {...json, 'bolts': (json['bolts'] as int) * 2},
    };

    test('an old save is upgraded step by step', () {
      store.values['k'] = '{"coins": 4, "schemaVersion": 1}';
      final loaded = slot(version: 3, migrations: migrations).load();
      expect(loaded, (value: (bolts: 8), source: LoadSource.primary));
    });

    test('the upgraded save is written at the new version', () async {
      store.values['k'] = '{"coins": 4, "schemaVersion": 1}';
      final s = slot(version: 3, migrations: migrations);
      await s.save(s.load().value);
      expect(stored('k')['schemaVersion'], 3);
      expect(stored('k.backup')['schemaVersion'], 1);
    });

    test('a missing migration falls back instead of crashing', () {
      store.values['k'] = '{"coins": 4, "schemaVersion": 1}';
      expect(slot(version: 2).load().source, LoadSource.defaults);
    });
  });
}
