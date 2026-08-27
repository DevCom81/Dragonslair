import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/l10n_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../combat/presentation/combat_providers.dart';
import '../../events/presentation/game_event_providers.dart';
import '../../game_master/domain/game_master_repository.dart';
import '../../game_master/presentation/game_master_controller.dart';
import '../../players/domain/inventory_item.dart';
import '../../players/domain/inventory_rules.dart';
import '../../players/domain/player.dart';
import '../../players/presentation/player_providers.dart';
import 'pending_ability_roll.dart';

class InGameInventoryView extends ConsumerStatefulWidget {
  const InGameInventoryView({
    required this.roomId,
    required this.playerId,
    super.key,
  });

  final String roomId;
  final String playerId;

  @override
  ConsumerState<InGameInventoryView> createState() => _InGameInventoryViewState();
}

class _InGameInventoryViewState extends ConsumerState<InGameInventoryView> {
  String? _busyItemId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final players = ref.watch(roomPlayersProvider(widget.roomId)).value ?? const [];
    Player? player;
    for (final candidate in players) {
      if (candidate.id == widget.playerId) {
        player = candidate;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.inGameInventoryTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.gold,
                ),
          ),
        ),
        Expanded(
          child: player == null || player.inventory.isEmpty
              ? Center(child: Text(l10n.emptyInventory))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: player.inventory.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = player!.inventory[index];
                    return _ItemTile(
                      item: item,
                      busy: _busyItemId == item.id,
                      onEquip: isEquippable(item)
                          ? () => _setEquipped(player!, item, !item.equipped)
                          : null,
                      onUse: isPotion(item) || isScroll(item)
                          ? () => _useItem(player!, players, item)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _setEquipped(
    Player player,
    InventoryItem item,
    bool equipped,
  ) async {
    setState(() => _busyItemId = item.id);
    final l10n = AppLocalizations.of(context);
    try {
      final next = setEquipped(
        inventory: player.inventory,
        itemId: item.id,
        equipped: equipped,
      );
      await ref.read(playerRepositoryProvider).patchOwnPlayer(
            playerId: player.id,
            inventory: next,
          );
      await ref.read(gameEventRepositoryProvider).createSystem(
            roomId: widget.roomId,
            content: equipped
                ? '${player.figurineName} : ${l10n.itemEquip} ${item.name}'
                : '${player.figurineName} : ${l10n.itemUnequip} ${item.name}',
          );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _busyItemId = null);
      }
    }
  }

  Future<void> _useItem(
    Player player,
    List<Player> players,
    InventoryItem item,
  ) async {
    setState(() => _busyItemId = item.id);
    try {
      if (isPotion(item)) {
        await _usePotion(player, item);
      } else {
        await _useScroll(player, players, item);
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _busyItemId = null);
      }
    }
  }

  Future<void> _usePotion(Player player, InventoryItem item) async {
    final result = consumePotion(inventory: player.inventory, itemId: item.id);
    if (result.heal <= 0) {
      return;
    }
    final nextHp = (player.hp + result.heal).clamp(0, 100);
    await ref.read(playerRepositoryProvider).patchOwnPlayer(
          playerId: player.id,
          hp: nextHp,
          inventory: result.inventory,
        );
    await ref.read(gameEventRepositoryProvider).createSystem(
          roomId: widget.roomId,
          content:
              '${player.figurineName} : ${item.name} (+${result.heal} PV, ${player.hp} -> $nextHp)',
        );
  }

  Future<void> _useScroll(
    Player player,
    List<Player> players,
    InventoryItem item,
  ) async {
    final result = consumeScroll(inventory: player.inventory, itemId: item.id);
    if (result.effect != null) {
      await ref.read(playerRepositoryProvider).patchOwnPlayer(
            playerId: player.id,
            inventory: result.inventory,
            effects: upsertEffect(player.effects, result.effect!),
          );
      await ref.read(gameEventRepositoryProvider).createSystem(
            roomId: widget.roomId,
            content: '${player.figurineName} : ${item.name} (${result.effect!.name})',
          );
      return;
    }

    final l10n = AppLocalizations.of(context);
    final content = '${l10n.actionUseItem} : ${item.name}';
    await ref.read(gameEventRepositoryProvider).createAction(
          roomId: widget.roomId,
          playerId: player.id,
          content: '${player.figurineName} : $content',
        );
    final response =
        await ref.read(gameMasterControllerProvider.notifier).submit(
              GameMasterInput(
                roomId: widget.roomId,
                playerId: player.id,
                playerName: player.figurineName,
                action: content,
                players: players.map(toGameMasterPlayerContext).toList(),
                enemies: enemiesForRoom(ref, widget.roomId),
                recentEvents: recentEventsForRoom(ref, widget.roomId),
                combat: toGameMasterCombat(
                  readActiveCombat(ref, widget.roomId),
                ),
              ),
            );
    if (!AppConfig.isGameMasterRemote) {
      ref.read(pendingAbilityRollProvider.notifier).setRoll(
            pendingRollFromResponse(response),
          );
    }
    applyLocalCombatFromResponse(ref: ref, response: response);
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: AppColors.danger,
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.busy,
    required this.onEquip,
    required this.onUse,
  });

  final InventoryItem item;
  final bool busy;
  final VoidCallback? onEquip;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typeLabel = localizedItemType(l10n, item.type);
    final subtitle = [
      if (item.equipped) l10n.itemEquipped,
      if (item.description.isNotEmpty) item.description,
      if (typeLabel.isNotEmpty) typeLabel,
    ].join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.name),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
          trailing: Text(l10n.itemQuantity(item.quantity)),
        ),
        if (onEquip != null || onUse != null)
          Wrap(
            spacing: 8,
            children: [
              if (onEquip != null)
                OutlinedButton(
                  onPressed: busy ? null : onEquip,
                  child: Text(item.equipped ? l10n.itemUnequip : l10n.itemEquip),
                ),
              if (onUse != null)
                FilledButton(
                  onPressed: busy ? null : onUse,
                  child: Text(l10n.itemUse),
                ),
            ],
          ),
      ],
    );
  }
}
