import 'package:dragons_lair/features/game_master/data/mock_game_master_repository.dart';
import 'package:dragons_lair/features/game_master/domain/game_master_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const repository = MockGameMasterRepository();

  test('mock GM narrates in english when the room locale is en', () async {
    final response = await repository.respond(
      const GameMasterInput(action: 'Attack', locale: 'en'),
    );
    expect(response.narration.contains('combat'), isTrue);
    expect(response.choices.first.label, 'Keep the pressure on');
  });

  test('mock GM keeps french when locale is fr', () async {
    final response = await repository.respond(
      const GameMasterInput(action: 'Attaque', locale: 'fr'),
    );
    expect(response.narration.contains('combat'), isTrue);
    expect(response.choices.first.label, 'Maintenir la pression');
  });
}
