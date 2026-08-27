import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/l10n_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../combat/presentation/combat_providers.dart';
import '../../dice/domain/dice_roll_service.dart';
import '../../enemies/domain/enemy.dart';
import '../../enemies/presentation/enemy_providers.dart';
import '../../events/domain/game_event.dart';
import '../../events/presentation/game_event_providers.dart';
import '../../game_master/domain/game_master_repository.dart';
import '../../game_master/domain/game_master_response.dart';
import '../../game_master/presentation/game_master_controller.dart';
import '../../players/domain/player.dart';
import '../../rooms/domain/room_locale.dart';
import '../../rooms/presentation/room_finish.dart';
import '../../rooms/presentation/room_providers.dart';

const abilityKeys = {
  'strength',
  'dexterity',
  'constitution',
  'intelligence',
  'wisdom',
  'charisma',
};

class PendingAbilityRoll {
  const PendingAbilityRoll({
    required this.playerId,
    required this.abilityKey,
    required this.dc,
    this.id,
    this.reason = '',
    this.status = PendingRollStatus.pending,
    this.result,
    this.modifier,
    this.total,
    this.success,
  });

  final String? id;
  final String playerId;
  final String abilityKey;
  final int dc;
  final String reason;
  final PendingRollStatus status;
  final int? result;
  final int? modifier;
  final int? total;
  final bool? success;

  bool get isOpen => status == PendingRollStatus.pending;

  static PendingAbilityRoll? tryParse(Map<String, dynamic> payload) {
    final playerId = payload['player_id'] as String? ??
        payload['target_id'] as String? ??
        payload['target'] as String?;
    final ability = payload['ability'] as String? ?? payload['stat'] as String?;
    final dc = (payload['dc'] as num?)?.toInt() ??
        (payload['difficulty'] as num?)?.toInt();
    if (playerId == null ||
        ability == null ||
        !abilityKeys.contains(ability) ||
        dc == null) {
      return null;
    }
    final clampedDc = dc < 5 ? 5 : (dc > 25 ? 25 : dc);
    return PendingAbilityRoll(
      id: payload['id'] as String?,
      playerId: playerId,
      abilityKey: ability,
      dc: clampedDc,
      reason: payload['reason'] as String? ?? '',
      status: PendingRollStatus.fromJson(payload['status']),
      result: (payload['result'] as num?)?.toInt(),
      modifier: (payload['modifier'] as num?)?.toInt(),
      total: (payload['total'] as num?)?.toInt(),
      success: payload['success'] as bool?,
    );
  }

  factory PendingAbilityRoll.fromJson(Map<String, dynamic> json) {
    final parsed = tryParse(json);
    if (parsed == null) {
      throw ArgumentError('Invalid pending roll row.');
    }
    return parsed;
  }
}

enum PendingRollStatus {
  pending,
  resolved,
  cancelled;

  static PendingRollStatus fromJson(Object? value) {
    return switch (value) {
      'resolved' => PendingRollStatus.resolved,
      'cancelled' => PendingRollStatus.cancelled,
      _ => PendingRollStatus.pending,
    };
  }
}

class PendingAbilityRollNotifier extends Notifier<PendingAbilityRoll?> {
  @override
  PendingAbilityRoll? build() => null;

  void setRoll(PendingAbilityRoll? roll) {
    state = roll;
  }

  void clear() {
    state = null;
  }
}

final pendingAbilityRollProvider =
    NotifierProvider<PendingAbilityRollNotifier, PendingAbilityRoll?>(
  PendingAbilityRollNotifier.new,
);

PendingAbilityRoll? pendingRollFromResponse(GameMasterResponse response) {
  for (final action in response.actions) {
    if (action.type != GameMasterActionType.requestRoll) {
      continue;
    }
    final parsed = PendingAbilityRoll.tryParse(action.payload);
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}

List<GameMasterRecentEvent> recentEventsForRoom(WidgetRef ref, String roomId) {
  final recent =
      ref.read(roomEventsProvider(roomId)).value ?? const <GameEvent>[];
  final slice = recent.length <= 8 ? recent : recent.sublist(recent.length - 8);
  return slice
      .map(
        (event) => GameMasterRecentEvent(
          type: event.type.toJson(),
          content: event.content,
        ),
      )
      .toList();
}

GameMasterPlayerContext toGameMasterPlayerContext(Player player) {
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
    strength: player.stats.strength,
    dexterity: player.stats.dexterity,
    constitution: player.stats.constitution,
    intelligence: player.stats.intelligence,
    wisdom: player.stats.wisdom,
    charisma: player.stats.charisma,
    effects: player.effects.map((effect) => effect.toJson()).toList(),
  );
}

GameMasterEnemyContext toGameMasterEnemyContext(Enemy enemy) {
  return GameMasterEnemyContext(
    id: enemy.id,
    name: enemy.name,
    enemyType: enemy.enemyType,
    hp: enemy.hp,
    maxHp: enemy.maxHp,
    status: enemy.status.toJson(),
    position: GameMasterPosition(
      x: enemy.positionX,
      y: enemy.positionY,
    ),
  );
}

