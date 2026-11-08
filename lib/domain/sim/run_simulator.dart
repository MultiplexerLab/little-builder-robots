import 'dart:math';

import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/run_outcome.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/models/sim_tuning.dart';
import 'package:little_builder_robots/domain/models/stats.dart';
import 'package:little_builder_robots/domain/sim/input_event.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';
import 'package:little_builder_robots/domain/sim/terrain.dart';

/// The obstacle run as pure Dart (SRS 4.3, 4.4, 7). It steps at a fixed rate
/// with no randomness, so the same build and the same taps always give the
/// same result (SRS 4.7). Flame calls [step] stepsPerSecond times a second
/// and draws [state]; the solver test runs it headless.
class RunSimulator {
  RunSimulator({
    required this.course,
    required Stats stats,
    required this.tuning,
    this.playStyle = PlayStyle.big,
    bool autopilot = false,
    this.waitAtFirstGap = false,
    int startCheckpoint = 0,
  }) : terrain = Terrain.fromCourse(course),
       autopilot = autopilot || playStyle == PlayStyle.little {
    _applyStats(stats);
    _checkpoint = startCheckpoint;
    if (course.checkpoints[startCheckpoint].pitStop) {
      _pitStopsUsed.add(startCheckpoint);
    }
    _respawn();
  }

  static const double _epsilon = 1e-6;

  final Course course;
  final SimTuning tuning;
  final PlayStyle playStyle;
  final Terrain terrain;

  /// The robot jumps and flies by itself: always in Helper mode (HLP-02,
  /// HLP-03), and in the solver test.
  final bool autopilot;

  /// Tutorial (ONB-02): stop at the first gap until the child taps.
  final bool waitAtFirstGap;

  late Stats _stats;
  late double _speed;
  late double _climbPx;
  late double _jumpVelocity;
  late double _fuelMax;

  int _tick = 0;
  double _elapsed = 0;
  double _x = 0;
  double _y = 0;
  double _vy = 0;
  bool _onGround = true;
  RunPhase _phase = RunPhase.running;
  double _waitLeft = 0;
  int _checkpoint = 0;
  final Set<int> _pitStopsUsed = {};
  final Set<int> _collected = {};
  final Map<int, double> _gateOpenUntil = {};
  final Set<int> _doorsOpen = {};
  final Set<int> _leavesCleared = {};
  int _falls = 0;
  int _bumps = 0;
  bool _pressQueued = false;
  bool _holding = false;
  double _jumpBuffer = 0;
  double _coyote = 0;
  double _fuel = 0;
  bool _thrusting = false;
  bool _thrustBlocked = false;
  bool _wasOnBar = false;
  bool _tutorialDone = false;
  bool _waiting = false;

  bool get _helper => playStyle == PlayStyle.little;

  /// Game seconds per step. Helper mode slows the whole run (HLP-04).
  double get _dt =>
      (_helper ? tuning.helperTimeScale : 1) / tuning.stepsPerSecond;

  double get _halfWidth => tuning.robotHalfWidth;
  bool get _grab => _stats.has(Ability.grab);
  double get _left => _x - _halfWidth;
  double get _right => _x + _halfWidth;

  RunPhase get phase => _phase;
  Stats get stats => _stats;

  RunState get state => RunState(
    tick: _tick,
    elapsedSeconds: _elapsed,
    x: _x,
    y: _y,
    vy: _vy,
    onGround: _onGround,
    phase: _phase,
    checkpointIndex: _checkpoint,
    collectedBolts: Set.unmodifiable(_collected),
    openGates: {
      for (final MapEntry(key: i, value: until) in _gateOpenUntil.entries)
        if (until > _elapsed) i: until - _elapsed,
    },
    openDoors: Set.unmodifiable(_doorsOpen),
    clearedLeaves: Set.unmodifiable(_leavesCleared),
    falls: _falls,
    bumps: _bumps,
    atGapEdge: atGapEdge,
    fuel: _fuel,
    fuelMax: _fuelMax,
    thrusting: _thrusting,
    onBar: _onGround && _grab && terrain.onBar(_left, _right),
    waitingForTap: _waiting,
  );

