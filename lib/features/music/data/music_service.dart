import 'package:just_audio/just_audio.dart';

abstract class MusicService {
  Future<void> crossfadeTo({
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
  Future<void> crossfadeTo({
    required String assetPath,
    required double targetVolume,
  }) async {
    if (_disposed) {
      return;
    }
    final generation = ++_generation;
    try {
      if (_player.playing || _loadedAsset != null) {
        await _rampVolume(to: 0, generation: generation);
      }
      if (_disposed || generation != _generation) {
        return;
      }
      if (_loadedAsset != assetPath) {
        await _player.setAsset(assetPath);
        await _player.setLoopMode(LoopMode.one);
        _loadedAsset = assetPath;
      }
      if (_disposed || generation != _generation) {
        return;
      }
      await _player.setVolume(0);
      await _player.play();
      await _rampVolume(to: targetVolume.clamp(0, 1), generation: generation);
    } on Object {
      // Autoplay / decode errors must never block the game.
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
