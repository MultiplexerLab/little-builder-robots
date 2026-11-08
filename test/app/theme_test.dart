import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/widgets/chunky_button.dart';

void main() {
  test('DES-01: colour tokens match the style guide', () {
    expect(AppColors.navy, const Color(0xFF1E2A4A));
    expect(AppColors.sky, const Color(0xFFDFF1FF));
    expect(AppColors.sunny, const Color(0xFFFFC93C));
    expect(AppColors.danger, const Color(0xFFB23A1E));
  });

  test('DES-03: target sizes follow NFR-05', () {
    expect(AppSizes.childTarget, 64);
    expect(AppSizes.childPrimary, 96);
    expect(AppSizes.grownUpsTarget, 48);
    expect(AppSizes.targetSpacing, 16);
  });

  test('DES-02: type scale', () {
    expect(AppText.display.fontSize, 50);
    expect(AppText.display.fontWeight, FontWeight.w700);
    expect(AppText.body.fontWeight, FontWeight.w500);
    expect(AppText.label.fontWeight, FontWeight.w600);
    expect(AppTheme.grownUps().textTheme.bodyLarge!.fontFamily, 'NunitoSans');
  });

  Widget host(ChunkyButtonStyle style) => MaterialApp(
    theme: AppTheme.child(),
    home: Scaffold(
      body: Center(
        child: ChunkyButton(label: 'Go', style: style, onPressed: () {}),
      ),
    ),
  );

  testWidgets('primary button is at least 96 pt tall', (tester) async {
    await tester.pumpWidget(host(ChunkyButtonStyle.primary));
    final size = tester.getSize(find.byType(AnimatedContainer));
    expect(size.height, greaterThanOrEqualTo(AppSizes.childPrimary));
  });

  testWidgets('secondary button is at least 64 pt tall', (tester) async {
    await tester.pumpWidget(host(ChunkyButtonStyle.secondary));
    final size = tester.getSize(find.byType(AnimatedContainer));
    expect(size.height, greaterThanOrEqualTo(AppSizes.childTarget));
    expect(size.width, greaterThanOrEqualTo(AppSizes.childTarget));
  });
}
