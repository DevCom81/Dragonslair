import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/music_service.dart';
import '../domain/music_mood.dart';
import '../domain/music_playback_state.dart';

final musicServiceProvider = Provider<MusicService>((ref) {
  final service = JustAudioMusicService();
  unawaited(service.preload(MusicMood.exploration.assetPath));
  ref.onDispose(service.dispose);
  return service;
});

final musicControllerProvider =
    NotifierProvider<MusicController, MusicPlaybackState>(MusicController.new);

class MusicController extends Notifier<MusicPlaybackState> {
  static const _mutedKey = 'music_muted';
  static const _volumeKey = 'music_volume';

  MusicService get _service => ref.read(musicServiceProvider);

  @override
  MusicPlaybackState build() => const MusicPlaybackState();

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final muted = prefs.getBool(_mutedKey) ?? false;
      final volume = (prefs.getDouble(_volumeKey) ?? 0.7).clamp(0.0, 1.0);
      state = state.copyWith(isMuted: muted, volume: volume);
    } on Object {
      // Keep defaults if storage is unavailable.
    }
  }

  void primeFromUserGesture() {
    _service.primeFromUserGesture();
    unawaited(unlock());
  }

  Future<void> unlock() async {
    state = state.copyWith(isUnlocked: true);
    final mood = state.currentMood ?? MusicMood.exploration;
    if (state.currentMood == null) {
      state = state.copyWith(currentMood: mood);
    }
    await _service.ensurePlaying(
      assetPath: mood.assetPath,
      targetVolume: state.outputVolume,
    );
  }

  Future<void> setMood(MusicMood mood) {
    if (mood == MusicMood.combat) {
      return enterCombat();
    }
    return syncScene(
      narrativeMood: mood,
      combatActive: state.combatActive,
    );
  }

  Future<void> enterCombat() {
    final narrative = state.currentMood == MusicMood.combat
        ? (state.previousMood ?? MusicMood.exploration)
        : (state.currentMood ?? MusicMood.exploration);
    return syncScene(narrativeMood: narrative, combatActive: true);
  }

  Future<void> leaveCombat() {
    return syncScene(
      narrativeMood: state.previousMood ?? MusicMood.exploration,
      combatActive: false,
    );
  }

  Future<void> syncScene({
    required MusicMood narrativeMood,
    required bool combatActive,
  }) async {
    final narrative = narrativeMood.isNarrative
        ? narrativeMood
        : (state.previousMood ?? MusicMood.exploration);
    final target = combatActive ? MusicMood.combat : narrative;
    if (state.currentMood == target && state.combatActive == combatActive) {
      if (state.previousMood != narrative) {
        state = state.copyWith(previousMood: narrative);
      }
      if (state.isUnlocked) {
        await _service.ensurePlaying(
          assetPath: target.assetPath,
          targetVolume: state.outputVolume,
        );
      }
      return;
    }

    state = state.copyWith(
      previousMood: narrative,
      currentMood: target,
      combatActive: combatActive,
    );
    if (!state.isUnlocked) {
      return;
    }
    await _service.crossfadeTo(
      assetPath: target.assetPath,
      targetVolume: state.outputVolume,
    );
  }

  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    unawaited(_service.setOutputVolume(state.outputVolume));
    final mood = state.currentMood;
    if (state.isUnlocked && mood != null) {
      unawaited(
        _service.ensurePlaying(
          assetPath: mood.assetPath,
          targetVolume: state.outputVolume,
        ),
      );
    }
    unawaited(_persist());
  }

  void toggleMute() {
    state = state.copyWith(isMuted: !state.isMuted);
    unawaited(_service.setOutputVolume(state.outputVolume));
    final mood = state.currentMood;
    if (state.isUnlocked && mood != null && !state.isMuted) {
      unawaited(
        _service.ensurePlaying(
          assetPath: mood.assetPath,
          targetVolume: state.outputVolume,
        ),
      );
    }
    unawaited(_persist());
  }

  void stop() {
    state = state.copyWith(clearCurrentMood: true, combatActive: false);
    unawaited(_service.stop());
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedKey, state.isMuted);
      await prefs.setDouble(_volumeKey, state.volume);
    } on Object {
      // Session values still apply.
    }
  }
}
