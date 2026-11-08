// A long scripted play session through the real UI, to shake out runtime
// errors: it builds the intended robot in the Workshop for every course,
// plays each run (Helper mode jumps and flies by itself), swaps parts at
// pit stops, takes the rewards and walks back through the map. Then it
// visits Test Track, the sticker book, the Parent gate and Grown-ups.
//
// Any exception, overflow or tap on a widget that can't be hit fails it.
// Run: flutter test tool/soak/play_session_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/router.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations_en.dart';
import 'package:little_builder_robots/core/l10n/l10n_lookup.dart';
import 'package:little_builder_robots/core/utils/touch_guard.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/features/course_map/course_map_screen.dart';
import 'package:little_builder_robots/features/grown_ups/settings_screen.dart';
import 'package:little_builder_robots/features/home/home_screen.dart';
import 'package:little_builder_robots/features/result/result_screen.dart';
import 'package:little_builder_robots/features/run/pit_stop_panel.dart';
import 'package:little_builder_robots/features/stickers/sticker_book_screen.dart';
import 'package:little_builder_robots/features/stickers/sticker_icons.dart';
import 'package:little_builder_robots/features/workshop/workshop_screen.dart';

import '../../test/helpers/app_harness.dart';

final l10n = AppLocalizationsEn();
final log = <String>[];

String partName(String id) => lookup(l10n, testData.catalog.byId(id).nameKey);

/// Taps the widget with this screen-reader label, after checking it can
/// really be hit (a child can't scroll to reach it).
Future<void> tapLabel(WidgetTester tester, String label) async {
  TouchGuard.instance.reset();
  final finder = find.bySemanticsLabel(label).hitTestable();
  expect(finder, findsWidgets, reason: 'nothing tappable says "$label"');
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 50));
}

/// Pumps frames until [done] or [seconds] pass.
Future<bool> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  double seconds = 60,
}) async {
  for (var t = 0.0; t < seconds; t += 0.1) {
    if (done()) return true;
    await tester.pump(const Duration(milliseconds: 100));
  }
  return done();
}

bool on(Type screen) => find.byType(screen).evaluate().isNotEmpty;

/// Closes reveal dialogs (part and sticker) by their only buttons.
Future<void> closeReveals(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
    final ok = find.bySemanticsLabel(l10n.buttonOk).hitTestable();
    final tryOn = find.bySemanticsLabel(l10n.buttonTryItOn).hitTestable();
    if (tryOn.evaluate().isNotEmpty) {
      await tapLabel(tester, l10n.buttonTryItOn);
    } else if (ok.evaluate().isNotEmpty) {
      await tapLabel(tester, l10n.buttonOk);
    }
  }
}

