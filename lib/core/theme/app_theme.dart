import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// 全局主题装配。
///
/// 对齐 PRD 第 11.3 章「插画与交互风格」：
/// - 整体界面采用圆角卡片作为内容承载容器，避免直角、锐利边缘带来的紧张感；
/// - 弱化数据化、工具化的视觉语言，强化情感陪伴感；
/// - 交互节奏偏慢、偏柔和，避免过强的游戏化竞争感。
abstract final class AppTheme {
  /// 卡片圆角。统一使用较大圆角，呼应「圆润治愈」的整体基调。
  static const double cardRadius = 24;

  /// 小控件圆角（标签、输入框、次级按钮）。
  static const double controlRadius = 16;

  /// 胶囊圆角（主入口按钮、封条）。
  static const double pillRadius = 999;

  /// 页面横向安全边距。
  static const double pagePadding = 20;

  /// 卡片默认内边距。
  static const double cardPadding = 18;

  /// 柔和过渡时长。交互节奏偏慢，但不超过 400ms 以免产生迟滞感。
  static const Duration motionSoft = Duration(milliseconds: 320);

  /// 仪式感动效时长。用于种子入土、点燃燃烧等核心机制动画。
  static const Duration motionRitual = Duration(milliseconds: 900);

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      // 主色：暖橘黄（开心事 / 花朵）
      primary: AppColors.warmApricot,
      onPrimary: AppColors.inkInverse,
      primaryContainer: AppColors.warmApricotSoft,
      onPrimaryContainer: AppColors.warmApricotDeep,
      // 次色：鼠尾草绿（点缀）
      secondary: AppColors.sageGreen,
      onSecondary: AppColors.inkInverse,
      secondaryContainer: AppColors.sageGreenSoft,
      onSecondaryContainer: AppColors.sageGreenDeep,
      // 三级色：雾雾灰粉（不开心事 / 纸卷）
      tertiary: AppColors.mistyRose,
      onTertiary: AppColors.inkInverse,
      tertiaryContainer: AppColors.mistyRoseSoft,
      onTertiaryContainer: AppColors.mistyRoseDeep,
      // 错误态沿用雾雾灰粉体系，避免出现刺眼的系统红
      error: AppColors.mistyRoseDeep,
      onError: AppColors.inkInverse,
      surface: AppColors.creamWhite,
      onSurface: AppColors.inkPrimary,
      surfaceContainerHighest: AppColors.creamSoft,
      onSurfaceVariant: AppColors.inkSecondary,
      outline: AppColors.creamDeep,
      outlineVariant: AppColors.divider,
      shadow: AppColors.shadowSoft,
    );

    final textTheme = AppTypography.build();

    return ThemeData(
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.creamWhite,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.creamWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.inkPrimary),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),

      // 主入口按钮：胶囊形、暖橘黄填充、柔和投影
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.warmApricot,
          foregroundColor: AppColors.inkInverse,
          disabledBackgroundColor: AppColors.creamDeep,
          disabledForegroundColor: AppColors.inkTertiary,
          minimumSize: const Size.fromHeight(56),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pillRadius),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkPrimary,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: AppColors.creamDeep),
          textStyle: textTheme.labelLarge?.copyWith(
            color: AppColors.inkPrimary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pillRadius),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.warmApricotDeep,
          textStyle: textTheme.labelMedium,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.inkTertiary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AppColors.creamDeep),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(
            color: AppColors.warmApricot,
            width: 1.4,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.creamSoft,
        selectedColor: AppColors.warmApricotSoft,
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(pillRadius),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.creamWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(cardRadius),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.creamWhite,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inkPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.inkInverse,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.warmApricotSoft,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontSize: 12,
            color: selected ? AppColors.warmApricotDeep : AppColors.inkTertiary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? AppColors.warmApricotDeep : AppColors.inkTertiary,
          );
        }),
      ),

      // 无障碍：保证文字放大后布局不溢出（PRD 第 10 章）
      visualDensity: VisualDensity.standard,
    );
  }
}
