import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:little_builder_robots/app/app.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/services.dart';
import 'package:little_builder_robots/core/audio/audio_service.dart';
import 'package:little_builder_robots/core/storage/key_value_store.dart';
import 'package:little_builder_robots/data/game_data_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape only (SRS 2.2); the iOS and Android manifests match.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Saves live in the app's documents folder, on this device only (PRV-08).
  await Hive.initFlutter();
  final store = await HiveKeyValueStore.open();
  final data = await GameDataRepository(rootBundle).loadAll();
  final audio = await AudioService.create(rootBundle);

  runApp(
    ProviderScope(
      overrides: [
        gameDataProvider.overrideWithValue(data),
        storeProvider.overrideWithValue(store),
        audioProvider.overrideWithValue(audio),
      ],
      child: const App(),
    ),
  );
}