  RunOutcome get outcome => RunOutcome(
    finished: _phase == RunPhase.finished,
    boltsCollected: _collected.length,
    boltsOnCourse: course.bolts.length,
    falls: _falls,
  );

  /// A press starts a jump on the next step; holding keeps the Jetpack on
  /// (RUN-02). In Helper mode a press is only a happy hop (HLP-05).
  void input(InputEvent event) {
    switch (event) {
      case InputEvent.press:
        _pressQueued = true;
        _holding = true;
      case InputEvent.release:
        _holding = false;
    }
  }

  /// Continues from a pit stop with the swapped parts' stats (RUN-11).
  void resumeFromPitStop(Stats stats) {
    if (_phase != RunPhase.parked) {
      throw StateError('Not parked at a pit stop');
    }
    _applyStats(stats);
    _fuel = _fuelMax;
    _phase = RunPhase.running;
  }

  /// RUN-13 step 3: back to a pit stop the robot has passed, parked there
  /// so the child can swap parts.
  void returnToPitStop(int checkpointIndex) {
    if (!course.checkpoints[checkpointIndex].pitStop ||
        checkpointIndex > _checkpoint) {
      throw StateError('No pit stop $checkpointIndex behind the robot');
    }
    _checkpoint = checkpointIndex;
    _respawn();
    _phase = RunPhase.parked;
  }

  /// The nearest pit stop at or behind the robot, if any.
  int? get pitStopBehind {
    for (var i = _checkpoint; i >= 0; i--) {
      if (course.checkpoints[i].pitStop) return i;
    }
    return null;
  }

  /// Advances one fixed step and returns what happened.
  List<RunEvent> step() {
    final events = <RunEvent>[];
    final pressed = _pressQueued;
    _pressQueued = false;
    _tick++;
    final dt = _dt;

    switch (_phase) {
      case RunPhase.parked || RunPhase.finished:
        return events;
      case RunPhase.bumped || RunPhase.fallen:
        _waitLeft -= dt;
        if (_waitLeft <= 0) {
          _respawn();
          events.add(RunEvent.respawned(_checkpoint));
        }
        return events;
      case RunPhase.running:
        break;
    }

    // Tutorial: wait at the first gap for the child's tap (ONB-02).
    if (waitAtFirstGap && !_tutorialDone && !autopilot && atGapEdge) {
      if (!pressed) {
        _waiting = true;
        return events;
      }
      _tutorialDone = true;
    }
    _waiting = false;
    _elapsed += dt;

    var hold = _holding;
    if (pressed) {
      if (_helper) {
        events.add(const RunEvent.happyHop());
      } else {
        _jumpBuffer = tuning.jumpBufferSeconds;
      }
    }
    if (autopilot) {
      final pilot = _pilot();
      if (pilot.jump) _jumpBuffer = tuning.jumpBufferSeconds;
      hold = pilot.hold;
    }

    if (_jumpBuffer > 0 && (_onGround || _coyote > 0)) {
      _vy = _jumpVelocity;
      _launchOffRamp(events);
      _onGround = false;
      _jumpBuffer = 0;
      _coyote = 0;
      events.add(const RunEvent.jumped());
    }

    final thrust =
        hold &&
        !_onGround &&
        _stats.has(Ability.jetpack) &&
        _fuel > 0 &&
        !_thrustBlocked;
    if (thrust && !_thrusting) events.add(const RunEvent.jetpackOn());
    _thrusting = thrust;
    if (thrust) _fuel = max(0, _fuel - dt);

    if (!_moveForward(dt, events)) return events;
    _pressPlates(events);
    _blowLeaves(events);
    _moveVertically(dt, events);
    if (_phase != RunPhase.running) return events;
    if (_sinkInMud(events)) return events;

    final onBar = _onGround && _grab && terrain.onBar(_left, _right);
    if (onBar && !_wasOnBar) {
      events.add(RunEvent.swung(_obstacleAt(_x) ?? -1));
    }
    _wasOnBar = onBar;

    _collectBolts(events);
    _reachCheckpoints(events);
    if (_phase == RunPhase.running && _x >= course.lengthPx) {
      _phase = RunPhase.finished;
      events.add(const RunEvent.finished());
    }
    _jumpBuffer = max(0, _jumpBuffer - dt);
    _coyote = max(0, _coyote - dt);
    return events;
  }

