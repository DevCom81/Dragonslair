import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/music_service.dart';
import '../domain/music_mood.dart';
import '../domain/music_playback_state.dart';

final musicServiceProvider = Provider<MusicService>((ref) {
  final service = JustAudioMusicService();
  ref.onDispose(service.dispose);
  return service;
});

final musicClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final musicNarrativeCooldownProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 60);
});

final musicControllerProvider =
    NotifierProvider<MusicController, MusicPlaybackState>(MusicController.new);

class MusicController extends Notifier<MusicPlaybackState> {
  static const _mutedKey = 'music_muted';
  static const _volumeKey = 'music_volume';

  DateTime? _lastNarrativeChangeAt;

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

  Future<void> unlock() async {
    if (state.isUnlocked) {
      return;
    }
    state = state.copyWith(isUnlocked: true);
    final mood = state.currentMood;
    if (mood == null) {
      return;
    }
    await _service.crossfadeTo(
      assetPath: mood.assetPath,
      targetVolume: state.outputVolume,
    );
  }

  Future<void> setMood(MusicMood mood) {
    return _applyMood(mood, fromNarrative: true);
  }

  Future<void> restorePreviousMood() {
    return _applyMood(
      state.previousMood ?? MusicMood.exploration,
      fromNarrative: false,
      bypassCooldown: true,
    );
  }

  Future<void> enterCombat() {
    if (state.combatActive && state.currentMood == MusicMood.combat) {
      return Future.value();
    }
    return _applyMood(
      MusicMood.combat,
      fromNarrative: false,
      bypassCooldown: true,
      enteringCombat: true,
    );
  }

  Future<void> leaveCombat() {
    if (!state.combatActive) {
      return Future.value();
    }
    state = state.copyWith(combatActive: false);
    return restorePreviousMood();
  }

  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    unawaited(_service.setOutputVolume(state.outputVolume));
    unawaited(_persist());
  }

  void toggleMute() {
    state = state.copyWith(isMuted: !state.isMuted);
    unawaited(_service.setOutputVolume(state.outputVolume));
    unawaited(_persist());
  }

  void stop() {
    state = state.copyWith(clearCurrentMood: true, combatActive: false);
    unawaited(_service.stop());
  }

  Future<void> _applyMood(
    MusicMood mood, {
    required bool fromNarrative,
    bool bypassCooldown = false,
    bool enteringCombat = false,
  }) async {
    if (state.combatActive && mood != MusicMood.combat && !enteringCombat) {
      return;
    }
    if (!bypassCooldown && fromNarrative && !_cooldownElapsed()) {
      return;
    }
    if (mood == state.currentMood) {
      if (enteringCombat) {
        state = state.copyWith(combatActive: true);
      }
      return;
    }

    final previous = state.currentMood;
    final nextPrevious = mood == MusicMood.combat
        ? (previous == MusicMood.combat ? state.previousMood : previous)
        : previous;

    state = state.copyWith(
      previousMood: nextPrevious,
      currentMood: mood,
      combatActive: enteringCombat ? true : state.combatActive,
    );
    if (fromNarrative) {
      _lastNarrativeChangeAt = ref.read(musicClockProvider)();
    }
    if (!state.isUnlocked) {
      return;
    }
    await _service.crossfadeTo(
      assetPath: mood.assetPath,
      targetVolume: state.outputVolume,
    );
  }

  bool _cooldownElapsed() {
    final last = _lastNarrativeChangeAt;
    if (last == null) {
      return true;
    }
    final now = ref.read(musicClockProvider)();
    return now.difference(last) >= ref.read(musicNarrativeCooldownProvider);
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
