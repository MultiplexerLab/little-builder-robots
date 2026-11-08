import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/router.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/widgets/chunky_button.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/domain/models/run_outcome.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/rules/unlock_rules.dart';
import 'package:little_builder_robots/features/grown_ups/settings_screen.dart';
import 'package:little_builder_robots/features/home/home_screen.dart';
import 'package:little_builder_robots/features/parent_gate/parent_gate_screen.dart';
import 'package:little_builder_robots/features/result/result_screen.dart';
import 'package:little_builder_robots/features/run/run_screen.dart';
import 'package:little_builder_robots/features/workshop/part_tile.dart';
import 'package:little_builder_robots/features/workshop/workshop_screen.dart';

import '../helpers/app_harness.dart';

void main() {
  final rules = UnlockRules(
    catalog: testData.catalog,
    courses: testData.courses,
    decals: testData.decals,
  );

  group('First run and Home (ONB-01, HOM-02 to HOM-04)', () {
    testWidgets('choosing Little Builder stores only the play style', (
      tester,
    ) async {
      final c = await pumpApp(
        tester,
        location: AppRoute.firstRun.path,
        store: seededStore(settings: const Settings()),
      );
      await tapNav(tester, find.text('Little Builder'));
      await tester.pump(const Duration(milliseconds: 300));
      final settings = c.read(settingsProvider);
      expect(settings.playStyle, PlayStyle.little);
      expect(settings.onboardingDone, isTrue);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Play opens the Workshop on the next course (HOM-03)', (
      tester,
    ) async {
      final c = await pumpApp(tester);
      await tapNav(tester, find.text('Play'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(WorkshopScreen), findsOneWidget);
      expect(c.read(selectedCourseProvider), 'w1_c01');
    });

    testWidgets('Test Track shows a padlock until course 3 (TRK-01)', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('the gear opens the Parent gate (HOM-04, PAR-03)', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapNav(tester, find.byIcon(Icons.settings_outlined));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ParentGateScreen), findsOneWidget);
    });

    testWidgets('Play is a primary button at least 96 pt tall (DES-03)', (
      tester,
    ) async {
      await pumpApp(tester);
      final play = find.ancestor(
        of: find.text('Play'),
        matching: find.byType(ChunkyButton),
      );
      expect(tester.getSize(play).height, greaterThanOrEqualTo(96));
    });
  });

  group('Workshop (WRK-02 to WRK-05, WRK-11)', () {
    testWidgets('tiles are at least 96 pt (WRK-02)', (tester) async {
      await pumpApp(tester, location: AppRoute.workshop.path);
      final tiles = find.byType(PickerTile);
      expect(tiles, findsWidgets);
      for (final e in tiles.evaluate()) {
        final size = tester.getSize(find.byWidget(e.widget));
        expect(size.shortestSide, greaterThanOrEqualTo(AppSizes.partTile));
      }
    });

    testWidgets('tapping an owned part equips and saves it (WRK-03)', (
      tester,
    ) async {
      final c = await pumpApp(tester, location: AppRoute.workshop.path);
      await tester.tap(find.bySemanticsLabel('Legs'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.read(profileProvider).robot.movesId, 'moves_legs');
      final saved = c.read(progressRepositoryProvider).load().progress;
      expect(saved.profile.robot.movesId, 'moves_legs');
    });

    testWidgets('a locked part without bolts changes nothing (WRK-11)', (
      tester,
    ) async {
      final c = await pumpApp(tester, location: AppRoute.workshop.path);
      await tester.tap(find.bySemanticsLabel('Tank tracks'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.read(profileProvider).robot.movesId, 'moves_wheels');
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('with enough bolts: confirm, tick, unlocked (WRK-05)', (
      tester,
    ) async {
      final c = await pumpApp(
        tester,
        location: AppRoute.workshop.path,
        store: seededStore(profile: rules.newProfile().copyWith(bolts: 50)),
      );
      await tester.tap(find.bySemanticsLabel('Tank tracks'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(Dialog), findsOneWidget);
      // Wheels to Tank tracks: Speed down, Climb and Weight up (SRS 11).
      expect(find.byIcon(Icons.arrow_downward_rounded), findsWidgets);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsWidgets);
      await tapNav(tester, find.byIcon(Icons.check_rounded));
      await tester.pump(const Duration(milliseconds: 400));
      final profile = c.read(profileProvider);
      expect(profile.bolts, 10);
      expect(profile.robot.movesId, 'moves_tank_tracks');
    });
  });

  group('Parent gate and Grown-ups (PAR-01 to PAR-04)', () {
    testWidgets('a correct answer opens Grown-ups', (tester) async {
      final c = await pumpApp(tester);
      await tapNav(tester, find.byIcon(Icons.settings_outlined));
      await tester.pump(const Duration(milliseconds: 300));
      final question = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((t) => t.startsWith('What is'));
      const words = {
        'three': 3, 'four': 4, 'five': 5, 'six': 6, //
        'seven': 7, 'eight': 8, 'nine': 9,
      };
      final parts = question.replaceAll('?', '').split(' ');
      final answer = words[parts[2]]! * words[parts[5]]!;
      for (final d in '$answer'.split('')) {
        await tester.tap(find.bySemanticsLabel(d));
        await tester.pump();
      }
      await tester.tap(find.bySemanticsLabel('Done'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.read(gatePassedProvider), isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        find.text(
          'No data leaves this device. There are no ads, '
          'no accounts and no tracking.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a wrong answer shows a new question (PAR-02)', (
      tester,
    ) async {
      await pumpApp(tester, location: AppRoute.parentGate.path);
      await tester.tap(find.bySemanticsLabel('1'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Done'));
      await tester.pump();
      expect(find.text('Not quite. Here is a new question.'), findsOneWidget);
    });
  });

  group('Run and Result', () {
    testWidgets('Pause offers Resume, Restart and Workshop (RUN-08)', (
      tester,
    ) async {
      await pumpApp(tester, location: AppRoute.run.path);
      await tester.pump(const Duration(milliseconds: 100));
      await tapNav(tester, find.bySemanticsLabel('Pause'));
      await tester.pump();
      for (final label in ['Keep going', 'Start again', 'Workshop', 'Home']) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('the jump zone is the right 40% (RUN-15)', (tester) async {
      await pumpApp(tester, location: AppRoute.run.path);
      // Skip the course preview.
      await tester.tapAt(const Offset(400, 200));
      await tester.pump(const Duration(milliseconds: 100));
      final zone = tester.getRect(find.bySemanticsLabel('Jump'));
      expect(zone.width, closeTo(844 * 0.4, 1));
      expect(zone.right, 844);
    });

    testWidgets('leaving a run from Pause keeps the bolts (RES-03)', (
      tester,
    ) async {
      final c = await pumpApp(tester, location: AppRoute.run.path);
      await tester.tapAt(const Offset(400, 200)); // skip the preview
      // Course 1 has a bolt at 800 px; Wheels get there in about 3 s.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tapNav(tester, find.bySemanticsLabel('Pause'));
      await tester.pump();
      await tapNav(tester, find.bySemanticsLabel('Home'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));
      expect(c.read(profileProvider).bolts, greaterThan(0));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(RunScreen), findsNothing);
    });

    testWidgets('Result shows stars, then Next, Rebuild, Play again', (
      tester,
    ) async {
      final c = await pumpApp(tester, location: AppRoute.home.path);
      final report = c
          .read(progressProvider.notifier)
          .applyRun(
            testData.courses.first,
            const RunOutcome(
              finished: true,
              boltsCollected: 5,
              boltsOnCourse: 5,
              falls: 1,
            ),
            const {},
          );
      c.read(lastRunProvider.notifier).set(report);
      c.read(routerProvider).go(AppRoute.result.path);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ResultScreen), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
      for (final label in ['Next', 'Rebuild', 'Play again']) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      // 5 run bolts + 5 reward bolts.
      expect(find.text('+10'), findsOneWidget);
      // NFR-19: no scrolling, so every button must be fully on screen.
      const screen = Rect.fromLTWH(0, 0, 844, 390);
      for (final label in ['Next', 'Rebuild', 'Play again']) {
        final rect = tester.getRect(find.bySemanticsLabel(label));
        expect(screen.intersect(rect), rect, reason: label);
      }
      expect(find.byType(BoltCounter), findsOneWidget);
    });
  });

  testWidgets('end to end: Little Builder plays course 1 to the Result', (
    tester,
  ) async {
    final c = await pumpApp(
      tester,
      location: AppRoute.run.path,
      store: seededStore(
        settings: const Settings(
          onboardingDone: true,
          playStyle: PlayStyle.little,
        ),
      ),
    );
    await tester.tapAt(const Offset(400, 200)); // skip the preview
    // 6000 px at 280 px/s, slowed to 80%: about 27 s, plus the cheer.
    for (var i = 0; i < 340; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(ResultScreen).evaluate().isNotEmpty) break;
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ResultScreen), findsOneWidget);
    final report = c.read(lastRunProvider)!;
    expect(report.outcome.finished, isTrue);
    expect(report.stars.finish, isTrue);
    expect(c.read(profileProvider).resultFor('w1_c01').completed, isTrue);
  });

  testWidgets('the map hint bubble keeps Go on screen (MAP-04, NFR-19)', (
    tester,
  ) async {
    await pumpApp(tester, location: AppRoute.courseMap.path);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.bySemanticsLabel('Course 1, 0 stars'));
    await tester.pump(const Duration(milliseconds: 300));
    const screen = Rect.fromLTWH(0, 0, 844, 390);
    for (final label in ['Go!', 'Say it again']) {
      final rect = tester.getRect(find.bySemanticsLabel(label).last);
      expect(screen.intersect(rect), rect, reason: label);
    }
  });

  testWidgets('the first-run card fits the screen (ONB-01, NFR-19)', (
    tester,
  ) async {
    // A Redmi Note 11S in landscape, minus its camera cut-out.
    await pumpApp(
      tester,
      location: AppRoute.firstRun.path,
      store: seededStore(settings: const Settings()),
      size: const Size(820, 393),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final screen = Offset.zero & tester.view.physicalSize / 2;
    for (final text in ['For grown-ups', 'Little Builder', 'Big Builder']) {
      final rect = tester.getRect(find.text(text));
      expect(screen.intersect(rect), rect, reason: text);
    }
  });
}
