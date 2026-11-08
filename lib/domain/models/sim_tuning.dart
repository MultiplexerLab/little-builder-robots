import 'package:freezed_annotation/freezed_annotation.dart';

part 'sim_tuning.freezed.dart';
part 'sim_tuning.g.dart';

/// Run physics tuning from assets/data/physics.json (SRS 4.1, 4.4, HLP-04).
/// Distances are px, times are seconds, speeds px/s.
@freezed
abstract class SimTuning with _$SimTuning {
  const factory SimTuning({
    /// Fixed simulation rate (SRS 7: 1/120 s steps).
    required int stepsPerSecond,

    /// Speed: speedBase + speedPerPoint x Speed.
    required double speedBase,
    required double speedPerPoint,

    /// Highest climbable step: climbPerPoint x Climb.
    required double climbPerPoint,

    /// Jump height: jumpBase + jumpPerPoint x Jump.
    required double jumpBase,
    required double jumpPerPoint,

    /// Jetpack thrust time: fuelSecondsPerPoint x Fuel.
    required double fuelSecondsPerPoint,
    required double gravity,

    /// Helper mode slows the whole run, so every jump keeps the same shape
    /// and timed gates give the same result (HLP-04, SRS 4.7).
    required double helperTimeScale,
    required double fallRespawnSeconds,
    required double bumpRespawnSeconds,

    /// How far below ground a falling robot goes before it counts as a fall.
    required double fallDepth,
    required double robotHalfWidth,
    required double robotHeight,
    required double boltRadius,

    /// A tap this long before landing still jumps.
    required double jumpBufferSeconds,

    /// A tap this long after walking off an edge still jumps.
    required double coyoteSeconds,

    /// Weight that presses heavy switches (SRS 4.3).
    required int switchWeight,

    /// Heaviest robot that crosses mud without sinking (SRS 4.3).
    required int mudMaxWeight,

    /// Jetpack upward acceleration while held, and its top climb speed.
    required double jetpackThrust,
    required double jetpackMaxRise,

    /// Upward launch speed off a ramp per px/s of forward speed.
    required double rampLaunchPerSpeed,

    /// Fan arms blow a leaf pile away from this far.
    required double fanRange,

    /// Autopilot (Helper mode and the solver): hover height over gaps, how
    /// far ahead it looks for leaf piles, and the gaps it keeps from leaves
    /// and ceilings.
    required double hoverHeight,
    required double flightLookahead,
    required double leafClearance,
    required double ceilingMargin,
  }) = _SimTuning;

  factory SimTuning.fromJson(Map<String, dynamic> json) =>
      _$SimTuningFromJson(json);
}
