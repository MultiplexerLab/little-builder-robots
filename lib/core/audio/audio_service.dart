import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:little_builder_robots/domain/models/settings.dart';

/// Music loops per screen group (AUD-01).
enum MusicGroup { menus, workshop, run, testTrack }

/// Sound effects. Failures are funny, never buzzers (FEEL-03).
enum Sfx {
  tap,
  snap,
  bolt,
  jump,
  land,
  boing,
  splash,
  honk,
  cheer,
  star,
  reveal,
  unlock,
  swing,
  door,
  whoosh,
  jetpack,
  shake,
  yawn,
}

/// Plays bundled clips only (PRV-03). A clip that is not in the bundle yet
/// is skipped quietly, so the game runs before all audio is recorded.
///
/// Files: `assets/audio/music/<group>.m4a`, `assets/audio/sfx/<name>.m4a`
/// and `assets/audio/voice/en_GB/<l10n key>.m4a` (AUD-02: a voice clip has the
/// same name as the text it reads).
class AudioService {
  AudioService._(this._available);

  /// Plays nothing; for tests and before start-up.
  AudioService.silent() : _available = const {};

  /// Lists the bundled clips and sets the iOS ambient audio category, so the
  /// silent switch mutes the game (AUD-03).
  static Future<AudioService> create(AssetBundle bundle) async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final clips = {
      for (final path in manifest.listAssets())
        if (path.startsWith('assets/audio/') && !path.endsWith('.gitkeep'))
          path,
    };
    await AudioPlayer.global.setAudioContext(
      AudioContextConfig(respectSilence: true).build(),
    );
    return AudioService._(clips);
  }

  static const _duckVolume = 0.3;
  static const _musicVolume = 0.6;

  final Set<String> _available;
  Settings _settings = const Settings();
  MusicGroup? _group;
  AudioPlayer? _music;
  AudioPlayer? _voice;
  final List<AudioPlayer> _sfx = [];
  int _nextSfx = 0;

  bool get _silent => _available.isEmpty;

  bool _has(String path) => _available.contains('assets/$path');

  /// Follows the Grown-ups switches (PAR-04, AUD-03).
  void apply(Settings settings) {
    _settings = settings;
    if (!settings.music) {
      unawaited(_music?.stop());
    } else if (_group != null) {
      final group = _group!;
      _group = null;
      unawaited(music(group));
    }
    if (!settings.voice) unawaited(_voice?.stop());
  }

  Future<void> music(MusicGroup group) async {
    if (_silent || _group == group) return;
    _group = group;
    final path = 'audio/music/${group.name}.m4a';
    if (!_settings.music || !_has(path)) {
      await _music?.stop();
      return;
    }
    final player = _music ??= AudioPlayer();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource(path), volume: _musicVolume);
  }

  void sfx(Sfx sound) {
    if (_silent || !_settings.sfx) return;
    final path = 'audio/sfx/${sound.name}.m4a';
    if (!_has(path)) return;
    if (_sfx.length < 4) _sfx.add(AudioPlayer());
    final player = _sfx[_nextSfx++ % _sfx.length];
    unawaited(player.play(AssetSource(path)));
  }

  /// The robot's short exclamations ("Wheee!"). They use a sound effect
  /// player so they never cut off a hint, and follow the voice switch.
  void say(String key) {
    if (_silent || !_settings.voice) return;
    final path = 'audio/voice/en_GB/$key.m4a';
    if (!_has(path)) return;
    if (_sfx.length < 4) _sfx.add(AudioPlayer());
    final player = _sfx[_nextSfx++ % _sfx.length];
    unawaited(player.play(AssetSource(path)));
  }

  /// Plays the voice clip for an l10n [key] (AUD-02), ducking the music
  /// while it speaks (AUD-04).
  Future<void> voice(String key) async {
    if (_silent || !_settings.voice) return;
    final path = 'audio/voice/en_GB/$key.m4a';
    if (!_has(path)) return;
    final player = _voice ??= AudioPlayer();
    await player.stop();
    await _music?.setVolume(_duckVolume);
    await player.play(AssetSource(path));
    unawaited(
      player.onPlayerComplete.first.then(
        (_) => _music?.setVolume(_musicVolume),
      ),
    );
  }
}
