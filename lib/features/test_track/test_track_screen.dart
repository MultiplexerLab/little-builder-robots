import 'package:flutter/material.dart';
import 'package:little_builder_robots/features/run/run_screen.dart';

/// Test Track (TRK-01 to TRK-04): the run screen on an endless loop of the
/// obstacle types met so far, each followed by a pit stop. No stars, bolts,
/// timers or finish. Home keeps it locked until course 3 (TRK-01).
class TestTrackScreen extends StatelessWidget {
  const TestTrackScreen({super.key});

  @override
  Widget build(BuildContext context) => const RunScreen(testTrack: true);
}
