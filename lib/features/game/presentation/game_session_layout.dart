import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';

class GameSessionLayout extends StatelessWidget {
  const GameSessionLayout({
    required this.board,
    required this.journal,
    required this.sheet,
    required this.inventory,
    required this.actions,
    required this.sheetLabel,
    required this.inventoryLabel,
    this.hud,
    super.key,
  });

  final Widget board;
  final Widget journal;
  final Widget sheet;
  final Widget inventory;
  final Widget actions;
  final String sheetLabel;
  final String inventoryLabel;
  final Widget? hud;

  @override
  Widget build(BuildContext context) {
    return switch (context.layoutSize) {
      AppLayoutSize.compact => _CompactGameLayout(
          board: board,
          actions: actions,
          hud: hud,
        ),
      AppLayoutSize.medium => _MediumGameLayout(
          board: board,
          journal: journal,
          actions: actions,
          hud: hud,
        ),
      AppLayoutSize.expanded => _ExpandedGameLayout(
          board: board,
          journal: journal,
          sheet: sheet,
          inventory: inventory,
          actions: actions,
          sheetLabel: sheetLabel,
          inventoryLabel: inventoryLabel,
        ),
    };
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.parchment,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

class _ScrollableActions extends StatelessWidget {
  const _ScrollableActions({
    required this.child,
    required this.maxHeightFactor,
  });

  final Widget child;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        (MediaQuery.sizeOf(context).height * maxHeightFactor).clamp(96.0, 320.0);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [child],
      ),
    );
  }
}

class _CompactGameLayout extends StatelessWidget {
  const _CompactGameLayout({
    required this.board,
    required this.actions,
    this.hud,
  });

  final Widget board;
  final Widget actions;
  final Widget? hud;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: board),
        ?hud,
        _ScrollableActions(maxHeightFactor: 0.42, child: actions),
      ],
    );
  }
}

class _MediumGameLayout extends StatelessWidget {
  const _MediumGameLayout({
    required this.board,
    required this.journal,
    required this.actions,
    this.hud,
  });

  final Widget board;
  final Widget journal;
  final Widget actions;
  final Widget? hud;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: board),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 2,
                child: _Panel(child: journal),
              ),
            ],
          ),
        ),
        ?hud,
        _ScrollableActions(maxHeightFactor: 0.38, child: actions),
      ],
    );
  }
}

class _ExpandedGameLayout extends StatelessWidget {
  const _ExpandedGameLayout({
    required this.board,
    required this.journal,
    required this.sheet,
    required this.inventory,
    required this.actions,
    required this.sheetLabel,
    required this.inventoryLabel,
  });

  final Widget board;
  final Widget journal;
  final Widget sheet;
  final Widget inventory;
  final Widget actions;
  final String sheetLabel;
  final String inventoryLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: board),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 2,
                child: _Panel(child: journal),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: _Panel(
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          tabs: [
                            Tab(text: sheetLabel),
                            Tab(text: inventoryLabel),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [sheet, inventory],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 3,
                child: _Panel(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [actions],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
