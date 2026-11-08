import 'package:flutter/widgets.dart';

/// Toddler input rules (NFR-19): touches while 3 or more fingers are down
/// are ignored (palm guard), and navigation buttons ignore repeat taps for
/// 400 ms.
class TouchGuard {
  TouchGuard._();

  static final instance = TouchGuard._();

  static const repeatWindow = Duration(milliseconds: 400);

  final Set<int> _pointers = {};
  DateTime _lastNavigation = DateTime.fromMillisecondsSinceEpoch(0);

  /// True while a palm (3 or more fingers) is on the screen.
  bool get palm => _pointers.length >= 3;

  /// Whether a navigation tap may go ahead now; records it if so.
  bool allowNavigation([DateTime? now]) {
    final time = now ?? DateTime.now();
    if (palm || time.difference(_lastNavigation) < repeatWindow) return false;
    _lastNavigation = time;
    return true;
  }

  /// For tests.
  void reset() {
    _pointers.clear();
    _lastNavigation = DateTime.fromMillisecondsSinceEpoch(0);
  }
}

/// Counts fingers on the screen for [TouchGuard]. Wraps the whole app.
class TouchGuardScope extends StatelessWidget {
  const TouchGuardScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (e) => TouchGuard.instance._pointers.add(e.pointer),
    onPointerUp: (e) => TouchGuard.instance._pointers.remove(e.pointer),
    onPointerCancel: (e) => TouchGuard.instance._pointers.remove(e.pointer),
    child: child,
  );
}
