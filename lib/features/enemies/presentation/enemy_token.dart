import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/enemy.dart';

class EnemyToken extends StatelessWidget {
  const EnemyToken({
    required this.enemy,
    required this.size,
    this.sprite,
    super.key,
  });

  final Enemy enemy;
  final double size;
  final Widget? sprite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final defeated = enemy.isDefeated;
    final initial = enemy.name.trim().isEmpty
        ? '?'
        : enemy.name.trim().characters.first.toUpperCase();

    return Opacity(
      opacity: defeated ? 0.45 : 1,
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            sprite ??
                _GeneratedEnemyMark(
                  size: size,
                  initial: initial,
                  defeated: defeated,
                ),
            const SizedBox(height: 2),
            Text(
              enemy.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.cream,
                    decoration: defeated ? TextDecoration.lineThrough : null,
                  ),
            ),
            if (defeated)
              Text(
                l10n.enemyDefeated,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.danger,
                    ),
              )
            else
              _EnemyHpBar(ratio: enemy.hpRatio, hp: enemy.hp, maxHp: enemy.maxHp),
          ],
        ),
      ),
    );
  }
}

class _GeneratedEnemyMark extends StatelessWidget {
  const _GeneratedEnemyMark({
    required this.size,
    required this.initial,
    required this.defeated,
  });

  final double size;
  final String initial;
  final bool defeated;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.danger.withValues(alpha: 0.85),
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: defeated
              ? Icon(Icons.close, color: AppColors.cream, size: size * 0.45)
              : Text(
                  initial,
                  style: TextStyle(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w700,
                    fontSize: size * 0.38,
                  ),
                ),
        ),
      ),
    );
  }
}

class _EnemyHpBar extends StatelessWidget {
  const _EnemyHpBar({
    required this.ratio,
    required this.hp,
    required this.maxHp,
  });

  final double ratio;
  final int hp;
  final int maxHp;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$hp / $maxHp',
      child: SizedBox(
        height: 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 4,
            backgroundColor: AppColors.surface,
            color: ratio > 0.35 ? AppColors.danger : const Color(0xFF5A1F1F),
          ),
        ),
      ),
    );
  }
}
