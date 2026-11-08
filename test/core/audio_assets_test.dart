import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/core/audio/audio_service.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';
import 'package:little_builder_robots/features/run/run_screen.dart';

import '../helpers/game_data.dart';

bool _exists(String path) => File('assets/audio/$path').existsSync();

/// AUD-01 and AUD-02: every clip the game can ask for is in the bundle.
void main() {
  test('a music loop per screen group', () {
    for (final group in MusicGroup.values) {
      expect(_exists('music/${group.name}.m4a'), isTrue, reason: group.name);
    }
  });

  test('every sound effect', () {
    for (final sound in Sfx.values) {
      expect(_exists('sfx/${sound.name}.m4a'), isTrue, reason: sound.name);
    }
  });

  test('a voice clip for every child-facing line', () {
    final keys = <String>{
      // Fixed lines the screens play.
      'firstRunQuestion', 'homeGreeting', 'homeIdlePlay', 'testTrackLocked',
      'testTrackHint', 'needMoreBolts', 'partFromCourse', 'pitStopHint',
      'tryNewParts', 'screenResult', 'newPartTitle', 'newStickerTitle',
      'restMessage', 'tutorialTapPart', 'tutorialTestIt', 'tutorialTapJump',
      // Lines that come from data or rules.
      for (final c in loadWorld1()) c.hintKey,
      for (final s in loadStickers()) s.clueKey,
      for (final need in Need.values) needHintKey(need),
      for (final key in const [
        'goodAtSpeed', 'goodAtClimb', 'goodAtJump', 'goodAtHeavy', //
        'goodAtJetpack', 'goodAtGrab', 'goodAtFan', 'goodAtMudproof',
      ])
        key,
    };
    for (final key in keys) {
      expect(_exists('voice/en_GB/$key.m4a'), isTrue, reason: key);
    }
    // And each voiced key has text to show alongside it (DES-09).
    final arb =
        jsonDecode(File('lib/core/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    for (final key in keys) {
      expect(arb.containsKey(key), isTrue, reason: key);
    }
  });
}
