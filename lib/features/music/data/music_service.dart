import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'web_audio_prime.dart';

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
  }) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  final Duration fadeDuration;
  var _generation = 0;
  var _disposed = false;
  String? _loadedAsset;

  @override
  void primeFromUserGesture() {
    primeWebAudio();
    if (_loadedAsset != null && !_disposed) {
      unawaited(_playIgnoringErrors());
    }
  }

  Future<void> _playIgnoringErrors() async {
    try {
      await _player.play();
    } on Object catch (error, stackTrace) {
      debugPrint('Music play failed: $error\n$stackTrace');
    }
  }

  @override
  Future<void> preload(String assetPath) {
    return _setSource(assetPath);
  }

  @override
  Future<void> crossfadeTo({
    required String assetPath,
    required double targetVolume,
  }) async {
    if (_disposed) {
      return;
    }
    final generation = ++_generation;
    final volume = targetVolume.clamp(0.0, 1.0);
    try {
      if (_player.playing || _loadedAsset != null) {
        await _rampVolume(to: 0, generation: generation);
      }
      if (_disposed || generation != _generation) {
        return;
      }
      await _setSource(assetPath);
      if (_disposed || generation != _generation) {
        return;
      }
      await _player.setVolume(0);
      await _player.play();
      await _rampVolume(to: volume, generation: generation);
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
    try {
      await _setSource(assetPath);
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
    try {
      await _player.setVolume(volume.clamp(0, 1));
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
    _player.dispose();
  }

  Future<void> _setSource(String assetPath) async {
    if (_disposed || _loadedAsset == assetPath) {
      return;
    }
    if (kIsWeb) {
      // setAsset inlines the whole MP3 as a data URL (~4 MB). That blocks
      // Chrome autoplay because play() runs after the load, not on the click.
      await _player.setUrl('assets/$assetPath');
    } else {
      await _player.setAsset(assetPath);
    }
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