  /// Ground under the robot, including the tops of leaf piles.
  double? _support() {
    var support = terrain.supportUnder(_left, _right, grab: _grab);
    for (final (i, obstacle) in course.obstacles.indexed) {
      if (obstacle is LeafPileObstacle &&
          !_leavesCleared.contains(i) &&
          obstacle.x < _right &&
          obstacle.end > _left &&
          (support == null || obstacle.height > support)) {
        support = obstacle.height;
      }
    }
    return support;
  }

  /// Moves right, climbing steps it can and bumping into ones it can't, and
  /// into closed gates, shut doors and leaf piles. Returns false after a
  /// bump.
  bool _moveForward(double dt, List<RunEvent> events) {
    final front = _right;
    var newX = _x + _speed * dt;
    final newFront = newX + _halfWidth;

    final edge = terrain.risingEdge(front, newFront, _y, airborne: !_onGround);
    final wall = _wallBetween(front, newFront);

    if (edge != null && (wall == null || edge.x <= wall)) {
      if (_onGround && edge.height - _y <= _climbPx + _epsilon) {
        _y = edge.height; // SRS 4.1: climb a step no taller than Climb allows
      } else if (_support() == null) {
        // Falling in a gap: slide down its far wall.
        newX = edge.x - _halfWidth - _epsilon;
      } else {
        // Too tall, or jumped into a step face (SRS 4.3).
        _x = edge.x - _halfWidth - _epsilon;
        _fail(RunPhase.bumped, events);
        return false;
      }
    } else if (wall != null) {
      _x = wall - _halfWidth - _epsilon;
      _fail(RunPhase.bumped, events);
      return false;
    }
    _x = newX;
    return true;
  }

  /// The nearest closed gate, shut door or standing leaf pile the front
  /// crosses in (fromX, toX].
  double? _wallBetween(double fromX, double toX) {
    double? nearest;
    for (final (i, obstacle) in course.obstacles.indexed) {
      final x = switch (obstacle) {
        TimedGateObstacle(:final x)
            when !((_gateOpenUntil[i] ?? double.negativeInfinity) > _elapsed) =>
          x,
        HeavySwitchObstacle(:final x) when !_doorsOpen.contains(i) => x,
        LeafPileObstacle(:final x, :final height)
            when !_leavesCleared.contains(i) && _y < height - _epsilon =>
          x,
        _ => null,
      };
      if (x != null &&
          x > fromX &&
          x <= toX &&
          (nearest == null || x < nearest)) {
        nearest = x;
      }
    }
    return nearest;
  }

  void _pressPlates(List<RunEvent> events) {
    for (final (i, obstacle) in course.obstacles.indexed) {
      switch (obstacle) {
        case TimedGateObstacle(:final plateX, :final openSeconds)
            when _x >= plateX && !_gateOpenUntil.containsKey(i):
          _gateOpenUntil[i] = _elapsed + openSeconds;
          events.add(RunEvent.gateOpened(i));
        // Only a heavy robot standing on the plate presses it (SRS 4.3).
        case HeavySwitchObstacle(:final plateX)
            when _onGround &&
                _x >= plateX &&
                _x - plateX <= 2 * _halfWidth &&
                _stats.weight >= tuning.switchWeight &&
                !_doorsOpen.contains(i):
          _doorsOpen.add(i);
          events.add(RunEvent.switchPressed(i));
        default:
          break;
      }
    }
  }

  void _blowLeaves(List<RunEvent> events) {
    if (!_stats.has(Ability.fan)) return;
    for (final (i, obstacle) in course.obstacles.indexed) {
      if (obstacle is LeafPileObstacle &&
          obstacle.x - _right <= tuning.fanRange &&
          obstacle.end > _left &&
          _leavesCleared.add(i)) {
        events.add(RunEvent.leavesBlown(i));
      }
    }
  }

