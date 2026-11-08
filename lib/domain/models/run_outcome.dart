import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_outcome.freezed.dart';

/// What happened in one course run, as reported by the RunSimulator.
@freezed
abstract class RunOutcome with _$RunOutcome {
  const factory RunOutcome({
    required bool finished,
    required int boltsCollected,
    required int boltsOnCourse,

    /// Falls into gaps or water. Bumps are not counted (RES-02, SRS 4.4).
    required int falls,
  }) = _RunOutcome;
}
