import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/core/audio/audio_service.dart';
import 'package:little_builder_robots/core/haptics/haptics.dart';
import 'package:little_builder_robots/core/utils/play_clock.dart';

/// Overridden in main() with the real service; silent in tests.
final audioProvider = Provider<AudioService>((ref) => AudioService.silent());

final hapticsProvider = Provider<Haptics>(
  (ref) => Haptics(enabled: ref.watch(settingsProvider).haptics),
);

/// Counts play time into today's total (PAR-05, PAR-07).
final playClockProvider = Provider<PlayClock>((ref) {
  final clock = PlayClock(
    onSeconds: (day, seconds) =>
        ref.read(progressProvider.notifier).addPlaySeconds(day, seconds),
  );
  ref.onDispose(clock.dispose);
  return clock;
});

/// Today's play against the daily limit (PAR-07, PAR-11).
final playLimitProvider = Provider<PlayLimit>(
  (ref) => playLimit(
    ref.watch(profileProvider),
    ref.watch(settingsProvider),
    DateTime.now(),
  ),
);