  void _moveVertically(double dt, List<RunEvent> events) {
    final support = _support();
    if (_onGround) {
      if (support == null || support < _y - _epsilon) {
        _onGround = false;
        _vy = 0;
        _coyote = tuning.coyoteSeconds;
        _launchOffRamp(events);
      } else {
        _y = support;
        return;
      }
    }
    final previousY = _y;
    final accel = _thrusting
        ? tuning.jetpackThrust - tuning.gravity
        : -tuning.gravity;
    var newVy = _vy + accel * dt;
    if (_thrusting) newVy = min(newVy, max(_vy, tuning.jetpackMaxRise));
    // Exact for constant acceleration, so jumps reach 60 + 30 x Jump px.
    _y += (_vy + newVy) / 2 * dt;
    _vy = newVy;

    final ceiling = _ceilingOver(_left, _right);
    if (ceiling != null && _y + tuning.robotHeight > ceiling) {
      // Hitting the ceiling ends thrust until landing (SRS 4.3).
      _y = ceiling - tuning.robotHeight;
      if (_vy > 0) _vy = 0;
      if (!_thrustBlocked) events.add(const RunEvent.ceilingBonk());
      _thrustBlocked = true;
      _thrusting = false;
    }

    if (support != null &&
        _vy <= 0 &&
        previousY >= support - _epsilon &&
        _y <= support) {
      _y = support;
      _vy = 0;
      _onGround = true;
      _fuel = _fuelMax; // refilled on landing (SRS 4.1)
      _thrustBlocked = false;
      _thrusting = false;
      events.add(const RunEvent.landed());
    } else if (_y < -tuning.fallDepth) {
      _fail(RunPhase.fallen, events);
    }
  }

  double? _ceilingOver(double left, double right) {
    double? lowest;
    for (final obstacle in course.obstacles) {
      if (obstacle is LowCeilingObstacle &&
          obstacle.x < right &&
          obstacle.end > left &&
          (lowest == null || obstacle.height < lowest)) {
        lowest = obstacle.height;
      }
    }
    return lowest;
  }

  /// Leaving a ramp's lip throws the robot up in proportion to its speed.
  void _launchOffRamp(List<RunEvent> events) {
    for (final (i, obstacle) in course.obstacles.indexed) {
      if (obstacle is RampObstacle &&
          _x >= obstacle.end - _halfWidth &&
          _x <= obstacle.end + 2 * _halfWidth) {
        _vy = max(_vy, tuning.rampLaunchPerSpeed * _speed);
        events.add(RunEvent.rampLaunch(i));
        return;
      }
    }
  }

  /// A heavy robot that is not mudproof sinks (SRS 4.3): a bump failure.
  bool _sinkInMud(List<RunEvent> events) {
    if (!_onGround ||
        _stats.weight <= tuning.mudMaxWeight ||
        _stats.has(Ability.mudproof)) {
      return false;
    }
    for (final obstacle in course.obstacles) {
      if (obstacle is MudObstacle &&
          _x >= obstacle.x + _halfWidth &&
          _x <= obstacle.end) {
        _fail(RunPhase.bumped, events);
        return true;
      }
    }
    return false;
  }

  void _collectBolts(List<RunEvent> events) {
    final reach = _halfWidth + tuning.boltRadius;
    for (final (i, bolt) in course.bolts.indexed) {
      if (!_collected.contains(i) &&
          (bolt.x - _x).abs() <= reach &&
          bolt.y >= _y - tuning.boltRadius &&
          bolt.y <= _y + tuning.robotHeight + tuning.boltRadius) {
        _collected.add(i);
        events.add(RunEvent.boltCollected(i));
      }
    }
  }

  void _reachCheckpoints(List<RunEvent> events) {
    final checkpoints = course.checkpoints;
    while (_checkpoint + 1 < checkpoints.length &&
        checkpoints[_checkpoint + 1].x <= _x) {
      _checkpoint++;
      events.add(RunEvent.checkpointReached(_checkpoint));
      if (checkpoints[_checkpoint].pitStop && _pitStopsUsed.add(_checkpoint)) {
        _x = checkpoints[_checkpoint].x;
        _phase = RunPhase.parked;
        events.add(RunEvent.parked(_checkpoint));
        return;
      }
    }
  }

