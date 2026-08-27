import 'package:flutter/material.dart';

import 'breakpoints.dart';

extension AppLayoutContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  AppLayoutSize get layoutSize =>
      AppBreakpoints.sizeFor(screenSize.width, screenSize.height);

  bool get isCompact => layoutSize == AppLayoutSize.compact;

  bool get isMedium => layoutSize == AppLayoutSize.medium;

  bool get isExpanded => layoutSize == AppLayoutSize.expanded;

  T responsiveValue<T>({
    required T compact,
    T? medium,
    T? expanded,
  }) {
    return switch (layoutSize) {
      AppLayoutSize.compact => compact,
      AppLayoutSize.medium => medium ?? compact,
      AppLayoutSize.expanded => expanded ?? medium ?? compact,
    };
  }

  EdgeInsets get pagePadding {
    return switch (layoutSize) {
      AppLayoutSize.compact => const EdgeInsets.all(16),
      AppLayoutSize.medium => const EdgeInsets.all(20),
      AppLayoutSize.expanded =>
        const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    };
  }

  double get contentMaxWidth {
    return switch (layoutSize) {
      AppLayoutSize.compact => double.infinity,
      AppLayoutSize.medium => 840,
      AppLayoutSize.expanded => 1100,
    };
  }
}
