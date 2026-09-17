import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/mood_garden_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../application/settings_controller.dart';
import '../../data/datasources/storage_bootstrap.dart';
import '../../domain/entities/garden_theme.dart';
import '../../domain/entities/mood_tag.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/soft_card.dart';
import 'widgets/settings_sheets.dart';

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
    // 存储形态在启动装配后不再变化；用 watch 保持与 Provider 的语义一致。
    final storage = context.watch<StorageBootstrap>();
    final settings = context.watch<SettingsController>();

    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      body: SafeArea(
        bottom: false,
        child: Consumer<MoodGardenController>(
          builder: (context, controller, _) {
            if (controller.isLoading || settings.isLoading) {
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
                _TagManager(settings: settings),
                const SizedBox(height: 22),

                // 每一条都真的能用：点进去立刻生效或真的发出分享。
                // 未实现的功能不在这里占位（排期见 docs/ROADMAP.md）。
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
                        emoji: '🔠',
                        title: '字体大小',
                        subtitle: settings.textScale == 1.0
                            ? '跟随系统（当前未额外放大）'
                            : '比系统再放大 ${((settings.textScale - 1) * 100).round()}%',
                        onTap: () => showTextScaleSheet(context, settings),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _SettingTile(
                        emoji: '🔔',
                        title: '每日提醒',
                        subtitle: settings.settings.reminderEnabled
                            ? '每天 ${settings.reminderTimeLabel} 轻轻提醒你'
                            : '关着。开一个，别让今天白白过去',
                        onTap: () => showReminderSheet(context, settings),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _SettingTile(
                        emoji: settings.settings.soundEnabled ? '🔊' : '🔇',
                        title: '仪式音效',
                        subtitle: settings.settings.soundEnabled
                            ? '种子入土与点燃纸卷时有轻音效'
                            : '已关闭。适合在安静的场合记录',
                        onTap: () => settings.setSoundEnabled(
                          !settings.settings.soundEnabled,
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _SettingTile(
                        emoji: '📤',
                        title: '分享花园',
                        subtitle: '把花园现在的样子分享出去',
                        onTap: () => showShareSheet(context, controller),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _SettingTile(
                        emoji: storage.isPersistent ? '🔒' : '⚠️',
                        title: '隐私与数据',
                        subtitle: storage.isPersistent
                            ? '记录已加密保存在本机'
                            : '记录未能保存到本机',
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

  void _showPrivacySheet(
    BuildContext context,
    MoodGardenController controller,
  ) {
    final storage = context.read<StorageBootstrap>();

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
                storage.isPersistent
                    ? '记录会加密保存在这台设备上，密钥由系统安全区单独保管，'
                          '不与记录内容放在一起。\n'
                          '烧掉的纸卷在写入时就已擦除原文，之后任何方式都无法再读出。'
                    : '⚠️ 记录目前无法保存到本机：关闭 App 后内容会丢失。\n'
                          '技术原因：${storage.degradedReason ?? '未知'}',
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
                value: '${garden.bloomingCountAt(now)}',
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
/// 预设标签只读，自定义标签可增可删——这条区分是有意的：
/// 删掉一个预设标签会让历史记录里的 tagId 找不到对应的花种，
/// 那些记录就会显示成「自定义」并长成向日葵。
class _TagManager extends StatelessWidget {
  const _TagManager({required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tags = settings.allTags;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final tag in tags)
                _TagChip(
                  tag: tag,
                  onDelete: tag.isCustom
                      ? () => settings.removeCustomTag(tag.id)
                      : null,
                ),
              _AddTagChip(
                onTap: () => showNewTagDialog(context, settings),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '预设标签不能删；带 × 的是你自己加的。',
            style: textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// 一个标签，右侧可选删除按钮。
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, this.onDelete});

  final MoodTag tag;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.fromLTRB(13, 8, onDelete == null ? 13 : 6, 8),
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
          if (onDelete != null) ...<Widget>[
            const SizedBox(width: 2),
            Semantics(
              button: true,
              label: '删除标签 ${tag.label}',
              child: InkWell(
                onTap: onDelete,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(
                    Icons.close,
                    size: 13,
                    color: AppColors.inkTertiary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 「＋ 新建标签」。
class _AddTagChip extends StatelessWidget {
  const _AddTagChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '新建心情标签',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.pillRadius),
            border: Border.all(
              color: AppColors.warmApricotSoft,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.add,
                size: 14,
                color: AppColors.warmApricotDeep,
              ),
              const SizedBox(width: 5),
              Text(
                '新建标签',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.warmApricotDeep,
                ),
              ),
            ],
          ),
        ),
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
  });

  final String emoji;
  final String title;
  final String subtitle;
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
            'v${AppConstants.appVersion}',
            style: textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
