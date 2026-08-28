import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'web_bgm.dart';

abstract class MusicService {
  void primeFromUserGesture();

  Future<void> preload(String assetPath);

  Future<void> crossfadeTo({
    required String assetPath,
    required double targetVolume,
  });

  Future<void> ensurePlaying({
    required String assetPath,
    required double targetVolume,
  });

  Future<void> setOutputVolume(double volume);

  Future<void> stop();

  void dispose();
}

class JustAudioMusicService implements MusicService {
  JustAudioMusicService({
    AudioPlayer? player,
    this.fadeDuration = const Duration(seconds: 2),
  }) : _injectedPlayer = player;

  final AudioPlayer? _injectedPlayer;
  AudioPlayer? _mobilePlayer;
  final Duration fadeDuration;
  final _web = WebBgmPlayer();
  var _generation = 0;
  var _disposed = false;
  String? _loadedAsset;

  AudioPlayer get _player =>
      _injectedPlayer ?? (_mobilePlayer ??= AudioPlayer());

  String _webUrl(String assetPath) => '${Uri.base.origin}/assets/$assetPath';

  @override
  void primeFromUserGesture() {
    if (_disposed) {
      return;
    }
    if (kIsWeb) {
      _web.prime();
    }
  }

  @override
  Future<void> preload(String assetPath) async {
    if (_disposed) {
      return;
    }
    if (kIsWeb) {
      _web.preload(_webUrl(assetPath));
      _loadedAsset = assetPath;
      return;
    }
    await _setMobileSource(assetPath);
  }

  @override
  Future<void> crossfadeTo({
    required String assetPath,
    required double targetVolume,
  }) async {
    if (_disposed) {
      return;
    }
    final volume = targetVolume.clamp(0.0, 1.0);
    if (kIsWeb) {
      await _playWeb(assetPath, volume);
      return;
    }
    final generation = ++_generation;
    try {
      final changingTrack =
          _loadedAsset != null && _loadedAsset != assetPath && _player.playing;
      if (changingTrack) {
        await _rampVolume(to: 0, generation: generation);
      }
      if (_disposed || generation != _generation) {
        return;
      }
      await _setMobileSource(assetPath);
      if (_disposed || generation != _generation) {
        return;
      }
      await _player.setVolume(volume);
      await _player.play();
    } on Object catch (error, stackTrace) {
      debugPrint('Music crossfade failed: $error\n$stackTrace');
      await _restoreVolume(volume);
    }
  }

  @override
  Future<void> ensurePlaying({
    required String assetPath,
    required double targetVolume,
  }) async {
    if (_disposed) {
      return;
    }
    final volume = targetVolume.clamp(0.0, 1.0);
    if (kIsWeb) {
      await _playWeb(assetPath, volume);
      return;
    }
    try {
      await _setMobileSource(assetPath);
      await _player.setVolume(volume);
      if (!_player.playing) {
        await _player.play();
      }
    } on Object catch (error, stackTrace) {
      debugPrint('Music playback failed: $error\n$stackTrace');
      await _restoreVolume(volume);
    }
  }

  @override
  Future<void> setOutputVolume(double volume) async {
    if (_disposed) {
      return;
    }
    final clamped = volume.clamp(0.0, 1.0);
    if (kIsWeb) {
      _web.setVolume(clamped);
      return;
    }
    try {
      await _player.setVolume(clamped);
    } on Object {
      // Ignore platform volume failures.
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _loadedAsset = null;
    if (_disposed) {
      return;
    }
    if (kIsWeb) {
      _web.stop();
      return;
    }
    try {
      await _player.stop();
    } on Object {
      // Ignore stop failures.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _web.stop();
    _injectedPlayer?.dispose();
    _mobilePlayer?.dispose();
  }

  Future<void> _playWeb(String assetPath, double volume) async {
    try {
      await _web.playUrl(_webUrl(assetPath), volume);
      _loadedAsset = assetPath;
    } on Object catch (error, stackTrace) {
      debugPrint('Music web playback failed: $error\n$stackTrace');
    }
  }

  Future<void> _setMobileSource(String assetPath) async {
    if (_disposed || _loadedAsset == assetPath) {
      return;
    }
    await _player.setAsset(assetPath);
    await _player.setLoopMode(LoopMode.one);
    _loadedAsset = assetPath;
  }

  Future<void> _restoreVolume(double volume) async {
    try {
      await _player.setVolume(volume);
    } on Object {
      // Best-effort; playback may still be blocked.
    }
  }

  Future<void> _rampVolume({
    required double to,
    required int generation,
  }) async {
    const steps = 16;
    final from = _player.volume;
    if ((to - from).abs() < 0.01) {
      await _player.setVolume(to);
      return;
    }
    final stepDuration = fadeDuration ~/ steps;
    for (var i = 1; i <= steps; i++) {
      if (_disposed || generation != _generation) {
        return;
      }
      final t = i / steps;
      await _player.setVolume(from + (to - from) * t);
      if (stepDuration > Duration.zero) {
        await Future<void>.delayed(stepDuration);
      }
    }
  }
}
