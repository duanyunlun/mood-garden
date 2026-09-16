import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 区块标题。
///
/// 左对齐标题 + 可选副标题 + 可选右侧动作。
/// 替代工具化的数据面板标题，保持柔和的阅读节奏（PRD 11.3）。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.emoji,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// 标题前的小图标。骨架期用 emoji 占位。
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (emoji != null) ...<Widget>[
                    Text(emoji!, style: const TextStyle(fontSize: 17)),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      style: textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.inkTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Dart 3.8+ 的 null-aware element：trailing 为 null 时整个元素被省略
        ?trailing,
      ],
    );
  }
}
