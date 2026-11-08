import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/settings.dart';

/// The local calendar day, as yyyy-mm-dd (PAR-07).
String dayKey(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}-'
    '${time.month.toString().padLeft(2, '0')}-'
    '${time.day.toString().padLeft(2, '0')}';

/// Where today's play stands against the daily limit (PAR-07, PAR-11).
typedef PlayLimit = ({bool reached, bool windDown});

/// PAR-07 and PAR-11: whether the limit is reached, or within 5 minutes.
PlayLimit playLimit(ProfileData profile, Settings settings, DateTime now) {
  if (settings.dailyLimitMinutes <= 0) {
    return (reached: false, windDown: false);
  }
  final day = dayKey(now);
  final played = profile.playSecondsByDay[day] ?? 0;
  final allowed =
      settings.dailyLimitMinutes * 60 + (profile.bonusSecondsByDay[day] ?? 0);
  return (
    reached: played >= allowed,
    windDown: played >= allowed - 5 * 60 && played < allowed,
  );
}

/// Counts play time while the app is in front, a second at a time, and
/// reports it in small batches so saves stay cheap (PAR-05, PAR-07). Nothing
/// leaves the device (PRV-08).
class PlayClock extends ChangeNotifier {
  PlayClock({required this.onSeconds, this.batchSeconds = 15});

  /// Called with the day and seconds to add.
  final void Function(String day, int seconds) onSeconds;
  final int batchSeconds;

  Timer? _timer;
  int _pending = 0;
  String _day = dayKey(DateTime.now());

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// Stops counting without saving (the app is closing).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Stops counting and saves what is pending (app in background).
  void pause() {
    _timer?.cancel();
    _timer = null;
    flush();
  }

  @visibleForTesting
  void tick([DateTime? now]) {
    final day = dayKey(now ?? DateTime.now());
    if (day != _day) {
      flush();
      _day = day;
    }
    _pending++;
    if (_pending >= batchSeconds) flush();
  }

  void flush() {
    if (_pending == 0) return;
    onSeconds(_day, _pending);
    _pending = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
