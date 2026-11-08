import 'package:little_builder_robots/domain/models/course.dart';

/// Ground height along a course, built from its obstacles. The ground is a
/// row of flat segments; a segment with a null height is a hole. A hole
/// under a bar (a bar gap) holds up a robot that can grab.
class Terrain {
  Terrain._(this._starts, this._heights, this._bars);

  /// Flat ground at level 0, raised by steps and cut by gaps.
  factory Terrain.fromCourse(Course course) {
    final breaks = <(double, double?, bool)>[
      (double.negativeInfinity, 0, false),
    ];
    for (final obstacle in course.obstacles) {
      switch (obstacle) {
        case StepsObstacle(:final x, :final stepWidth, :final stepHeights):
          var level = 0.0;
          for (final (i, rise) in stepHeights.indexed) {
            level += rise;
            breaks.add((x + i * stepWidth, level, false));
          }
          breaks.add((obstacle.end, 0, false));
        case GapObstacle(:final x, :final width):
          breaks
            ..add((x, null, false))
            ..add((x + width, 0, false));
        case BarGapObstacle(:final x, :final width):
          breaks
            ..add((x, null, true))
            ..add((x + width, 0, false));
        case TimedGateObstacle() ||
            HeavySwitchObstacle() ||
            MudObstacle() ||
            LeafPileObstacle() ||
            LowCeilingObstacle() ||
            RampObstacle():
          break;
      }
    }
    // A stable sort keeps the later break when two share an x.
    final sorted = breaks.indexed.toList()
      ..sort((a, b) {
        final byX = a.$2.$1.compareTo(b.$2.$1);
        return byX != 0 ? byX : a.$1.compareTo(b.$1);
      });
    final starts = <double>[];
    final heights = <double?>[];
    final bars = <bool>[];
    for (final (_, (x, height, bar)) in sorted) {
      if (starts.isNotEmpty && starts.last == x) {
        heights.last = height;
        bars.last = bar;
      } else {
        starts.add(x);
        heights.add(height);
        bars.add(bar);
      }
    }
    return Terrain._(starts, heights, bars);
  }

  static const double _epsilon = 1e-6;

  final List<double> _starts;
  final List<double?> _heights;
  final List<bool> _bars;

  double _endOf(int i) =>
      i + 1 < _starts.length ? _starts[i + 1] : double.infinity;

  double? _heightOf(int i, {required bool grab}) =>
      _heights[i] ?? (grab && _bars[i] ? 0 : null);

  /// The highest ground under the span left..right, or null if it is all
  /// hole. With [grab], bars count as ground.
  double? supportUnder(double left, double right, {bool grab = false}) {
    double? best;
    for (var i = 0; i < _starts.length; i++) {
      if (_starts[i] >= right) break;
      final height = _heightOf(i, grab: grab);
      if (_endOf(i) > left && height != null) {
        if (best == null || height > best) best = height;
      }
    }
    return best;
  }

  /// Whether any part of left..right is over a hole.
  bool hasHole(double left, double right, {bool grab = false}) {
    for (var i = 0; i < _starts.length; i++) {
      if (_starts[i] >= right) break;
      if (_endOf(i) > left && _heightOf(i, grab: grab) == null) return true;
    }
    return false;
  }

  /// Whether left..right is over a bar the robot hangs from.
  bool onBar(double left, double right) {
    for (var i = 0; i < _starts.length; i++) {
      if (_starts[i] >= right) break;
      if (_endOf(i) > left && _bars[i]) return true;
    }
    return false;
  }

  /// The first edge in (fromX, toX] the robot runs into: ground higher than
  /// [y] (a step face or the far wall of a gap), or with [airborne] any step
  /// face, because steps can't be jumped onto (SRS 4.3).
  ({double x, double height})? risingEdge(
    double fromX,
    double toX,
    double y, {
    bool airborne = false,
  }) {
    for (var i = 1; i < _starts.length; i++) {
      final x = _starts[i];
      if (x > toX) break;
      final height = _heights[i];
      if (x <= fromX || height == null) continue;
      final below = _heights[i - 1];
      final stepFace = below != null && height > below + _epsilon;
      if (height > y + _epsilon || (airborne && stepFace)) {
        return (x: x, height: height);
      }
    }
    return null;
  }

  /// Flat segments for drawing: start, end and height (null for a hole) and
  /// whether a bar spans it.
  Iterable<({double start, double end, double? height, bool bar})>
  get segments sync* {
    for (var i = 0; i < _starts.length; i++) {
      yield (
        start: _starts[i],
        end: _endOf(i),
        height: _heights[i],
        bar: _bars[i],
      );
    }
  }
}