Future<void> equip(WidgetTester tester, List<String> partIds) async {
  for (final id in partIds) {
    final slot = testData.catalog.byId(id).slot;
    await tapLabel(tester, l10n.tabLabel(slot.name));
    await tester.pump(const Duration(milliseconds: 200));
    await tapLabel(tester, partName(id));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> playCourse(WidgetTester tester, Course course) async {
  final plan = course.intendedBuilds.first;
  log.add('course ${course.index}');

  await pumpUntil(tester, () => on(HomeScreen));
  await tapLabel(tester, l10n.buttonPlay);
  await pumpUntil(tester, () => on(WorkshopScreen), seconds: 3);
  await closeReveals(tester);
  // Start each course from the default build, then add the plan's parts.
  await equip(tester, [
    for (final slot in [Slot.body, Slot.arms, Slot.moves])
      testData.catalog.defaultRobot.partIdFor(slot),
    ...plan.parts,
  ]);
  await tapLabel(tester, l10n.buttonTestIt);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tapAt(const Offset(300, 250)); // skip the course preview

  var stop = 0;
  final finished = await pumpUntil(tester, () {
    return on(ResultScreen) || on(PitStopPanel);
  }, seconds: 90);
  expect(finished, isTrue, reason: 'course ${course.index} stalled');
  while (on(PitStopPanel)) {
    log.add('  pit stop ${stop + 1}');
    // A plan may keep its parts through a pit stop.
    final swap = stop < plan.pitStops.length ? plan.pitStops[stop] : <String>[];
    for (final id in swap) {
      await tapLabel(tester, partName(id));
      await tester.pump(const Duration(milliseconds: 200));
    }
    stop++;
    await tapLabel(tester, l10n.buttonGo);
    await pumpUntil(
      tester,
      () => on(ResultScreen) || on(PitStopPanel),
      seconds: 90,
    );
  }
  expect(on(ResultScreen), isTrue, reason: 'course ${course.index}');
  await tester.pump(const Duration(seconds: 2));
  await closeReveals(tester);
  await pumpUntil(
    tester,
    () => find
        .bySemanticsLabel(l10n.buttonNext)
        .hitTestable()
        .evaluate()
        .isNotEmpty,
    seconds: 5,
  );
  await tapLabel(tester, l10n.buttonNext);
  await pumpUntil(tester, () => on(CourseMapScreen), seconds: 3);
  await tapLabel(tester, l10n.buttonHome);
}

void main() {
  testWidgets(
    'play the whole game through the UI',
    (tester) async {
      final c = await pumpApp(
        tester,
        location: AppRoute.home.path,
        store: seededStore(
          settings: const Settings(
            onboardingDone: true,
            playStyle: PlayStyle.little,
          ),
        ),
      );

      for (final course in testData.courses) {
        await playCourse(tester, course);
        final result = c.read(profileProvider).resultFor(course.id);
        expect(result.completed, isTrue, reason: 'course ${course.index}');
        log.add('  stars ${result.stars}');
      }

      // Test Track: two laps.
      await pumpUntil(tester, () => on(HomeScreen));
      await tapLabel(tester, l10n.buttonTestTrack);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapAt(const Offset(300, 250));
      for (var lap = 0; lap < 9; lap++) {
        await pumpUntil(tester, () => on(PitStopPanel), seconds: 40);
        if (on(PitStopPanel)) await tapLabel(tester, l10n.buttonGo);
      }
      await tapLabel(tester, l10n.buttonPause);
      await tapLabel(tester, l10n.buttonHome);

      // Sticker book: tap every sticker for its clue.
      await pumpUntil(tester, () => on(HomeScreen));
      await tapLabel(tester, l10n.buttonStickers);
      await pumpUntil(tester, () => on(StickerBookScreen), seconds: 3);
      // Every sticker must be reachable without scrolling (NFR-19).
      final badges = find.byType(StickerBadge);
      expect(badges, findsNWidgets(testData.stickers.length));
      for (var i = 0; i < testData.stickers.length; i++) {
        expect(
          badges.at(i).hitTestable(),
          findsOneWidget,
          reason: 'sticker $i',
        );
        await tester.tap(badges.at(i));
        await tester.pump(const Duration(milliseconds: 100));
      }
      log.add(
        'stickers ${c.read(profileProvider).stickerIds.length}'
        '/${testData.stickers.length}',
      );
      await tapLabel(tester, l10n.buttonHome);

      // Grown-ups through the gate; flip every switch.
      c.read(gatePassedProvider.notifier).set(true);
      c.read(routerProvider).go(AppRoute.grownUps.path);
      await pumpUntil(tester, () => on(SettingsScreen), seconds: 3);
      for (final s in tester.widgetList<Switch>(find.byType(Switch)).toList()) {
        s.onChanged!(!s.value);
        await tester.pump();
      }
      // Grown-ups may scroll; children's screens may not.
      await tester.scrollUntilVisible(
        find.text(l10n.limitMinutes(15)),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text(l10n.limitMinutes(15)));
      await tester.pump();
      expect(c.read(settingsProvider).dailyLimitMinutes, 15);

      // The session log is the point of this tool run.
      // ignore: avoid_print
      print(log.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
