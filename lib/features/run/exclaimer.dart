import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';

/// Decides when the robot shouts something in a run ("Wheee!", "Boing!").
/// The words are exclamations, not instructions, so they never replace a
/// hint. Each has a voice clip with the same key (AUD-02).
class Exclaimer {
  Exclaimer(this.course);

  final Course course;

  /// The robot shouts at most this often, so it never chatters.
  static const cooldown = 1.6;

  /// How long a bubble stays up.
  static const showFor = 1.2;

  double _lastAt = -cooldown;
  bool _saidYum = false;
  String? _key;
  double _until = 0;

  /// When the current bubble goes away.
  double get untilAt => _until;

  /// What the robot is saying at [now], if anything.
  String? currentAt(double now) => now < _until ? _key : null;

  /// The l10n key to shout for [event] at time [now] (seconds), or null.
  /// [firstFailure] is true when a bump or fall is the first at that
  /// obstacle: later ones get a hint instead (RUN-13), so the robot stays
  /// quiet and doesn't talk over it.
  String? react(RunEvent event, double now, {bool firstFailure = false}) {
    final key = switch (event) {
      RampLaunchEvent() => 'sayWhee',
      JetpackOnEvent() || LeavesBlownEvent() => 'sayWhoosh',
      SwungEvent() => 'saySwing',
      SwitchPressedEvent() => 'sayClunk',
      GateOpenedEvent() => 'sayZoom',
      FinishedEvent() => 'sayHooray',
      GearFoundEvent() => 'sayGear',
      BoltCollectedEvent() when !_saidYum => 'sayYum',
      BumpedEvent() when firstFailure => 'sayBoing',
      FellEvent(:final obstacleIndex) when firstFailure =>
        _isWater(obstacleIndex) ? 'saySplash' : 'sayWhoops',
      _ => null,
    };
    if (key == null) return null;
    // The finish and a golden gear always get their cheer.
    final always = key == 'sayHooray' || key == 'sayGear';
    if (!always && now - _lastAt < cooldown) return null;
    if (key == 'sayYum') _saidYum = true;
    _lastAt = now;
    _key = key;
    _until = now + showFor;
    return key;
  }

  bool _isWater(int? index) {
    if (index == null) return false;
    final o = course.obstacles[index];
    return o is GapObstacle && o.water;
  }

  /// A restart begins a fresh run.
  void reset() {
    _lastAt = -cooldown;
    _saidYum = false;
    _key = null;
    _until = 0;
  }
}
