import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/core/theme/app_colors.dart';
import 'package:mood_garden/core/theme/app_typography.dart';

/// 色彩对比度测试（PRD 第 10 章无障碍）。
///
/// > 色彩对比度设计需照顾色弱 / 色盲用户的可读性与可辨识度需求。
///
/// 「对比度够不够」是可以算出来的，所以这里不靠肉眼评审，而是按
/// WCAG 2.1 的相对亮度公式逐对断言。任何一次随手调色都会被这组测试拦下。
///
/// 阈值取 **4.5:1**（AA 级、正文大小文字）。项目里唯一允许低于它的是
/// [AppColors.inkTertiary]，因为它只用于禁用态与纯装饰——
/// 如果它也变得清晰可读，「禁用」看起来就会像「可用」。
void main() {
  /// WCAG 相对亮度。
  double luminance(Color color) {
    double channel(double value) {
      final v = value;
      return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
    }

    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// 两色的对比度。
  double contrast(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 断言这一对达到 AA。
  void expectAA(Color foreground, Color background, String label) {
    final ratio = contrast(foreground, background);
    expect(
      ratio,
      greaterThanOrEqualTo(4.5),
      reason: '$label 的对比度只有 ${ratio.toStringAsFixed(2)}:1，低于 AA 要求的 4.5:1',
    );
  }

  group('主题文字在其底色上达到 AA', () {
    test('正文类文字压在奶油白底上', () {
      final theme = AppTypography.build();

      expectAA(theme.displaySmall!.color!, AppColors.creamWhite, 'displaySmall');
      expectAA(theme.headlineMedium!.color!, AppColors.creamWhite, 'headlineMedium');
      expectAA(theme.titleLarge!.color!, AppColors.creamWhite, 'titleLarge');
      expectAA(theme.titleMedium!.color!, AppColors.creamWhite, 'titleMedium');
      expectAA(theme.bodyLarge!.color!, AppColors.creamWhite, 'bodyLarge');
      expectAA(theme.bodyMedium!.color!, AppColors.creamWhite, 'bodyMedium');
      expectAA(theme.bodySmall!.color!, AppColors.creamWhite, 'bodySmall');
      expectAA(theme.labelMedium!.color!, AppColors.creamWhite, 'labelMedium');
    });

    test('极小辅助文字也要读得清（时间戳、计数）', () {
      final theme = AppTypography.build();

      expectAA(theme.labelSmall!.color!, AppColors.creamWhite, 'labelSmall');
      // 它也常用在卡片底色上
      expectAA(theme.labelSmall!.color!, AppColors.creamSoft, 'labelSmall / creamSoft');
    });
  });

  group('强调色作为文字时达到 AA', () {
    test('暖橘黄系', () {
      // 这四种底色上都会出现暖色文字
      expectAA(AppColors.warmApricotDeep, AppColors.creamWhite, '暖色文字 / 奶油白');
      expectAA(AppColors.warmApricotDeep, AppColors.warmApricotTint, '暖色文字 / 暖色浅底');
      expectAA(AppColors.warmApricotDeep, AppColors.warmApricotSoft, '暖色文字 / 暖色标签底');
    });

    test('雾雾灰粉系', () {
      expectAA(AppColors.mistyRoseDeep, AppColors.creamWhite, '灰粉文字 / 奶油白');
      expectAA(AppColors.mistyRoseDeep, AppColors.mistyRoseTint, '灰粉文字 / 纸卷底');
      expectAA(AppColors.mistyRoseDeep, AppColors.mistyRoseSoft, '灰粉文字 / 标签底');
    });

    test('鼠尾草绿系', () {
      expectAA(AppColors.sageGreenDeep, AppColors.creamWhite, '绿色文字 / 奶油白');
      expectAA(AppColors.sageGreenDeep, AppColors.sageGreenTint, '绿色文字 / 花园底');
      expectAA(AppColors.sageGreenDeep, AppColors.sageGreenSoft, '绿色文字 / 标签底');
    });

    test('灰烬封条：那句「已转化为养分」必须看得清', () {
      expectAA(AppColors.ash, AppColors.ashSoft, '封条文字 / 封条底');
      expectAA(AppColors.ash, AppColors.creamWhite, '封条文字 / 奶油白');
    });
  });

  group('按钮与主色块上的文字达到 AA', () {
    test('暖橘黄主色块上的深色文字', () {
      // 这一条是修复前最容易出问题的地方：
      // 奶油白压在暖橘黄上只有 1.96:1
      expectAA(AppColors.inkPrimary, AppColors.warmApricot, '按钮文字 / 主色');
    });

    test('点燃按钮走到满进度时的底色仍能承住深色文字', () {
      // 底色是 mistyRoseSoft 向 flame 混 35%，这里按同一公式算出实际色值再断言。
      // 直接断言「深色压在纯火苗色上」是不对的：底色根本不会走到那么深。
      final worstCase = Color.lerp(
        AppColors.mistyRoseSoft,
        AppColors.flame,
        0.35,
      )!;
      expectAA(AppColors.inkPrimary, worstCase, '按钮文字 / 满进度底色');
    });
  });

  group('inkTertiary 的例外是刻意的', () {
    test('它确实低于 AA，因此只能用于禁用态与纯装饰', () {
      final ratio = contrast(AppColors.inkTertiary, AppColors.creamWhite);

      expect(
        ratio,
        lessThan(4.5),
        reason: '如果它达到了 AA，禁用态看起来就会像可用态——'
            '这条断言的价值在于提醒：不要拿它去写需要读的内容',
      );
    });
  });
}
