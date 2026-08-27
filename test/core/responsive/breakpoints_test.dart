import 'package:dragons_lair/core/responsive/breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies width into compact medium expanded', () {
    expect(AppBreakpoints.sizeFor(390, 844), AppLayoutSize.compact);
    expect(AppBreakpoints.sizeFor(430, 932), AppLayoutSize.compact);
    expect(AppBreakpoints.sizeFor(768, 1024), AppLayoutSize.medium);
    expect(AppBreakpoints.sizeFor(1366, 768), AppLayoutSize.expanded);
    expect(AppBreakpoints.sizeFor(1920, 1080), AppLayoutSize.expanded);
  });

  test('short height stays compact even when width is medium', () {
    expect(AppBreakpoints.sizeFor(844, 390), AppLayoutSize.compact);
  });

  test('boundaries are exclusive of the next band', () {
    expect(AppBreakpoints.sizeFor(599, 800), AppLayoutSize.compact);
    expect(AppBreakpoints.sizeFor(600, 800), AppLayoutSize.medium);
    expect(AppBreakpoints.sizeFor(1023, 800), AppLayoutSize.medium);
    expect(AppBreakpoints.sizeFor(1024, 800), AppLayoutSize.expanded);
  });
}
