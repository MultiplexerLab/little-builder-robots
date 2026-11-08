import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/router.dart';
import 'package:little_builder_robots/core/utils/play_clock.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/features/grown_ups/rest_screen.dart';
import 'package:little_builder_robots/features/home/home_screen.dart';
import 'package:little_builder_robots/features/home/splash_screen.dart';
import 'package:little_builder_robots/features/onboarding/first_run_screen.dart';

import '../helpers/app_harness.dart';

void main() {
  testWidgets('HOM-01: splash has no buttons and goes Home within 2 s', (
    tester,
  ) async {
    await pumpApp(tester, location: '/');
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(GestureDetector), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('ONB-01: the first launch goes to First-run setup', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: '/',
      store: seededStore(settings: const Settings()),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byType(FirstRunScreen), findsOneWidget);
  });

  for (final route in AppRoute.values) {
    testWidgets('${route.path} builds without overflow', (tester) async {
      await pumpApp(tester, location: route.path);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('HOM-06: child screens have a Home button', (tester) async {
    const childRoutes = [
      AppRoute.workshop,
      AppRoute.courseMap,
      AppRoute.stickerBook,
    ];
    for (final route in childRoutes) {
      await pumpApp(tester, location: route.path);
      expect(find.byType(HomeButton), findsOneWidget, reason: route.path);
    }
  });

  testWidgets('Home button returns to Home', (tester) async {
    await pumpApp(tester, location: AppRoute.workshop.path);
    await tapNav(tester, find.byType(HomeButton));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('PAR-03: Grown-ups without the gate goes Home', (tester) async {
    await pumpApp(tester, location: AppRoute.grownUps.path);
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('PAR-07: with the limit used up, child screens go to rest', (
    tester,
  ) async {
    final profile = testData.courses.isEmpty
        ? null
        : seededStore().values; // keep analyzer quiet about unused
    expect(profile, isNotNull);
    final container = await pumpApp(
      tester,
      store: seededStore(
        settings: const Settings(onboardingDone: true, dailyLimitMinutes: 15),
      ),
    );
    container
        .read(progressProvider.notifier)
        .addPlaySeconds(dayKey(DateTime.now()), 15 * 60);
    await tester.pump();
    await tester.pump();
    expect(find.byType(RestScreen), findsOneWidget);
  });
}