List<GameMasterEnemyContext> enemiesForRoom(WidgetRef ref, String roomId) {
  final enemies = ref.read(roomEnemiesProvider(roomId)).value ?? const [];
  return enemies.map(toGameMasterEnemyContext).toList();
}

String localeForRoom(WidgetRef ref, String roomId) {
  return normalizeRoomLocale(ref.read(roomProvider(roomId)).value?.locale);
}

Future<void> resolvePendingAbilityRoll({
  required WidgetRef ref,
  required String roomId,
  required Player player,
  required List<Player> players,
  required PendingAbilityRoll pending,
  required String successLabel,
  required String failureLabel,
}) async {
  if (pending.playerId != player.id) {
    return;
  }

  final dice = DiceRollService();
  final roll = dice.roll(count: 1, sides: 20).values.first;
  final pendingId = pending.id;

  if (pendingId != null && AppConfig.isGameMasterRemote) {
    await ref.read(gameMasterControllerProvider.notifier).resolveRoll(
          ResolveRollInput(
            pendingRollId: pendingId,
            raw: roll,
            playerName: player.figurineName,
            players: players.map(toGameMasterPlayerContext).toList(),
            enemies: enemiesForRoom(ref, roomId),
            recentEvents: recentEventsForRoom(ref, roomId),
            combat: toGameMasterCombat(readActiveCombat(ref, roomId)),
          ),
        );
    return;
  }

  final modifier = player.effectiveModifierFor(pending.abilityKey);
  final total = roll + modifier;
  final success = total >= pending.dc;
  final outcome = success ? successLabel : failureLabel;
  final sign = modifier >= 0 ? '+$modifier' : '$modifier';
  final content =
      '${player.figurineName} : 1d20=$roll $sign = $total vs DD ${pending.dc}. $outcome';

  final events = ref.read(gameEventRepositoryProvider);
  await events.createAction(
    roomId: roomId,
    playerId: player.id,
    content: content,
  );

  try {
    final response = await ref.read(gameMasterControllerProvider.notifier).submit(
          GameMasterInput(
            roomId: roomId,
            playerId: player.id,
            playerName: player.figurineName,
            action: content,
            players: players.map(toGameMasterPlayerContext).toList(),
            enemies: enemiesForRoom(ref, roomId),
            recentEvents: recentEventsForRoom(ref, roomId),
            combat: toGameMasterCombat(readActiveCombat(ref, roomId)),
            locale: localeForRoom(ref, roomId),
          ),
        );
    ref.read(pendingAbilityRollProvider.notifier).setRoll(
          pendingRollFromResponse(response),
        );
    applyLocalCombatFromResponse(ref: ref, response: response);
    await applyLocalFinishFromResponse(
      ref: ref,
      roomId: roomId,
      response: response,
    );
  } catch (_) {
    ref.read(pendingAbilityRollProvider.notifier).clear();
    rethrow;
  }
}

class PendingAbilityRollBar extends ConsumerStatefulWidget {
  const PendingAbilityRollBar({
    required this.roomId,
    required this.currentPlayer,
    required this.players,
    this.pending,
    super.key,
  });

  final String roomId;
  final Player? currentPlayer;
  final List<Player> players;
  final PendingAbilityRoll? pending;

  @override
  ConsumerState<PendingAbilityRollBar> createState() =>
      _PendingAbilityRollBarState();
}

class _PendingAbilityRollBarState extends ConsumerState<PendingAbilityRollBar> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final pending = widget.pending;
    if (pending == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final player = widget.currentPlayer;
    final isMine = player != null && pending.playerId == player.id;
    final gmBusy = ref.watch(gameMasterControllerProvider).isLoading;

    if (!isMine) {
      final name = widget.players
              .where((candidate) => candidate.id == pending.playerId)
              .map((candidate) => candidate.figurineName)
              .firstOrNull ??
          l10n.pendingRollUnknownPlayer;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          l10n.pendingRollWaiting(name),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
        ),
      );
    }

    final ability = localizedStatLabel(l10n, pending.abilityKey);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.pendingRollBody(ability, pending.dc),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.gold,
                ),
          ),
          if (pending.reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                pending.reason,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: (_busy || gmBusy) ? null : _resolve,
            child: _busy || gmBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.pendingRollCta),
          ),
        ],
      ),
    );
  }

  Future<void> _resolve() async {
    final player = widget.currentPlayer;
    final pending = widget.pending;
    if (player == null || pending == null) {
      return;
    }

    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      await resolvePendingAbilityRoll(
        ref: ref,
        roomId: widget.roomId,
        player: player,
        players: widget.players,
        pending: pending,
        successLabel: l10n.pendingRollSuccess,
        failureLabel: l10n.pendingRollFailure,
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
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
