import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 空态与占位提示。
///
/// 用于花园尚无植物、时光轴当天无记录、图鉴未解锁等场景。
/// 文案风格遵循 PRD 11.3 的「温暖、柔和」基调——不用「暂无数据」这类
/// 工具化措辞，而是给出有陪伴感的引导。
class SoftEmptyState extends StatelessWidget {
  const SoftEmptyState({
    required this.emoji,
    required this.title,
    super.key,
    this.description,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  /// 主图标。骨架期用 emoji 占位，正式版替换为手绘插画。
  final String emoji;

  /// 主文案。
  final String title;

  /// 辅助说明。
  final String? description;

  /// 行动按钮文案。
  final String? actionLabel;

  /// 行动按钮回调。
  final VoidCallback? onAction;

  /// 紧凑模式。用于嵌在卡片内部的小面积空态。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.pagePadding,
          vertical: compact ? 12 : 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              emoji,
              style: TextStyle(fontSize: compact ? 32 : 52),
            ),
            SizedBox(height: compact ? 10 : 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: compact ? textTheme.bodyMedium : textTheme.titleMedium,
            ),
            if (description != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 46),
                  backgroundColor: AppColors.warmApricot,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
