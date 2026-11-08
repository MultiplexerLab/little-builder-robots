import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/app/app.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/router.dart';
import 'package:little_builder_robots/core/storage/key_value_store.dart';
import 'package:little_builder_robots/core/utils/touch_guard.dart';
import 'package:little_builder_robots/data/game_data.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/settings.dart';

import 'game_data.dart';

final GameData testData = loadGameData();

/// A store with saved settings and, optionally, a saved profile.
MemoryKeyValueStore seededStore({
  Settings settings = const Settings(onboardingDone: true),
  ProfileData? profile,
}) {
  final store = MemoryKeyValueStore();
  store.values['settings'] = jsonEncode({
    ...settings.toJson(),
    'schemaVersion': 1,
  });
  if (profile != null) {
    store.values['progress'] = jsonEncode({
      ...Progress(profiles: [profile]).toJson(),
      'schemaVersion': 1,
    });
  }
  return store;
}

/// Landscape iPhone (844 x 390 pt).
void landscape(WidgetTester tester, {Size size = const Size(844, 390)}) {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// Pumps the whole app at [location] with real game data and an in-memory
/// save. Returns the container to read providers.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  String location = '/home',
  KeyValueStore? store,
  Size size = const Size(844, 390),
}) async {
  landscape(tester, size: size);
  TouchGuard.instance.reset();
  final container = ProviderContainer(
    overrides: [
      gameDataProvider.overrideWithValue(testData),
      storeProvider.overrideWithValue(store ?? seededStore()),
      routerProvider.overrideWith(
        (ref) => createRouter(ref, initialLocation: location),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await tester.pump();
  return container;
}

/// Taps [finder] after the navigation repeat-tap window (NFR-19).
Future<void> tapNav(WidgetTester tester, Finder finder) async {
  TouchGuard.instance.reset();
  await tester.tap(finder);
  await tester.pump();
}
