import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/mood_tag.dart';

/// 心情标签选择器（PRD 7.1.1 步骤 3）。
///
/// > 选择一个心情标签，标签与花种一一对应，示例：感恩🌻（向日葵）、
/// > 惊喜🌷（郁金香）、陪伴💜（薰衣草）、成就🌾（麦穗）、美食🌸（樱花）、
/// > 平静🍀（幸运草）等。
///
/// 选中后立即在下方显示「这颗种子会长成什么」的预览，
/// 让「标签 → 花种」的映射关系对用户可见，强化收集预期。
class MoodTagSelector extends StatelessWidget {
  const MoodTagSelector({
    required this.selectedId,
    required this.onSelected,
    super.key,
    this.tags,
  });

  /// 当前选中的标签 id。
  final String? selectedId;

  /// 选择回调。
  final ValueChanged<String> onSelected;

  /// 可选标签列表。默认使用内置预设（PRD 7.1.1）。
  ///
  /// 传入自定义列表即可支持 Tab4 的「快捷标签管理」扩展。
  final List<MoodTag>? tags;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final available = tags ?? MoodTag.presets;
    final selected =
        available.where((tag) => tag.id == selectedId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: available
              .map(
                (tag) => _TagChip(
                  tag: tag,
                  selected: tag.id == selectedId,
                  onTap: () => onSelected(tag.id),
                ),
              )
              .toList(growable: false),
        ),
        if (selected != null) ...<Widget>[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.sageGreenTint,
              borderRadius: BorderRadius.circular(AppTheme.controlRadius),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  selected.species?.emoji ?? '🌱',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '这颗种子会长成${selected.species?.name ?? '一朵花'}'
                    '${selected.species?.isSeasonal ?? false ? '（季节限定）' : ''}',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.sageGreenDeep,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  final MoodTag tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      selected: selected,
      button: true,
      label: '${tag.label}标签，对应${tag.species?.name ?? '花'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        child: AnimatedContainer(
          duration: AppTheme.motionSoft,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.warmApricotSoft : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.pillRadius),
            border: Border.all(
              color: selected
                  ? AppColors.warmApricot
                  : AppColors.creamDeep,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(tag.emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(
                tag.label,
                style: textTheme.labelMedium?.copyWith(
                  color: selected
                      ? AppColors.warmApricotDeep
                      : AppColors.inkSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
