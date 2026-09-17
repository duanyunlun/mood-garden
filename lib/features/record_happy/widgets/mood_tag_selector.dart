import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/tag_catalog.dart';

/// 心情标签选择器（PRD 7.1.1 步骤 3）。
///
/// > 选择一个心情标签，标签与花种一一对应，示例：感恩🌻（向日葵）、
/// > 惊喜🌷（郁金香）、陪伴💜（薰衣草）、成就🌾（麦穗）、美食🌸（樱花）、
/// > 平静🍀（幸运草）等。
///
/// 到了 PRD 7.1.3 的进阶玩法，这个列表不再只是「六个预设」：
/// - 攒够同类记录的**进化款**会追加进来，带 🌟 角标；
/// - 连续记录达标后的**隐藏款**会出现，带 🌙 角标；
/// - **季节限定**的花种在非当季时置灰，并直接写明什么时候能种。
///
/// 三种状态都在同一个列表里表达，用户不需要去别处理解「为什么这个不能选」。
class MoodTagSelector extends StatelessWidget {
  const MoodTagSelector({
    required this.tags,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  /// 可选标签（含可用性）。由 `MoodGardenController.availableTags()` 推导。
  final List<SelectableTag> tags;

  /// 当前选中的标签 id。
  final String? selectedId;

  /// 选择回调。
  final ValueChanged<SelectableTag> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selected = tags.where((item) => item.tag.id == selectedId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final item in tags)
              _TagChip(
                item: item,
                selected: item.tag.id == selectedId,
                onTap: item.isAvailable ? () => onSelected(item) : null,
              ),
          ],
        ),
        if (selected != null && selected.isAvailable) ...<Widget>[
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
                  selected.tag.species?.emoji ?? '🌱',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _previewText(selected),
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

  /// 花种预览文案。把进化款、隐藏款、季节限定的差别说清楚，
  /// 而不是让用户自己从图标猜。
  static String _previewText(SelectableTag item) {
    final species = item.tag.species;
    final name = species?.name ?? '一朵花';
    final suffix = species?.isSeasonal ?? false ? '（季节限定）' : '';
    if (item.isHidden) {
      return '这颗种子会长成$name$suffix —— 坚持记录才有的奖励';
    }
    if (item.isEvolved) {
      return '这颗种子会长成$name$suffix —— 攒够同类心情后的进化形态';
    }
    return '这颗种子会长成$name$suffix';
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SelectableTag item;

  /// `null` 表示此刻不可选（例如樱花不在 3-4 月）。
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tag = item.tag;
    final disabled = onTap == null;

    return Semantics(
      selected: selected,
      button: true,
      enabled: !disabled,
      label: disabled
          ? '${tag.label}标签，${item.unavailableReason}，当前不可选'
          : '${tag.label}标签，对应${tag.species?.name ?? '花'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        child: AnimatedContainer(
          duration: AppTheme.motionSoft,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.warmApricotSoft
                : (disabled ? AppColors.creamSoft : Colors.white),
            borderRadius: BorderRadius.circular(AppTheme.pillRadius),
            border: Border.all(
              color: selected ? AppColors.warmApricot : AppColors.creamDeep,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Opacity(
                opacity: disabled ? 0.4 : 1,
                child: Text(
                  tag.emoji,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                tag.label,
                style: textTheme.labelMedium?.copyWith(
                  color: disabled
                      ? AppColors.inkTertiary
                      : (selected
                          ? AppColors.warmApricotDeep
                          : AppColors.inkSecondary),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (disabled) ...<Widget>[
                const SizedBox(width: 5),
                Text(
                  item.unavailableReason ?? '',
                  style: textTheme.labelSmall?.copyWith(fontSize: 10),
                ),
              ] else if (item.badge != null) ...<Widget>[
                const SizedBox(width: 5),
                Text(item.badge!, style: const TextStyle(fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 标签上的角标：进化款给 🌟、隐藏款给 🌙。
extension on SelectableTag {
  String? get badge {
    if (isHidden) {
      return '🌙';
    }
    if (isEvolved) {
      return '🌟';
    }
    return null;
  }
}
