import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../combat/presentation/combat_banner.dart';
import '../../combat/presentation/combat_providers.dart';
import '../../dice/domain/dice_roll_service.dart';
import '../../events/presentation/game_event_providers.dart';
import '../../game_master/domain/game_master_repository.dart';
import '../../game_master/presentation/game_master_controller.dart';
import '../../music/presentation/apply_music_from_response.dart';
import '../../players/domain/player.dart';
import '../../rooms/presentation/room_finish.dart';
import '../domain/player_action.dart';
import 'gm_choice_bar.dart';
import 'pending_ability_roll.dart';
import 'pending_roll_providers.dart';

class PendingPlayerChoiceNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setChoice(String? value) {
    state = value;
  }

  void clear() {
    state = null;
  }
}

final pendingPlayerChoiceProvider =
    NotifierProvider<PendingPlayerChoiceNotifier, String?>(
      PendingPlayerChoiceNotifier.new,
    );

class ActionPanel extends ConsumerStatefulWidget {
  const ActionPanel({
    required this.roomId,
    required this.currentPlayer,
    required this.players,
    this.paused = false,
    super.key,
  });

  final String roomId;
  final Player? currentPlayer;
  final List<Player> players;
  final bool paused;

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

  String _actionLabel(AppLocalizations l10n, PlayerActionType action) {
    return switch (action) {
      PlayerActionType.examine => l10n.actionExamine,
      PlayerActionType.interact => l10n.actionInteract,
      PlayerActionType.attack => l10n.actionAttack,
      PlayerActionType.defend => l10n.actionDefend,
      PlayerActionType.useItem => l10n.actionUseItem,
      PlayerActionType.free => l10n.actionFree,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pending = activePendingRoll(ref, widget.roomId);
    final combat = watchActiveCombat(ref, widget.roomId);
    final isMyRoll =
        pending != null &&
        widget.currentPlayer != null &&
        pending.playerId == widget.currentPlayer!.id;
    final canAct =
        widget.currentPlayer != null &&
        !_isSubmitting &&
        !isMyRoll &&
        !widget.paused;
    final choices =
        ref.watch(gameMasterControllerProvider).value?.choices ?? const [];

    ref.listen<String?>(pendingPlayerChoiceProvider, (previous, next) {
      final text = next?.trim();
      if (text == null || text.isEmpty) {
        return;
      }
      ref.read(pendingPlayerChoiceProvider.notifier).clear();
      _applyGmChoice(text);
    });

    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.paused)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.gamePaused,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.gold),
                ),
              ),
            CombatBanner(combat: combat),
            PendingAbilityRollBar(
              roomId: widget.roomId,
              currentPlayer: widget.currentPlayer,
              players: widget.players,
              pending: pending,
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final action in PlayerActionType.values)
                  ChoiceChip(
                    label: Text(_actionLabel(l10n, action)),
                    selected: _selectedAction == action,
                    onSelected: (_) {
                      setState(() => _selectedAction = action);
                    },
                  ),
              ],
            ),
            if (choices.isNotEmpty) ...[
              const SizedBox(height: 8),
              GmChoiceBar(
                choices: choices,
                enabled: canAct,
                onSelected: (choice) => _applyGmChoice(choice.playerCommand),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _actionController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (canAct) {
                  _submitAction();
                }
              },
              decoration: InputDecoration(
                hintText: l10n.actionHint,
                border: const OutlineInputBorder(),
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
                        : Text(l10n.sendToGm),
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

  Future<void> _applyGmChoice(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty ||
        widget.currentPlayer == null ||
        _isSubmitting ||
        widget.paused) {
      return;
    }
    _selectedAction = PlayerActionType.free;
    _actionController.text = trimmed;
    await _submitAction();
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

      final response = await ref
          .read(gameMasterControllerProvider.notifier)
          .submit(
            GameMasterInput(
              roomId: widget.roomId,
              playerId: player.id,
              playerName: player.figurineName,
              action: content,
              players: widget.players.map(toGameMasterPlayerContext).toList(),
              enemies: enemiesForRoom(ref, widget.roomId),
              recentEvents: recentEventsForRoom(ref, widget.roomId),
              combat: toGameMasterCombat(readActiveCombat(ref, widget.roomId)),
              locale: localeForRoom(ref, widget.roomId),
            ),
          );
      if (!AppConfig.isGameMasterRemote) {
        ref
            .read(pendingAbilityRollProvider.notifier)
            .setRoll(pendingRollFromResponse(response));
      }
      applyLocalCombatFromResponse(ref: ref, response: response);
      applyMusicFromResponse(ref: ref, response: response);
      await applyLocalFinishFromResponse(
        ref: ref,
        roomId: widget.roomId,
        response: response,
      );

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
      await ref
          .read(gameEventRepositoryProvider)
          .createAction(
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
}
