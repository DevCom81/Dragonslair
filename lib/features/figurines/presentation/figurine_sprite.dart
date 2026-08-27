import 'package:flutter/material.dart';

import '../domain/figurine_definition.dart';

class FigurineSprite extends StatelessWidget {
  const FigurineSprite({
    required this.figurine,
    this.size = 64,
    super.key,
  });

  final FigurineDefinition figurine;
  final double size;

  @override
  Widget build(BuildContext context) {
    final width = size;
    final height = size * 1.25;

    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: width * FigurineCatalog.columns,
          maxWidth: width * FigurineCatalog.columns,
          minHeight: height * FigurineCatalog.rows,
          maxHeight: height * FigurineCatalog.rows,
          child: Transform.translate(
            offset: Offset(
              -figurine.column * width,
              -figurine.row * height,
            ),
            child: Image.asset(
              FigurineCatalog.assetPath,
              width: width * FigurineCatalog.columns,
              height: height * FigurineCatalog.rows,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }
}
