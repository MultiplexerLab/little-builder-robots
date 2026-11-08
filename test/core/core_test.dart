import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations_en.dart';
import 'package:little_builder_robots/core/l10n/l10n_lookup.dart';
import 'package:little_builder_robots/core/utils/play_clock.dart';
import 'package:little_builder_robots/core/utils/touch_guard.dart';
import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';
import 'package:little_builder_robots/features/parent_gate/question_generator.dart';
import 'package:little_builder_robots/features/run/run_screen.dart';

import '../helpers/game_data.dart';

void main() {
  group('PAR-07 play limit', () {
    final now = DateTime(2026, 10, 31, 17);
    const robot = RobotConfig(
      headId: 'h',
      bodyId: 'b',
      armsId: 'a',
      movesId: 'm',
      colour: 'sunny',
    );
    ProfileData played(int minutes, {int bonus = 0}) => ProfileData(
      robot: robot,
      playSecondsByDay: {'2026-10-31': minutes * 60},
      bonusSecondsByDay: {'2026-10-31': bonus * 60},
    );
    const limit15 = Settings(dailyLimitMinutes: 15);

    test('no limit never locks', () {
      expect(playLimit(played(500), const Settings(), now).reached, isFalse);
    });

    test('wind-down in the last 5 minutes, then reached (PAR-11)', () {
      expect(playLimit(played(9), limit15, now), (
        reached: false,
        windDown: false,
      ));
      expect(playLimit(played(11), limit15, now), (
        reached: false,
        windDown: true,
      ));
      expect(playLimit(played(15), limit15, now).reached, isTrue);
    });

    test('"10 more minutes" extends today only', () {
      expect(playLimit(played(20, bonus: 10), limit15, now).reached, isFalse);
      final tomorrow = now.add(const Duration(days: 1));
      expect(playLimit(played(20), limit15, tomorrow).reached, isFalse);
    });

    test('PlayClock reports in batches and splits at midnight', () {
      final calls = <(String, int)>[];
      final clock = PlayClock(
        onSeconds: (d, s) => calls.add((d, s)),
        batchSeconds: 3,
      );
      final day1 = DateTime(2026, 10, 31, 23, 59, 58);
      clock
        ..tick(day1)
        ..tick(day1)
        ..tick(day1);
      expect(calls, [(dayKey(day1), 3)]);
      clock
        ..tick(day1)
        ..tick(day1.add(const Duration(seconds: 5)));
      expect(calls.last, (dayKey(day1), 1));
      clock
        ..flush()
        ..dispose();
      expect(calls.last, ('2026-11-01', 1));
    });
  });

  group('NFR-19 touch guard', () {
    setUp(TouchGuard.instance.reset);

    test('navigation ignores repeat taps within 400 ms', () {
      final t = DateTime(2026);
      final guard = TouchGuard.instance;
      expect(guard.allowNavigation(t), isTrue);
      expect(
        guard.allowNavigation(t.add(const Duration(milliseconds: 300))),
        isFalse,
      );
      expect(
        guard.allowNavigation(t.add(const Duration(milliseconds: 450))),
        isTrue,
      );
    });

    testWidgets('a palm (3+ fingers) blocks taps', (tester) async {
      await tester.pumpWidget(
        const TouchGuardScope(child: SizedBox.expand()),
      );
      final a = await tester.startGesture(const Offset(10, 10));
      final b = await tester.startGesture(const Offset(20, 10));
      expect(TouchGuard.instance.palm, isFalse);
      final c = await tester.startGesture(const Offset(30, 10));
      expect(TouchGuard.instance.palm, isTrue);
      expect(TouchGuard.instance.allowNavigation(), isFalse);
      await a.up();
      await b.up();
      await c.up();
      expect(TouchGuard.instance.palm, isFalse);
    });
  });

  group('PAR-01, PAR-02 Parent gate questions', () {
    test('factors 3 to 9, answers 20 to 81, never repeated', () {
      final generator = QuestionGenerator();
      GateQuestion? previous;
      for (var i = 0; i < 500; i++) {
        final q = generator.next(previous: previous);
        expect(q.a, inInclusiveRange(3, 9));
        expect(q.b, inInclusiveRange(3, 9));
        expect(q.a * q.b, inInclusiveRange(20, 81));
        expect(q, isNot(previous));
        previous = q;
      }
    });

    test('numbers are written in words', () {
      final l10n = AppLocalizationsEn();
      expect(
        l10n.gateQuestion(l10n.numberWord('7'), l10n.numberWord('6')),
        'What is seven multiplied by six?',
      );
    });
  });

  group('NFR-14, AUD-02: every data key has text', () {
    final AppLocalizations l10n = AppLocalizationsEn();

    test('part names, course hints and sticker clues', () {
      final keys = [
        for (final p in loadCatalog().parts) p.nameKey,
        for (final c in loadWorld1()) c.hintKey,
        for (final s in loadStickers()) s.clueKey,
        'testTrackHint',
      ];
      for (final key in keys) {
        expect(lookup(l10n, key), isNot(key), reason: key);
      }
    });

    test('every run hint has text (RUN-13)', () {
      for (final need in Need.values) {
        final key = needHintKey(need);
        expect(lookup(l10n, key), isNot(key), reason: key);
      }
    });
  });
}
