import 'music_mood.dart';

class MusicPlaybackState {
  const MusicPlaybackState({
    this.currentMood,
    this.previousMood,
    this.isMuted = false,
    this.volume = 0.7,
    this.isUnlocked = false,
    this.combatActive = false,
  });

  final MusicMood? currentMood;
  final MusicMood? previousMood;
  final bool isMuted;
  final double volume;
  final bool isUnlocked;
  final bool combatActive;

  double get outputVolume => isMuted ? 0 : volume.clamp(0, 1);

  MusicPlaybackState copyWith({
    MusicMood? currentMood,
    MusicMood? previousMood,
    bool? isMuted,
    double? volume,
    bool? isUnlocked,
    bool? combatActive,
    bool clearCurrentMood = false,
    bool clearPreviousMood = false,
  }) {
    return MusicPlaybackState(
      currentMood: clearCurrentMood ? null : (currentMood ?? this.currentMood),
      previousMood: clearPreviousMood
          ? null
          : (previousMood ?? this.previousMood),
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      combatActive: combatActive ?? this.combatActive,
    );
  }
}
