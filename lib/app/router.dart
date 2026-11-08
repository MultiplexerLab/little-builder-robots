import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/services.dart';
import 'package:little_builder_robots/features/course_map/course_map_screen.dart';
import 'package:little_builder_robots/features/grown_ups/rest_screen.dart';
import 'package:little_builder_robots/features/grown_ups/settings_screen.dart';
import 'package:little_builder_robots/features/home/home_screen.dart';
import 'package:little_builder_robots/features/home/splash_screen.dart';
import 'package:little_builder_robots/features/onboarding/first_run_screen.dart';
import 'package:little_builder_robots/features/parent_gate/parent_gate_screen.dart';
import 'package:little_builder_robots/features/result/result_screen.dart';
import 'package:little_builder_robots/features/run/run_screen.dart';
import 'package:little_builder_robots/features/stickers/sticker_book_screen.dart';
import 'package:little_builder_robots/features/test_track/test_track_screen.dart';
import 'package:little_builder_robots/features/workshop/workshop_screen.dart';

/// Every route in the app (SRS section 3.0).
enum AppRoute {
  splash('/'),
  firstRun('/first-run'),
  home('/home'),
  workshop('/workshop'),
  courseMap('/map'),
  run('/run'),
  result('/result'),
  testTrack('/test-track'),
  stickerBook('/stickers'),
  parentGate('/gate'),
  grownUps('/grown-ups'),
  rest('/rest')
  ;

  const AppRoute(this.path);

  final String path;
}

Widget _screenFor(AppRoute route) => switch (route) {
  AppRoute.splash => const SplashScreen(),
  AppRoute.firstRun => const FirstRunScreen(),
  AppRoute.home => const HomeScreen(),
  AppRoute.workshop => const WorkshopScreen(),
  AppRoute.courseMap => const CourseMapScreen(),
  AppRoute.run => const RunScreen(),
  AppRoute.result => const ResultScreen(),
  AppRoute.testTrack => const TestTrackScreen(),
  AppRoute.stickerBook => const StickerBookScreen(),
  AppRoute.parentGate => const ParentGateScreen(),
  AppRoute.grownUps => const SettingsScreen(),
  AppRoute.rest => const RestScreen(),
};

/// Routes the daily limit never interrupts: a run finishes first (PAR-11),
/// and grown-ups can always get in.
const Set<AppRoute> _limitFree = {
  AppRoute.splash,
  AppRoute.firstRun,
  AppRoute.run,
  AppRoute.result,
  AppRoute.parentGate,
  AppRoute.grownUps,
  AppRoute.rest,
};

GoRouter buildRouter({
  String initialLocation = '/',
  bool Function()? gatePassed,
  bool Function()? limitReached,
  Listenable? refresh,
}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: refresh,
  redirect: (context, state) {
    final location = state.matchedLocation;
    // PAR-03: the Parent gate guards the Grown-ups area.
    if (location == AppRoute.grownUps.path && !(gatePassed?.call() ?? false)) {
      return AppRoute.home.path;
    }
    // PAR-07: once today's time is up, child screens go to rest.
    final reached = limitReached?.call() ?? false;
    final free = _limitFree.any((r) => r.path == location);
    if (reached && !free) return AppRoute.rest.path;
    return null;
  },
  routes: [
    for (final route in AppRoute.values)
      GoRoute(
        path: route.path,
        name: route.name,
        builder: (context, state) => _screenFor(route),
      ),
  ],
);

/// The app router wired to the gate and play-time state. Tests pass an
/// [initialLocation].
GoRouter createRouter(Ref ref, {String initialLocation = '/'}) {
  final refresh = ValueNotifier(0);
  ref
    ..listen(gatePassedProvider, (_, _) => refresh.value++)
    ..listen(playLimitProvider, (_, _) => refresh.value++);
  final router = buildRouter(
    initialLocation: initialLocation,
    gatePassed: () => ref.read(gatePassedProvider),
    limitReached: () => ref.read(playLimitProvider).reached,
    refresh: refresh,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
}

final routerProvider = Provider<GoRouter>(createRouter);
