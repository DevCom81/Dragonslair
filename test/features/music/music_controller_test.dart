import 'package:dragons_lair/features/music/data/music_service.dart';
import 'package:dragons_lair/features/music/domain/music_mood.dart';
import 'package:dragons_lair/features/music/presentation/music_controller.dart';
import 'package:dragons_lair/features/game_master/domain/game_master_response.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeMusicService implements MusicService {
  final played = <String>[];
  double volume = 0.7;
  var stopCount = 0;
  var primeCount = 0;
  var preloadCount = 0;

  @override
  void primeFromUserGesture() {
    primeCount += 1;
  }

  @override
  Future<void> preload(String assetPath) async {
    preloadCount += 1;
  }

  @override
  Future<void> crossfadeTo({
    required String assetPath,
    required double targetVolume,
  }) async {
    played.add(assetPath);
    volume = targetVolume;
  }

  @override
  Future<void> ensurePlaying({
    required String assetPath,
    required double targetVolume,
  }) async {
    played.add(assetPath);
    volume = targetVolume;
  }

  @override
  Future<void> setOutputVolume(double volume) async {
    this.volume = volume;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMusicService fake;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeMusicService();
    container = ProviderContainer(
      overrides: [
        musicServiceProvider.overrideWith((ref) => fake),
      ],
    );
  });

  tearDown(() => container.dispose());

  MusicController controller() {
    container.read(musicControllerProvider);
    return container.read(musicControllerProvider.notifier);
  }

  test('maps each MusicMood to its asset path', () {
    expect(MusicMood.tavern.assetPath, 'Assets/sound/Auberge.mp3');
    expect(MusicMood.exploration.assetPath, 'Assets/sound/Exploration.mp3');
    expect(MusicMood.mystery.assetPath, 'Assets/sound/Mystere.mp3');
    expect(MusicMood.tension.assetPath, 'Assets/sound/Tension.mp3');
    expect(MusicMood.combat.assetPath, 'Assets/sound/Combat.mp3');
  });

  test('unlock starts exploration when no mood is set', () async {
    final music = controller();
    await music.unlock();

    expect(
      container.read(musicControllerProvider).currentMood,
      MusicMood.exploration,
    );
    expect(fake.played, [MusicMood.exploration.assetPath]);
    expect(container.read(musicControllerProvider).isUnlocked, isTrue);
  });

  test('same scene after unlock does not restart the track', () async {
    final music = controller();
    await music.unlock();
    fake.played.clear();
    await music.syncScene(
      narrativeMood: MusicMood.exploration,
      combatActive: false,
    );

    expect(fake.played, [MusicMood.exploration.assetPath]);
  });

  test('unlock retries playback after a failed autoplay', () async {
    final music = controller();
    await music.unlock();
    fake.played.clear();
    await music.unlock();

    expect(fake.played, [MusicMood.exploration.assetPath]);
  });

  test('changes ambiance as soon as the scene changes', () async {
    final music = controller();
    await music.unlock();
    await music.setMood(MusicMood.tavern);

    expect(fake.played, [
      MusicMood.exploration.assetPath,
      MusicMood.tavern.assetPath,
    ]);
    expect(
      container.read(musicControllerProvider).currentMood,
      MusicMood.tavern,
    );
  });

  test('combat music takes priority over narrative mood', () async {
    final music = controller();
    await music.unlock();
    await music.setMood(MusicMood.tavern);
    await music.enterCombat();
    await music.setMood(MusicMood.mystery);

    expect(
      container.read(musicControllerProvider).currentMood,
      MusicMood.combat,
    );
    expect(
      container.read(musicControllerProvider).previousMood,
      MusicMood.mystery,
    );
    expect(fake.played.last, MusicMood.combat.assetPath);
    expect(
      fake.played.where((path) => path == MusicMood.mystery.assetPath),
      isEmpty,
    );
  });

  test('restores tavern after combat in the tavern', () async {
    final music = controller();
    await music.unlock();
    await music.setMood(MusicMood.tavern);
    await music.enterCombat();
    await music.leaveCombat();

    expect(
      container.read(musicControllerProvider).currentMood,
      MusicMood.tavern,
    );
    expect(fake.played.last, MusicMood.tavern.assetPath);
  });

  test('shared scene keeps combat over a persisted tavern mood', () async {
    final music = controller();
    await music.unlock();
    await music.syncScene(
      narrativeMood: MusicMood.tavern,
      combatActive: true,
    );

    expect(
      container.read(musicControllerProvider).currentMood,
      MusicMood.combat,
    );
    await music.syncScene(
      narrativeMood: MusicMood.tavern,
      combatActive: false,
    );
    expect(
      container.read(musicControllerProvider).currentMood,
      MusicMood.tavern,
    );
  });

  test(
    'restores exploration when previous mood is missing after combat',
    () async {
      final music = controller();
      await music.unlock();
      await music.enterCombat();
      await music.leaveCombat();

      expect(
        container.read(musicControllerProvider).currentMood,
        MusicMood.exploration,
      );
    },
  );

  test('rejects an invalid IA music mood without crashing', () {
    final response = GameMasterResponse.fromJson({
      'narration': 'Un bruit etrange.',
      'actions': [
        {'type': 'set_music_mood', 'mood': 'boss_theme'},
        {
          'type': 'system_message',
          'payload': {'message': 'ok'},
        },
      ],
      'choices': <Map<String, dynamic>>[],
    });

    expect(response.actions.single.type, GameMasterActionType.systemMessage);
  });

  test('parses set_music_mood from top-level mood field', () {
    final response = GameMasterResponse.fromJson({
      'narration': 'La taverne est chaude.',
      'actions': [
        {'type': 'set_music_mood', 'mood': 'tavern'},
      ],
      'choices': <Map<String, dynamic>>[],
    });

    expect(response.actions.single.type, GameMasterActionType.setMusicMood);
    expect(response.actions.single.payload['mood'], 'tavern');
  });

  test('mute and volume update state and output', () async {
    final music = controller();
    music.setVolume(0.4);
    expect(container.read(musicControllerProvider).volume, 0.4);
    expect(container.read(musicControllerProvider).outputVolume, 0.4);

    music.toggleMute();
    expect(container.read(musicControllerProvider).isMuted, isTrue);
    expect(container.read(musicControllerProvider).outputVolume, 0);
    await Future<void>.delayed(Duration.zero);
    expect(fake.volume, 0);

    music.toggleMute();
    expect(container.read(musicControllerProvider).isMuted, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(fake.volume, 0.4);
  });
}
