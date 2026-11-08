import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/audio/audio_service.dart';
import 'package:little_builder_robots/core/haptics/haptics.dart';
import 'package:little_builder_robots/core/utils/play_clock.dart';
import 'package:little_builder_robots/core/widgets/robot_painter.dart';
import 'package:little_builder_robots/data/game_data_repository.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/rules/sticker_rules.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';

import '../helpers/game_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Haptics (FEEL-02)', () {
    late List<String> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              calls.add(call.arguments as String);
            }
            return null;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    test('vibrates when on', () async {
      const Haptics(enabled: true)
        ..light()
        ..medium();
      await Future<void>.delayed(Duration.zero);
      expect(calls, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
      ]);
    });

    test('stays still when the Grown-ups switch is off', () async {
      const Haptics(enabled: false)
        ..light()
        ..medium();
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
    });
  });

  test('a silent AudioService never touches the platform', () async {
    final audio = AudioService.silent()
      ..apply(const Settings(music: false))
      ..sfx(Sfx.bolt);
    await audio.music(MusicGroup.run);
    await audio.voice('homeGreeting');
  });

  group('PlayClock', () {
    test('pause saves what is pending; stop does not', () {
      final calls = <int>[];
      PlayClock(onSeconds: (_, s) => calls.add(s))
        ..tick()
        ..tick()
        ..pause();
      expect(calls, [2]);
      PlayClock(onSeconds: (_, s) => calls.add(s))
        ..tick()
        ..stop();
      expect(calls, [2]);
    });

    test('dayKey pads month and day', () {
      expect(dayKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
    });
  });

  test('RobotArt draws every part, face, paint and decal (WRK-13)', () {
    final catalog = loadCatalog();
    final decals = [null, ...loadDecals().map((d) => d.id)];
    final base = catalog.defaultRobot;
    var drawn = 0;
    for (final slot in Slot.values) {
      for (final part in catalog.inSlot(slot)) {
        for (final face in RobotFace.values) {
          final recorder = PictureRecorder();
          RobotArt.draw(
            Canvas(recorder),
            RobotLook(
              base.withPart(slot, part.id),
              face: face,
              armsUp: face == RobotFace.cheer,
              flame: part.id == 'moves_jetpack',
            ),
          );
          recorder.endRecording().dispose();
          drawn++;
        }
      }
    }
    for (final paint in AppColors.paints.keys) {
      for (final decal in decals) {
        final recorder = PictureRecorder();
        RobotArt.paintInto(
          Canvas(recorder),
          const Size(96, 96),
          RobotLook(base.copyWith(colour: paint, decalId: decal)),
        );
        recorder.endRecording().dispose();
        drawn++;
      }
    }
    expect(drawn, 17 * 4 + 6 * 9);
  });

  test('every run event that is a discovery becomes a sticker fact', () {
    final courses = loadWorld1();
    final rules = StickerRules(
      stickers: loadStickers(),
      catalog: loadCatalog(),
      courses: courses,
    );
    final finale = courses.last; // has every obstacle type
    int indexOf(bool Function(Object) test) =>
        finale.obstacles.indexWhere(test);
    final facts = rules.factsFromRun(finale, [
      const RunEvent.jumped(),
      const RunEvent.boltCollected(0),
      RunEvent.bumped(
        indexOf((o) => o.toString().startsWith('Obstacle.steps')),
      ),
      RunEvent.bumped(indexOf((o) => o.toString().startsWith('Obstacle.mud'))),
      RunEvent.fell(
        indexOf((o) => o.toString().contains('water: true')),
      ),
      const RunEvent.jetpackOn(),
      const RunEvent.switchPressed(0),
      const RunEvent.swung(0),
      const RunEvent.leavesBlown(0),
      const RunEvent.rampLaunch(0),
      const RunEvent.ceilingBonk(),
      const RunEvent.gateOpened(0),
      const RunEvent.happyHop(),
      // Not discoveries:
      const RunEvent.landed(),
      const RunEvent.checkpointReached(1),
      const RunEvent.finished(),
    ]);
    expect(facts, {
      Fact.jump, Fact.bolt, Fact.boing, Fact.mud, Fact.splash, //
      Fact.jetpack, Fact.heavySwitch, Fact.swing, Fact.leaves, Fact.ramp,
      Fact.ceiling, Fact.gate, Fact.hop,
    });
  });

  test('GameDataRepository.loadAll reads every bundled file', () async {
    final data = await GameDataRepository(rootBundle).loadAll();
    expect(data.catalog.parts, hasLength(17));
    expect(data.courses, hasLength(15));
    expect(data.stickers, hasLength(25));
    expect(data.decals, hasLength(8));
    expect(data.testTrack.sections, hasLength(9));
    expect(data.tuning.stepsPerSecond, 120);
    expect(data.courseById('w1_c07').index, 7);
  });
}
