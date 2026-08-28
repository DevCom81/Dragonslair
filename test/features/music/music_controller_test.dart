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

  @override
  Future<void> crossfadeTo({
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
  late DateTime now;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeMusicService();
    now = DateTime.utc(2026, 8, 28, 12);
    container = ProviderContainer(
      overrides: [
        musicServiceProvider.overrideWith((ref) => fake),
        musicClockProvider.overrideWith(
          (ref) =>
              () => now,
        ),
        musicNarrativeCooldownProvider.overrideWith(
          (ref) => const Duration(seconds: 60),
        ),
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

  test('changes ambiance after unlock', () async {
    final music = controller();
    await music.unlock();
    await music.setMood(MusicMood.exploration);
    now = now.add(const Duration(seconds: 61));
    await music.setMood(MusicMood.mystery);

    expect(fake.played, [
      MusicMood.exploration.assetPath,
      MusicMood.mystery.assetPath,
    ]);
    expect(
      container.read(musicControllerProvider).currentMood,
      MusicMood.mystery,
    );
    expect(
      container.read(musicControllerProvider).previousMood,
      MusicMood.exploration,
    );
  });

  test('combat music takes priority over narrative mood', () async {
    final music = controller();
    await music.unlock();
    await music.setMood(MusicMood.exploration);
    now = now.add(const Duration(seconds: 61));
    await music.enterCombat();
    await music.setMood(MusicMood.mystery);

    expect(
      container.read(musicControllerProvider).currentMood,
      MusicMood.combat,
    );
    expect(
      container.read(musicControllerProvider).previousMood,
      MusicMood.exploration,
    );
    expect(fake.played.last, MusicMood.combat.assetPath);
    expect(
      fake.played.where((path) => path == MusicMood.mystery.assetPath),
      isEmpty,
    );
  });

  test('restores previous ambiance after combat', () async {
    final music = controller();
    await music.unlock();
    await music.setMood(MusicMood.tension);
    now = now.add(const Duration(seconds: 61));
    await music.enterCombat();
    await music.leaveCombat();

    expect(
      container.read(musicControllerProvider).currentMood,
      MusicMood.tension,
    );
    expect(fake.played.last, MusicMood.tension.assetPath);
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

  test('narrative mood changes respect a 60s cooldown', () async {
    final music = controller();
    await music.unlock();
    await music.setMood(MusicMood.exploration);
    await music.setMood(MusicMood.mystery);

    expect(
      container.read(musicControllerProvider).currentMood,
      MusicMood.exploration,
    );

    now = now.add(const Duration(seconds: 59));
    await music.setMood(MusicMood.mystery);
    expect(
      container.read(musicControllerProvider).currentMood,
      MusicMood.exploration,
    );

    now = now.add(const Duration(seconds: 2));
    await music.setMood(MusicMood.mystery);
    expect(
      container.read(musicControllerProvider).currentMood,
      MusicMood.mystery,
    );
  });

  test('combat ignores the narrative cooldown', () async {
    final music = controller();
    await music.unlock();
    await music.setMood(MusicMood.exploration);
    await music.enterCombat();

    expect(
      container.read(musicControllerProvider).currentMood,
      MusicMood.combat,
    );
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
