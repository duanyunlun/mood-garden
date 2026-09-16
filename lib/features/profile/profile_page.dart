import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/mood_garden_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/garden_theme.dart';
import '../../domain/entities/mood_tag.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/soft_card.dart';

/// Tab4 我的（PRD 第 6 章信息架构 / Tab4 定义）。
///
/// PRD 列出的六个模块：
/// - 花园主题换肤（向日葵田 / 樱花谷 / 薰衣草坡 / 麦浪田等）—— **已实现**
/// - 每日提醒设置（提醒时间、文案风格）—— P1，骨架期占位
/// - 快捷标签管理（自定义常用心情 / 场景标签）—— 骨架期展示现有标签
/// - 分享中心（花园全景 / 图鉴分享至社交平台）—— P2，骨架期占位
/// - 无障碍设置（字体大小、色彩对比度）—— 骨架期占位
/// - 隐私与数据设置（本地存储加密、云同步开关）—— 骨架期占位
///
/// 占位项一律明确标注状态，不做「看起来能用但点了没反应」的假入口。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      body: SafeArea(
        bottom: false,
        child: Consumer<MoodGardenController>(
          builder: (context, controller, _) {
            if (controller.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.warmApricot,
                ),
              );
            }

            final garden = controller.garden;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                10,
                AppTheme.pagePadding,
                28,
              ),
              children: <Widget>[
                Text(
                  '我的',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),

                _GardenOverviewCard(controller: controller),
                const SizedBox(height: 22),

                // 花园主题换肤（已实现）
                const SectionHeader(
                  title: '花园主题',
                  emoji: '🎨',
                  subtitle: '换一片风景，心情也跟着换',
                ),
                const SizedBox(height: 12),
                _ThemePicker(
                  currentThemeId: garden.themeId,
                  onSelected: controller.changeTheme,
                ),
                const SizedBox(height: 22),

                // 快捷标签管理
                const SectionHeader(
                  title: '我的心情标签',
                  emoji: '🏷️',
                  subtitle: '标签决定每次记录种下什么花',
                ),
                const SizedBox(height: 12),
                const _TagManager(),
                const SizedBox(height: 22),

                // 提醒 / 分享 / 无障碍 / 隐私
                const SectionHeader(
                  title: '设置',
                  emoji: '⚙️',
                ),
                const SizedBox(height: 12),
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: <Widget>[
                      _SettingTile(
                        emoji: '🔔',
                        title: '每日提醒',
                        subtitle: '温柔文案的推送提醒，养成记录习惯',
                        badge: 'P1',
                        onTap: () => _showPending(context, '每日提醒'),
                      ),
                      const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      _SettingTile(
                        emoji: '📤',
                        title: '分享中心',
                        subtitle: '把花园全景或图鉴分享出去',
                        badge: 'P2',
                        onTap: () => _showPending(context, '分享中心'),
                      ),
                      const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      _SettingTile(
                        emoji: '🔍',
                        title: '无障碍',
                        subtitle: '字体大小、色彩对比度',
                        badge: '待设计',
                        onTap: () => _showPending(context, '无障碍设置'),
                      ),
                      const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      _SettingTile(
                        emoji: '🔒',
                        title: '隐私与数据',
                        subtitle: '本地加密、云同步开关、清除数据',
                        badge: '待实现',
                        onTap: () => _showPrivacySheet(context, controller),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const _VersionFooter(),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showPending(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$feature 尚未实现，已在 README 路线图中登记')),
      );
  }

  void _showPrivacySheet(
    BuildContext context,
    MoodGardenController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.creamWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.cardRadius),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '隐私与数据',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '骨架期使用内存存储：数据不落盘、不加密，关闭 App 即清空。\n'
                '正式实现需接入 iOS Keychain 托管密钥 + 本地加密存储，'
                '并落实「灰烬内容物理不可恢复」的技术承诺（PRD 第 10 章）。',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () async {
                  await controller.clearAllData();
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('清除全部数据'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 花园概览卡片。
class _GardenOverviewCard extends StatelessWidget {
  const _GardenOverviewCard({required this.controller});

  final MoodGardenController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final garden = controller.garden;
    final now = DateTime.now();
    final stages = garden.stageDistributionAt(now);

    return SoftCard(
      color: AppColors.warmApricotTint,
      border: const BorderSide(color: AppColors.warmApricotSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                garden.theme.emoji,
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(AppConstants.appName, style: textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      '花园里已有 ${garden.totalPlants} 株植物',
                      style: textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatChip(
                label: '连续记录',
                value: '${garden.streakDays} 天',
              ),
              _StatChip(
                label: '已开花',
                value: '${stages.values.isNotEmpty ? stages.values.reduce((a, b) => a + b) : 0}',
              ),
              _StatChip(
                label: '养分',
                value: garden.vitalityLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.warmApricotDeep,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 花园主题选择器（PRD Tab4「花园主题换肤」）。
class _ThemePicker extends StatelessWidget {
  const _ThemePicker({
    required this.currentThemeId,
    required this.onSelected,
  });

  final String currentThemeId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // 用 Wrap + 固定列宽而非 GridView 的固定宽高比：
    // 卡片高度由内容决定，字体放大（PRD 第 10 章无障碍要求）时不会溢出。
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: GardenThemeOption.catalog.map((theme) {
            final selected = theme.id == currentThemeId;

            return SizedBox(
              width: itemWidth,
              child: SoftCard(
                onTap: () => onSelected(theme.id),
                color: selected ? AppColors.warmApricotSoft : Colors.white,
                border: selected
                    ? const BorderSide(
                        color: AppColors.warmApricot,
                        width: 1.6,
                      )
                    : null,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          theme.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const Spacer(),
                        if (selected)
                          const Icon(
                            Icons.check_circle,
                            size: 17,
                            color: AppColors.warmApricotDeep,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      theme.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: selected
                                ? AppColors.warmApricotDeep
                                : AppColors.inkPrimary,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      theme.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

/// 快捷标签管理（PRD Tab4）。
///
/// 骨架期展示内置预设标签；自定义标签的增删改待产品明确交互后实现
/// （PRD 第 12 章：标签对照表完整细节待定）。
class _TagManager extends StatelessWidget {
  const _TagManager();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: MoodTag.presets.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.creamSoft,
                  borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(tag.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(tag.label, style: textTheme.labelMedium),
                    const SizedBox(width: 6),
                    Text(
                      '→ ${tag.species?.name ?? '?'}',
                      style: textTheme.labelSmall,
                    ),
                  ],
                ),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 12),
          Text(
            '自定义标签功能待 PRD 第 12 章「标签-花种对照表」定案后开放',
            style: textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// 设置项。
class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 19)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: textTheme.labelSmall),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.creamSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: textTheme.labelSmall?.copyWith(fontSize: 10),
                ),
              ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.inkTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 版本信息。
class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        children: <Widget>[
          Text(
            AppConstants.slogan,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.warmApricotDeep,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'v0.1.0 · 骨架版本',
            style: textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '产品命名待定（谢谢日记 / 心情花园）',
            style: textTheme.labelSmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
