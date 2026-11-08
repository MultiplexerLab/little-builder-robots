import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/models/sim_tuning.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';
import 'package:little_builder_robots/domain/rules/stat_calculator.dart';
import 'package:little_builder_robots/domain/sim/input_event.dart';
import 'package:little_builder_robots/domain/sim/run_simulator.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';

/// What the hint ladder is showing (RUN-13).
class HintState {
  const HintState({
    required this.obstacleIndex,
    required this.step,
    required this.need,
    this.suggestion,
    this.suggestionOwned = true,
  });

  final int obstacleIndex;

  /// 1 shrug, 2 voiced hint, 3 "Try new parts?" bubble.
  final int step;
  final ObstacleNeed need;
  final Part? suggestion;
  final bool suggestionOwned;
}

/// Runs one obstacle run for the screen: steps the simulator at its fixed
/// rate from the frame clock (SRS 7), and handles pause, pit stops (RUN-11),
/// the hint ladder (RUN-13), the course preview (RUN-14) and the tutorial
/// wait (ONB-02). Flame only draws [state].
class RunController extends ChangeNotifier {
  RunController({
    required this.course,
    required RobotConfig robot,
    required this.calculator,
    required this.coach,
    required this.tuning,
    required this.playStyle,
    required this.owned,
    this.onEvent,
    this.preview = false,
    this.tutorial = false,
    this.loop = false,
  }) : _robot = robot {
    _sim = _newSim();
    _state = _previous = _sim.state;
  }

  final Course course;
  final StatCalculator calculator;
  final ObstacleCoach coach;
  final SimTuning tuning;
  final PlayStyle playStyle;

  /// Parts the child owns, for pit stops and hint suggestions.
  final Set<String> owned;

  /// Sounds, haptics and the finish hand-off.
  final void Function(RunEvent event)? onEvent;

  /// RUN-14: pan across the course first (first play only).
  final bool preview;

  /// ONB-02: wait at the first gap for a tap (Big Builder).
  final bool tutorial;

  /// Test Track: start a new lap at the flag (TRK-02).
  final bool loop;

  /// RUN-14: at most 4 s.
  static const previewSeconds = 3.5;

  /// RUN-13 step 1: how long the shrug lasts.
  static const shrugSeconds = 1.2;

  RobotConfig _robot;
  late RunSimulator _sim;
  late RunState _state;
  late RunState _previous;
  double _accumulator = 0;
  bool _paused = false;
  double _previewLeft = 0;
  double _shrugLeft = 0;
  final Map<int, int> _failures = {};
  HintState? _hint;
  final List<RunEvent> _events = [];
  int _laps = 0;
  bool _swappedAtPitStop = false;

  /// The robot as it is now: pit stop swaps change this, never the saved
  /// RobotConfig (RUN-11).
  RobotConfig get robot => _robot;
  RunState get state => _state;
  RunState get previous => _previous;

  /// How far between the last two steps the frame is, for smooth drawing.
  double get alpha => _accumulator * tuning.stepsPerSecond;
  bool get paused => _paused;
  bool get previewing => _previewLeft > 0;

  /// 0 to 1 through the preview pan.
  double get previewProgress => 1 - _previewLeft / previewSeconds;
  bool get shrugging => _shrugLeft > 0;
  HintState? get hint => _hint;
  int get laps => _laps;
  bool get swappedAtPitStop => _swappedAtPitStop;

  /// Everything that happened, for stickers (STK-01).
  List<RunEvent> get events => List.unmodifiable(_events);

  RunSimulator _newSim() => RunSimulator(
    course: course,
    stats: calculator.statsFor(_robot),
    tuning: tuning,
    playStyle: playStyle,
    waitAtFirstGap: tutorial,
  );

  void startPreview() {
    if (preview) _previewLeft = previewSeconds;
  }

  void skipPreview() {
    if (_previewLeft <= 0) return;
    _previewLeft = 0;
    notifyListeners();
  }

  /// Called every frame with real seconds.
  void advance(double dt) {
    if (_paused) return;
    if (_previewLeft > 0) {
      _previewLeft = max(0, _previewLeft - dt);
      notifyListeners();
      return;
    }
    if (_shrugLeft > 0) _shrugLeft = max(0, _shrugLeft - dt);
    final step = 1 / tuning.stepsPerSecond;
    _accumulator += min(dt, 0.1); // no spiral of death after a hitch
    var changed = false;
    while (_accumulator >= step) {
      _accumulator -= step;
      _previous = _state;
      final events = _sim.step();
      _state = _sim.state;
      changed = true;
      events.forEach(_handle);
      if (_sim.phase == RunPhase.parked || _sim.phase == RunPhase.finished) {
        _accumulator = 0;
        break;
      }
    }
    if (changed) notifyListeners();
  }

