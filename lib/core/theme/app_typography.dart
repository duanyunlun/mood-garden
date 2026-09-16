import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 全局字体与文本样式。
///
/// 对齐 PRD 第 11.2 章「字体」：
/// - 全局采用圆润、亲和力强的字体，避免锐利、冷硬的字体风格；
/// - 标题字号适度加大，突出温暖治愈的视觉基调；
/// - 正文字号需满足无障碍可调节需求（PRD 第 10 章「无障碍」）。
///
/// 实现说明：骨架期未内置字体文件，走系统默认字体栈。
/// 正式设计定稿后，可在此处替换为圆体（如「阿里巴巴普惠体」「思源柔黑」等
/// 可商用字体），只需修改 [fontFamily] 一处。
abstract final class AppTypography {
  /// 全局字体族。`null` 表示使用系统默认字体栈。
  ///
  /// 设计定稿后替换为圆体字体名，并在 `pubspec.yaml` 的 `fonts:` 段注册字体文件。
  static const String? fontFamily = null;

  /// 标题强调字重。圆润字体通常不需要过重的字重即可保持亲和力。
  static const FontWeight _headingWeight = FontWeight.w600;

  static const TextTheme _base = TextTheme(
    // 花园首页大标题 / 空态主标题
    displaySmall: TextStyle(
      fontSize: 32,
      height: 1.35,
      fontWeight: _headingWeight,
      color: AppColors.inkPrimary,
    ),
    // 页面标题
    headlineMedium: TextStyle(
      fontSize: 26,
      height: 1.35,
      fontWeight: _headingWeight,
      color: AppColors.inkPrimary,
    ),
    // 卡片标题 / 区块标题
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.4,
      fontWeight: _headingWeight,
      color: AppColors.inkPrimary,
    ),
    // 列表项标题
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.45,
      fontWeight: FontWeight.w600,
      color: AppColors.inkPrimary,
    ),
    // 正文
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.6,
      color: AppColors.inkPrimary,
    ),
    // 次级正文 / 记录内容
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 1.6,
      color: AppColors.inkSecondary,
    ),
    // 说明文案
    bodySmall: TextStyle(
      fontSize: 13,
      height: 1.55,
      color: AppColors.inkSecondary,
    ),
    // 按钮文字
    labelLarge: TextStyle(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: AppColors.inkInverse,
    ),
    // 标签 / 角标
    labelMedium: TextStyle(
      fontSize: 13,
      height: 1.35,
      fontWeight: FontWeight.w500,
      color: AppColors.inkSecondary,
    ),
    // 极小辅助文字（收集进度、时间戳）
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.35,
      color: AppColors.inkTertiary,
    ),
  );

  /// 生成绑定字体族后的完整 [TextTheme]。
  static TextTheme build() {
    if (fontFamily == null) {
      return _base;
    }
    return _base.apply(fontFamily: fontFamily);
  }
}
