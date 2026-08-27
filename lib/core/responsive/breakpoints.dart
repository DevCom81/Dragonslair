enum AppLayoutSize {
  compact,
  medium,
  expanded,
}

class AppBreakpoints {
  const AppBreakpoints._();

  static const compactMax = 600.0;
  static const mediumMax = 1024.0;

  /// Below this height, side-by-side shells overflow (phone landscape).
  static const shortMax = 560.0;

  static AppLayoutSize sizeFor(double width, [double height = double.infinity]) {
    if (height < shortMax) {
      return AppLayoutSize.compact;
    }
    if (width < compactMax) {
      return AppLayoutSize.compact;
    }
    if (width < mediumMax) {
      return AppLayoutSize.medium;
    }
    return AppLayoutSize.expanded;
  }
}
