import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 全局字体与文本样式。
///
/// 对齐 PRD 第 11.2 章「字体」与原型 v5：
/// - 标题使用**手写体**（Ma Shan Zheng），传达手写日记的温度；
/// - 正文保持系统字体——手写体在长段落与小字号下可读性明显下降，
///   而日记的正文是用户自己要反复回看的内容；
/// - 字号满足无障碍可调节需求（PRD 第 10 章），全部页面在 2× 缩放下零溢出。
///
/// 字体文件与许可见 `assets/fonts/README.md`。
abstract final class AppTypography {
  /// 手写体家族名。与 `pubspec.yaml` 的 `fonts:` 声明保持一致。
  static const String handFamily = 'MaShanZheng';

  /// 标题强调字重。
  ///
  /// 手写体本身笔画粗壮，再叠加粗字重会糊成一团，因此这里刻意用正常字重。
  static const FontWeight _headingWeight = FontWeight.w400;

  static const TextTheme _base = TextTheme(
    // 花园大标题：手写体
    displaySmall: TextStyle(
      fontSize: 34,
      height: 1.4,
      fontWeight: _headingWeight,
      fontFamily: handFamily,
      color: AppColors.inkPrimary,
    ),
    // 页面标题：手写体
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.4,
      fontWeight: _headingWeight,
      fontFamily: handFamily,
      color: AppColors.inkPrimary,
    ),
    // 卡片标题 / 区块标题：手写体
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.45,
      fontWeight: _headingWeight,
      fontFamily: handFamily,
      color: AppColors.inkPrimary,
    ),
    // 列表项标题：系统字体（它常与正文并排，混用会显得跳）
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.45,
      fontWeight: FontWeight.w600,
      color: AppColors.inkPrimary,
    ),
    // 正文
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.65,
      color: AppColors.inkPrimary,
    ),
    // 次级正文 / 记录内容
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 1.65,
      color: AppColors.inkSecondary,
    ),
    // 说明文案
    bodySmall: TextStyle(
      fontSize: 13,
      height: 1.6,
      color: AppColors.inkSecondary,
    ),
    // 按钮文字：手写体，与标题同一气质
    labelLarge: TextStyle(
      fontSize: 18,
      height: 1.4,
      fontWeight: _headingWeight,
      fontFamily: handFamily,
      color: AppColors.inkInverse,
    ),
    // 标签 / 角标
    labelMedium: TextStyle(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: AppColors.inkSecondary,
    ),
    // 极小辅助文字（时间戳、计数）
    //
    // 用 inkSecondary 而不是 inkTertiary：时间戳与计数是有信息量的，
    // 而 inkTertiary 只有约 3:1，只适合禁用态与纯装饰。
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.4,
      color: AppColors.inkSecondary,
    ),
  );

  /// 完整 [TextTheme]。手写体通过在样式上直接指定 `fontFamily` 生效，
  /// 因此这里无需再整体 `apply`。
  static TextTheme build() => _base;
}
