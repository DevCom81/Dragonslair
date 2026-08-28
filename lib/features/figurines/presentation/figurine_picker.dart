import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/figurine_definition.dart';
import 'figurine_sprite.dart';

class FigurinePickerGrid extends StatelessWidget {
  const FigurinePickerGrid({
    required this.selectedId,
    required this.onSelected,
    this.takenIds = const {},
    this.takenLabel,
    super.key,
  });

  final int? selectedId;
  final ValueChanged<int> onSelected;
  final Set<int> takenIds;
  final String? takenLabel;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.responsiveValue(
          compact: 3,
          medium: 4,
          expanded: 6,
        ),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: FigurineCatalog.count,
      itemBuilder: (context, index) {
        final figurine = FigurineCatalog.byId(index);
        final isTaken = takenIds.contains(figurine.id);
        return _FigurineCard(
          figurine: figurine,
          isTaken: isTaken,
          isSelected: selectedId == figurine.id,
          takenLabel: takenLabel,
          onTap: isTaken ? null : () => onSelected(figurine.id),
        );
      },
    );
  }
}

class _FigurineCard extends StatelessWidget {
  const _FigurineCard({
    required this.figurine,
    required this.isTaken,
    required this.isSelected,
    required this.onTap,
    this.takenLabel,
  });

  final FigurineDefinition figurine;
  final bool isTaken;
  final bool isSelected;
  final String? takenLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        color: isTaken ? AppColors.surface.withValues(alpha: 0.5) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? AppColors.gold : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: isTaken ? 0.35 : 1,
                child: FigurineSprite(figurine: figurine, size: 64),
              ),
              if (isTaken && takenLabel != null) ...[
                const SizedBox(height: 8),
                Text(
                  takenLabel!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