  void _handle(RunEvent event) {
    _events.add(event);
    switch (event) {
      case BumpedEvent(:final obstacleIndex) || FellEvent(:final obstacleIndex):
        if (obstacleIndex != null) _climbLadder(obstacleIndex);
      case FinishedEvent() when loop:
        _laps++;
        onEvent?.call(event);
        _sim = _newSim();
        _state = _previous = _sim.state;
        return;
      default:
        break;
    }
    onEvent?.call(event);
  }

  /// RUN-13: shrug, then a voiced hint, then the "Try new parts?" bubble.
  /// Little Builder skips the shrug.
  void _climbLadder(int obstacleIndex) {
    final failures = (_failures[obstacleIndex] ?? 0) + 1;
    _failures[obstacleIndex] = failures;
    final step = min(3, failures + (playStyle == PlayStyle.little ? 1 : 0));
    final need = coach.needFor(course, obstacleIndex);
    if (step == 1) {
      _shrugLeft = shrugSeconds;
      _hint = HintState(obstacleIndex: obstacleIndex, step: 1, need: need);
      return;
    }
    if (step == 2) {
      _hint = HintState(obstacleIndex: obstacleIndex, step: 2, need: need);
      return;
    }
    final suggestion = coach.suggestPart(
      course,
      obstacleIndex,
      _robot,
      owned,
    );
    _hint = HintState(
      obstacleIndex: obstacleIndex,
      step: 3,
      need: need,
      suggestion: suggestion?.part,
      suggestionOwned: suggestion?.owned ?? true,
    );
  }

  /// Tapping elsewhere dismisses the bubble (RUN-13).
  void dismissHint() {
    if (_hint == null) return;
    _hint = null;
    notifyListeners();
  }

  void input(InputEvent event) {
    if (_previewLeft > 0) {
      skipPreview();
      return;
    }
    if (_paused) return;
    _sim.input(event);
  }

  void pause() {
    _paused = true;
    _sim.input(InputEvent.release);
    notifyListeners();
  }

  void resume() {
    _paused = false;
    _accumulator = 0;
    notifyListeners();
  }

  /// RUN-08 Restart: the same course from the start, with the build the
  /// run started with being kept by the caller.
  void restart(RobotConfig robot) {
    _robot = robot;
    _sim = _newSim();
    _state = _previous = _sim.state;
    _failures.clear();
    _events.clear();
    _hint = null;
    _paused = false;
    _accumulator = 0;
    notifyListeners();
  }

  /// RUN-11: swap a part while parked; the saved RobotConfig is untouched.
  void swapPart(Part part) {
    if (_sim.phase != RunPhase.parked || !owned.contains(part.id)) return;
    _robot = _robot.withPart(part.slot, part.id);
    _swappedAtPitStop = true;
    notifyListeners();
  }

  /// RUN-11: the large Go button.
  void leavePitStop() {
    if (_sim.phase != RunPhase.parked) return;
    _sim.resumeFromPitStop(calculator.statsFor(_robot));
    _state = _previous = _sim.state;
    _failures.clear();
    _hint = null;
    notifyListeners();
  }

  /// RUN-13 step 3: the pit stop behind the robot, if there is one.
  int? get pitStopBehind => _sim.pitStopBehind;

  void returnToPitStop() {
    final index = _sim.pitStopBehind;
    if (index == null) return;
    _sim.returnToPitStop(index);
    _state = _previous = _sim.state;
    _hint = null;
    notifyListeners();
  }

  /// The need of the first obstacle after the robot, for the pit stop
  /// panel (RUN-11).
  ObstacleNeed? get nextNeed {
    for (final (i, obstacle) in course.obstacles.indexed) {
      if (obstacle.start > _state.x) return coach.needFor(course, i);
    }
    return null;
  }

  /// The first obstacle the preview points at (RUN-14).
  double get previewTargetX => course.obstacles.isEmpty
      ? course.lengthPx / 2
      : course.obstacles.first.start;

  bool get hasJetpack => calculator
      .statsFor(_robot)
      .abilities
      .any(
        (a) => a.name == 'jetpack',
      );

  /// The outcome so far, for banking bolts when leaving early (RES-03).
  RunSimulator get sim => _sim;
}
