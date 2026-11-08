// Renders every screen at landscape iPhone size with the real fonts into
// build/screenshots/*.png, to compare against the design mockups.
//
// Run: flutter test tool/screenshots/screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/router.dart';
import 'package:little_builder_robots/domain/models/run_outcome.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/rules/unlock_rules.dart';

import '../../test/helpers/app_harness.dart';

Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(
      Future.value(ByteData.view(File(path).readAsBytesSync().buffer)),
    );
  await loader.load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    // The root layer holds every route and overlay; it already scales by
    // the device pixel ratio.
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(Offset.zero & (view.size * 2));
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await _loadFont('Fredoka', 'assets/fonts/Fredoka-Variable.ttf');
    await _loadFont('NunitoSans', 'assets/fonts/NunitoSans-Variable.ttf');
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
    await _loadFont(
      'MaterialIcons',
      '$flutterRoot/bin/cache/artifacts/material_fonts/'
          'materialicons-regular.otf',
    );
  });

  final rules = UnlockRules(
    catalog: testData.catalog,
    courses: testData.courses,
    decals: testData.decals,
  );
  // A child five courses in, with some bolts, like the mockups.
  var played = rules.newProfile();
  for (final course in testData.courses.take(5)) {
    played = rules
        .applyRun(
          played,
          course,
          const RunOutcome(
            finished: true,
            boltsCollected: 5,
            boltsOnCourse: 6,
            falls: 0,
          ),
        )
        .profile;
  }
  played = played.copyWith(bolts: 52, unrevealedStickerIds: const {});

  Future<void> capture(
    WidgetTester tester,
    String name,
    String location, {
    Duration wait = const Duration(milliseconds: 600),
    Future<void> Function()? then,
    Settings settings = const Settings(onboardingDone: true),
  }) async {
    await pumpApp(
      tester,
      location: location,
      store: seededStore(profile: played, settings: settings),
    );
    await tester.pump(wait);
    await then?.call();
    await _shot(tester, name);
  }

  testWidgets(
    'splash',
    (t) => capture(t, '01_splash', '/', wait: Duration.zero),
  );
  testWidgets(
    'first run',
    (t) => capture(t, '02_first_run', AppRoute.firstRun.path),
  );
  testWidgets('home', (t) => capture(t, '03_home', AppRoute.home.path));
  testWidgets(
    'workshop',
    (t) => capture(t, '04_workshop', AppRoute.workshop.path),
  );
  testWidgets(
    'unlock',
    (t) => capture(
      t,
      '05_unlock',
      AppRoute.workshop.path,
      then: () async {
        await t.tap(find.bySemanticsLabel('Tank tracks'));
        await t.pump(const Duration(milliseconds: 500));
        expect(find.byType(Dialog), findsOneWidget);
        await t.pump(const Duration(milliseconds: 100));
      },
    ),
  );
  testWidgets('map', (t) => capture(t, '06_map', AppRoute.courseMap.path));
  testWidgets(
    'run',
    (t) => capture(
      t,
      '07_run',
      AppRoute.run.path,
      then: () async {
        await t.tapAt(const Offset(400, 200));
        for (var i = 0; i < 30; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      },
    ),
  );
  testWidgets(
    'pause',
    (t) => capture(
      t,
      '08_pause',
      AppRoute.run.path,
      then: () async {
        await t.tapAt(const Offset(400, 200));
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.bySemanticsLabel('Pause'));
        await t.pump(const Duration(milliseconds: 300));
      },
    ),
  );
  testWidgets(
    'stickers',
    (t) => capture(t, '09_stickers', AppRoute.stickerBook.path),
  );
  testWidgets('gate', (t) => capture(t, '10_gate', AppRoute.parentGate.path));
  testWidgets('rest', (t) => capture(t, '11_rest', AppRoute.rest.path));
  testWidgets('result', (tester) async {
    final c = await pumpApp(
      tester,
      store: seededStore(profile: played),
    );
    final report = c
        .read(progressProvider.notifier)
        .applyRun(
          testData.courses[2],
          const RunOutcome(
            finished: true,
            boltsCollected: 6,
            boltsOnCourse: 6,
            falls: 0,
          ),
          const {},
        );
    c.read(lastRunProvider.notifier).set(report);
    c.read(routerProvider).go(AppRoute.result.path);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    await _shot(tester, '12_result');
  });
  testWidgets('grown-ups', (tester) async {
    final c = await pumpApp(tester, store: seededStore(profile: played));
    c.read(gatePassedProvider.notifier).set(true);
    c.read(routerProvider).go(AppRoute.grownUps.path);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _shot(tester, '13_grown_ups');
  });
}
