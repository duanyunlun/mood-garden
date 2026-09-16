import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 圆角柔和卡片。
///
/// PRD 11.3：整体界面采用圆角卡片作为内容承载容器，避免直角、锐利边缘
/// 带来的紧张感。项目中所有内容容器都应使用本组件，而不是裸 [Card] 或
/// [Container]，以保证圆角、内边距、投影风格全局统一。
class SoftCard extends StatelessWidget {
  const SoftCard({
    required this.child,
    super.key,
    this.padding,
    this.color,
    this.onTap,
    this.radius,
    this.border,
  });

  final Widget child;

  /// 内边距。默认 [AppTheme.cardPadding]。
  final EdgeInsetsGeometry? padding;

  /// 背景色。默认白色，与奶油白页面底色形成柔和层次。
  final Color? color;

  /// 点击回调。为 `null` 时卡片不可交互。
  final VoidCallback? onTap;

  /// 自定义圆角。默认 [AppTheme.cardRadius]。
  final double? radius;

  /// 自定义描边。
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius ?? AppTheme.cardRadius);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: borderRadius,
        border: border == null ? null : Border.fromBorderSide(border!),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: AppColors.warmApricotSoft.withValues(alpha: 0.4),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTheme.cardPadding),
            child: child,
          ),
        ),
      ),
    );
  }
}
