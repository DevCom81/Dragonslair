import 'package:flutter/material.dart';

import 'breakpoints.dart';
import 'responsive_value.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.compact,
    this.medium,
    this.expanded,
    super.key,
  });

  final Widget compact;
  final Widget? medium;
  final Widget? expanded;

  @override
  Widget build(BuildContext context) {
    return switch (context.layoutSize) {
      AppLayoutSize.compact => compact,
      AppLayoutSize.medium => medium ?? compact,
      AppLayoutSize.expanded => expanded ?? medium ?? compact,
    };
  }
}

class ContentConstraint extends StatelessWidget {
  const ContentConstraint({
    required this.child,
    this.maxWidth,
    super.key,
  });

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? context.contentMaxWidth,
        ),
        child: child,
      ),
    );
  }
}
