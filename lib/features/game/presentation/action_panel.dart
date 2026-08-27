import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../dice/domain/dice_roll_service.dart';
import '../../events/presentation/game_event_providers.dart';
import '../../game_master/domain/game_master_repository.dart';
import '../../game_master/presentation/game_master_controller.dart';
import '../../players/domain/player.dart';
import '../domain/player_action.dart';

class ActionPanel extends ConsumerStatefulWidget {
  const ActionPanel({
    required this.roomId,
    required this.currentPlayer,
    required this.players,
    super.key,
  });

  final String roomId;
  final Player? currentPlayer;
  final List<Player> players;

  @override
  ConsumerState<ActionPanel> createState() => _ActionPanelState();
}

class _ActionPanelState extends ConsumerState<ActionPanel> {
  final _actionController = TextEditingController();
  final _diceService = DiceRollService();
  PlayerActionType _selectedAction = PlayerActionType.examine;
  var _isSubmitting = false;

  @override
  void dispose() {
    _actionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAct = widget.currentPlayer != null && !_isSubmitting;

    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final action in PlayerActionType.values)
                  ChoiceChip(
                    label: Text(action.label),
                    selected: _selectedAction == action,
                    onSelected: (_) {
                      setState(() => _selectedAction = action);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _actionController,
              decoration: const InputDecoration(
                hintText: 'Precise ton action...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: canAct ? _submitAction : null,
                    child: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Envoyer au MJ'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: canAct ? () => _rollDice(20) : null,
                  child: const Text('d20'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: canAct ? () => _rollDice(6) : null,
                  child: const Text('d6'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAction() async {
    final player = widget.currentPlayer;
    if (player == null) {
      return;
    }

    final content = _selectedAction.format(_actionController.text);
    setState(() => _isSubmitting = true);

    try {
      final events = ref.read(gameEventRepositoryProvider);
      await events.createAction(
        roomId: widget.roomId,
        playerId: player.id,
        content: '${player.figurineName} : $content',
      );

      final response = await ref.read(gameMasterControllerProvider.notifier).submit(
            GameMasterInput(
              roomId: widget.roomId,
              playerId: player.id,
              playerName: player.figurineName,
              action: content,
              players: widget.players.map(_toGameMasterPlayer).toList(),
            ),
          );

      if (response.choices.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Choix MJ: ${response.choices.first.label}')),
        );
      }

      _actionController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _rollDice(int sides) async {
    final player = widget.currentPlayer;
    if (player == null) {
      return;
    }

    final roll = _diceService.roll(count: 1, sides: sides);
    try {
      await ref.read(gameEventRepositoryProvider).createAction(
            roomId: widget.roomId,
            playerId: player.id,
            content: '${player.figurineName} lance ${roll.label}',
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  GameMasterPlayerContext _toGameMasterPlayer(Player player) {
    return GameMasterPlayerContext(
      id: player.id,
      name: player.figurineName,
      hp: player.hp,
      figurineId: player.figurineId,
      position: GameMasterPosition(
        x: player.positionX,
        y: player.positionY,
      ),
      inventory: player.inventory.map((item) => item.toJson()).toList(),
    );
  }
}