  void _fail(RunPhase phase, List<RunEvent> events) {
    _phase = phase;
    _thrusting = false;
    final obstacle = _obstacleAt(_x);
    if (phase == RunPhase.fallen) {
      _falls++;
      _waitLeft = tuning.fallRespawnSeconds;
      events.add(RunEvent.fell(obstacle));
    } else {
      _bumps++;
      _waitLeft = tuning.bumpRespawnSeconds;
      events.add(RunEvent.bumped(obstacle));
    }
  }

  /// The obstacle a failure at [x] counts against. A low ceiling only
  /// counts when nothing else is there.
  int? _obstacleAt(double x) {
    int? ceiling;
    for (final (i, obstacle) in course.obstacles.indexed) {
      // 1 px of slack: a bump stops the robot just short of the face.
      if (x + _halfWidth + 1 >= obstacle.start &&
          x - _halfWidth <= obstacle.end + 1) {
        if (obstacle is! LowCeilingObstacle) return i;
        ceiling ??= i;
      }
    }
    return ceiling;
  }

  /// Back to the last checkpoint on the ground, with gates, doors and leaves
  /// reset (SRS 4.4). Collected bolts stay collected.
  void _respawn() {
    _x = course.checkpoints[_checkpoint].x;
    _y = terrain.supportUnder(_left, _right) ?? 0;
    _vy = 0;
    _onGround = true;
    _phase = RunPhase.running;
    _gateOpenUntil.clear();
    _doorsOpen.clear();
    _leavesCleared.clear();
    _jumpBuffer = 0;
    _coyote = 0;
    _fuel = _fuelMax;
    _thrusting = false;
    _thrustBlocked = false;
    _holding = false;
  }

  /// On the ground with a gap one step ahead. A bar gap is not a gap for a
  /// robot that can grab.
  bool get atGapEdge {
    if (!_onGround || _phase != RunPhase.running) return false;
    final next = _x + _speed * _dt;
    return terrain.supportUnder(
          next - _halfWidth,
          next + _halfWidth,
          grab: _grab,
        ) ==
        null;
  }

  /// What a perfect player does (Helper mode and the solver): jump at the
  /// last moment before a gap; with a Jetpack, hover over gaps, climb over
  /// leaf piles and stay under ceilings.
  ({bool jump, bool hold}) _pilot() {
    var jump = atGapEdge;
    if (!_stats.has(Ability.jetpack)) return (jump: jump, hold: false);

    var target = 0.0;
    if (jump || terrain.hasHole(_left, _right, grab: _grab)) {
      target = tuning.hoverHeight;
    }
    if (!_stats.has(Ability.fan)) {
      for (final (i, obstacle) in course.obstacles.indexed) {
        if (obstacle is LeafPileObstacle &&
            !_leavesCleared.contains(i) &&
            obstacle.x <= _right + tuning.flightLookahead &&
            obstacle.end >= _left) {
          target = max(target, obstacle.height + tuning.leafClearance);
        }
      }
    }
    final ceiling = _ceilingOver(_left, _right + 2 * _halfWidth);
    if (ceiling != null) {
      target = min(
        target,
        ceiling - tuning.robotHeight - tuning.ceilingMargin,
      );
    }
    if (target > _y + _epsilon && _onGround) jump = true;
    if (target <= 0) return (jump: jump, hold: false);
    // Thrust while the peak if we stopped now (rising), or the lowest point
    // if we thrust now (falling), is below the target: a fast climb with no
    // overshoot and no dip.
    final g = tuning.gravity;
    final reach = _vy >= 0
        ? _y + _vy * _vy / (2 * g)
        : _y - _vy * _vy / (2 * (tuning.jetpackThrust - g));
    return (jump: jump, hold: reach < target);
  }

  /// SRS 4.1: speed, climb, jump and fuel from stats.
  void _applyStats(Stats stats) {
    _stats = stats;
    _speed = tuning.speedBase + tuning.speedPerPoint * stats.speed;
    _climbPx = tuning.climbPerPoint * stats.climb;
    final jumpHeight = tuning.jumpBase + tuning.jumpPerPoint * stats.jump;
    _jumpVelocity = sqrt(2 * tuning.gravity * jumpHeight);
    _fuelMax = stats.has(Ability.jetpack)
        ? tuning.fuelSecondsPerPoint * stats.fuel
        : 0;
  }
}
