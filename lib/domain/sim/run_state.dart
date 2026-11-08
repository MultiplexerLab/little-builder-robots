import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_state.freezed.dart';

enum RunPhase {
  running,

  /// Stopped by a bump; rolls back to the checkpoint soon (SRS 4.4).
  bumped,

  /// Fell into a gap; returns to the checkpoint soon (SRS 4.4).
  fallen,

  /// Waiting on a pit stop pad for the child to swap parts (RUN-11).
  parked,
  finished,
}

/// A snapshot of a run for Flame to draw (SRS 7). Positions are px, with y
/// the robot's feet above ground level 0.
@freezed
abstract class RunState with _$RunState {
  const factory RunState({
    required int tick,

    /// Game time, which runs slower in Helper mode (HLP-04).
    required double elapsedSeconds,
    required double x,
    required double y,
    required double vy,
    required bool onGround,
    required RunPhase phase,
    required int checkpointIndex,
    required Set<int> collectedBolts,

    /// Open gates by obstacle index, with the seconds left, for the shrinking
    /// light ring (SRS 4.3).
    required Map<int, double> openGates,

    /// Heavy-switch doors (by obstacle index) that are open.
    required Set<int> openDoors,

    /// Leaf piles (by obstacle index) blown away by Fan arms.
    required Set<int> clearedLeaves,
    required int falls,
    required int bumps,

    /// On the ground with a gap one step ahead: the moment Helper mode jumps
    /// (HLP-02).
    required bool atGapEdge,

    /// Jetpack fuel left and full, in seconds (SRS 4.1).
    required double fuel,
    required double fuelMax,
    required bool thrusting,

    /// Hanging from a bar with Grabber arms.
    required bool onBar,

    /// Tutorial: stopped before the first gap until the child taps (ONB-02).
    required bool waitingForTap,
  }) = _RunState;
}

/// Something that happened during one simulation step, for sounds,
/// animations, stickers and the hint ladder.
@freezed
sealed class RunEvent with _$RunEvent {
  const factory RunEvent.jumped() = JumpedEvent;
  const factory RunEvent.landed() = LandedEvent;

  /// A tap in Helper mode: a little hop on the spot that changes nothing
  /// (HLP-05).
  const factory RunEvent.happyHop() = HappyHopEvent;
  const factory RunEvent.boltCollected(int boltIndex) = BoltCollectedEvent;
  const factory RunEvent.gateOpened(int obstacleIndex) = GateOpenedEvent;
  const factory RunEvent.switchPressed(int obstacleIndex) = SwitchPressedEvent;
  const factory RunEvent.leavesBlown(int obstacleIndex) = LeavesBlownEvent;
  const factory RunEvent.swung(int obstacleIndex) = SwungEvent;
  const factory RunEvent.rampLaunch(int obstacleIndex) = RampLaunchEvent;
  const factory RunEvent.jetpackOn() = JetpackOnEvent;
  const factory RunEvent.ceilingBonk() = CeilingBonkEvent;

  /// [obstacleIndex] is the obstacle the failure counts against for the hint
  /// ladder (RUN-13), when there is one.
  const factory RunEvent.bumped(int? obstacleIndex) = BumpedEvent;
  const factory RunEvent.fell(int? obstacleIndex) = FellEvent;
  const factory RunEvent.respawned(int checkpointIndex) = RespawnedEvent;
  const factory RunEvent.checkpointReached(int checkpointIndex) =
      CheckpointReachedEvent;
  const factory RunEvent.parked(int checkpointIndex) = ParkedEvent;
  const factory RunEvent.finished() = FinishedEvent;
}
