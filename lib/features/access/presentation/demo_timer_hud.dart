import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/game_access.dart';
import 'access_providers.dart';

class DemoTimerBanner extends ConsumerStatefulWidget {
  const DemoTimerBanner({
    this.roomPaused = false,
    this.onUnlock,
    super.key,
  });

  final bool roomPaused;
  final VoidCallback? onUnlock;

  @override
  ConsumerState<DemoTimerBanner> createState() => _DemoTimerBannerState();
}

class _DemoTimerBannerState extends ConsumerState<DemoTimerBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final session = ref.read(currentDemoSessionProvider).value;
      if (session == null || session.isPaused || widget.roomPaused) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentDemoSessionProvider).value;
    final remaining = session?.remainingPlayTime() ?? DemoSession.playBudget;
    final frozen = widget.roomPaused || (session?.isPaused ?? false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Text(
                frozen
                    ? l10n.demoTimerPaused(_formatClock(remaining))
                    : l10n.demoTimer(_formatClock(remaining)),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.gold,
                    ),
              ),
              Text(
                l10n.demoKeepOnUnlock,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.onUnlock != null)
                TextButton(
                  onPressed: widget.onUnlock,
                  child: Text(l10n.unlockDragonsLair),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatClock(Duration remaining) {
    final seconds = remaining.inSeconds.clamp(0, DemoSession.playBudget.inSeconds);
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }
}
