import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../application/mood_garden_controller.dart';
import '../../../application/settings_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/flower_species.dart';
import '../../../domain/entities/growth_stage.dart';

/// 「我的」里的几个设置面板。
///
/// 抽到这个文件，是为了让 `profile_page.dart` 保持只描述页面结构；
/// 面板里的交互与副作用（申请权限、渲染分享图、写临时文件）放在这里。

// -----------------------------------------------------------------------------
// 无障碍：字体大小
// -----------------------------------------------------------------------------

/// 字体大小调节面板。拖动即时生效，所见即所得。
Future<void> showTextScaleSheet(
  BuildContext context,
  SettingsController settings,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.creamWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.cardRadius),
      ),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final current = settings.textScale;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '字体大小',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '系统里调过之后如果还觉得小，可以在这里再放大一点。'
                  '两个档位是叠加的。',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),

                // 实时预览：调完不用退出去看效果
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warmApricotTint,
                    borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                  ),
                  child: Text(
                    '今天有什么让你觉得，真好呀？',
                    style: Theme.of(sheetContext).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: <Widget>[
                    Text('A', style: Theme.of(sheetContext).textTheme.labelSmall),
                    Expanded(
                      child: Slider(
                        value: current,
                        min: AppConstants.textScaleMin,
                        max: AppConstants.textScaleMax,
                        divisions:
                            ((AppConstants.textScaleMax -
                                        AppConstants.textScaleMin) /
                                    0.05)
                                .round(),
                        label: '${(current * 100).round()}%',
                        onChanged: (value) {
                          // 即时应用到整棵树，预览与真实效果一致
                          settings.setTextScale(value);
                          setSheetState(() {});
                        },
                      ),
                    ),
                    Text('A', style: Theme.of(sheetContext).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    current == 1.0
                        ? '跟随系统'
                        : '比系统再放大 ${((current - 1) * 100).round()}%',
                    style: Theme.of(sheetContext).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () {
                      settings.setTextScale(1.0);
                      setSheetState(() {});
                    },
                    child: const Text('恢复跟随系统'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// -----------------------------------------------------------------------------
// 每日提醒
// -----------------------------------------------------------------------------

/// 每日提醒设置面板。
Future<void> showReminderSheet(
  BuildContext context,
  SettingsController settings,
) async {
  final messenger = ScaffoldMessenger.of(context);
  var hour = settings.settings.reminderHour;
  var minute = settings.settings.reminderMinute;
  final enabled = settings.settings.reminderEnabled;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.creamWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.cardRadius),
      ),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final textTheme = Theme.of(sheetContext).textTheme;
        final label =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('每日提醒', style: textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  '一天里挑一个安静的时刻，轻轻提醒你回来看看。'
                  '提醒文案是温和的，不会统计你断更了几天。',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 18),

                SoftTile(
                  emoji: '🕘',
                  title: '提醒时间',
                  trailing: label,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: sheetContext,
                      initialTime: TimeOfDay(hour: hour, minute: minute),
                      helpText: '选择提醒时间',
                      cancelText: '取消',
                      confirmText: '确定',
                    );
                    if (picked != null) {
                      setSheetState(() {
                        hour = picked.hour;
                        minute = picked.minute;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          // 无论「新开」还是「改了时间」，走的都是同一条路：
                          // 请求权限 → 重新排期（scheduleDaily 会先取消旧的）。
                          final ok = await settings.setReminder(
                            enabled: true,
                            hour: hour,
                            minute: minute,
                          );
                          if (!sheetContext.mounted) {
                            return;
                          }
                          if (!ok) {
                            messenger
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '没能打开通知权限。可以到系统设置里允许通知后再试',
                                  ),
                                ),
                              );
                            return;
                          }
                          Navigator.of(sheetContext).pop();
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(content: Text('好的，每天 $label 提醒你')),
                            );
                        },
                        child: Text(enabled ? '更新提醒' : '开启提醒'),
                      ),
                    ),
                    if (enabled) ...<Widget>[
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () async {
                          await settings.setReminder(enabled: false);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        child: const Text('关闭'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// -----------------------------------------------------------------------------
// 分享花园
// -----------------------------------------------------------------------------

/// 分享面板：先给一张真实渲染出来的花园卡片，再交给系统分享。
///
/// 分享的是一张**图片**而不是一段文字——花园是视觉产品，
/// 一句「我连续记录了 7 天」远不如花园本身有说服力。
Future<void> showShareSheet(
  BuildContext context,
  MoodGardenController controller,
) {
  final cardKey = GlobalKey();
  var busy = false;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.creamWhite,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.cardRadius),
      ),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final textTheme = Theme.of(sheetContext).textTheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('分享花园', style: textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('会把下面这张卡片存成图片分享出去。', style: textTheme.bodySmall),
                const SizedBox(height: 16),

                // 这张卡片同时是预览和分享内容，所见即所得
                RepaintBoundary(
                  key: cardKey,
                  child: GardenShareCard(controller: controller),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setSheetState(() => busy = true);
                            final error = await _shareCard(cardKey, controller);
                            if (!sheetContext.mounted) {
                              return;
                            }
                            setSheetState(() => busy = false);
                            if (error != null) {
                              ScaffoldMessenger.of(sheetContext)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(SnackBar(content: Text(error)));
                            }
                          },
                    child: Text(busy ? '正在准备…' : '分享'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// 把卡片渲染成 PNG 并交给系统分享。返回错误文案，成功时返回 `null`。
Future<String?> _shareCard(GlobalKey key, MoodGardenController controller) async {
  try {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return '这张卡片还没准备好，稍后再试';
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      return '没能生成图片';
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}mood_garden.png');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: 'image/png')],
        text: '${AppConstants.appName} · ${AppConstants.slogan}',
      ),
    );
    return null;
  } catch (error) {
    return '分享没能完成，可以再试一次';
  }
}

/// 分享用的花园卡片。
///
/// 刻意不复用首页画布：首页布局依赖滚动位置与视口尺寸，
/// 截出来的图会带上不该出现的空白。这里独立排版，保证无论用户在哪一页
/// 点分享，出来的都是同一张规整的卡片。
class GardenShareCard extends StatelessWidget {
  const GardenShareCard({required this.controller, super.key});

  final MoodGardenController controller;

  @override
  Widget build(BuildContext context) {
    final garden = controller.garden;
    final now = DateTime.now();
    final stages = garden.stageDistributionAt(now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFFDF8), AppColors.sageGreenTint],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.warmApricotSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(garden.theme.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      garden.theme.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 用各阶段的株数代替画布截图：一眼看出花园的构成
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: <Widget>[
              for (final stage in GrowthStage.values)
                if ((stages[stage] ?? 0) > 0)
                  _StageCount(stage: stage, count: stages[stage] ?? 0),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          _ShareStat(label: '连续记录', value: '${garden.streakDays} 天'),
          _ShareStat(label: '已开花', value: '${garden.bloomingCountAt(now)} 朵'),
          _ShareStat(label: '花园养分', value: garden.vitalityLabel),
          _ShareStat(
            label: '收集花种',
            value:
                '${garden.collectedSpeciesCountAt(now)} / ${FlowerSpecies.catalog.length} 种',
          ),

          const SizedBox(height: 16),
          Center(
            child: Text(
              AppConstants.slogan,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.warmApricotDeep,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageCount extends StatelessWidget {
  const _StageCount({required this.stage, required this.count});

  final GrowthStage stage;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(stage.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 4),
        Text('$count', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _ShareStat extends StatelessWidget {
  const _ShareStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: textTheme.labelSmall),
          Text(
            value,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.warmApricotDeep,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 新建自定义标签
// -----------------------------------------------------------------------------

/// 新建标签对话框。返回是否真的创建了。
Future<bool> showNewTagDialog(
  BuildContext context,
  SettingsController settings,
) async {
  final labelController = TextEditingController();
  var emoji = _emojiChoices.first;
  var speciesId = plantableSpecies.first.id;

  final created = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final textTheme = Theme.of(dialogContext).textTheme;

        return AlertDialog(
          backgroundColor: AppColors.creamWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          title: const Text('新建心情标签'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: labelController,
                  autofocus: true,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '标签名',
                    hintText: '例如：散步',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 6),
                Text('选个图标', style: textTheme.labelSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final choice in _emojiChoices)
                      _Choice(
                        selected: choice == emoji,
                        onTap: () => setDialogState(() => emoji = choice),
                        child: Text(
                          choice,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('它会长成什么花', style: textTheme.labelSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final species in plantableSpecies)
                      _Choice(
                        selected: species.id == speciesId,
                        onTap: () =>
                            setDialogState(() => speciesId = species.id),
                        child: Text(
                          '${species.emoji} ${species.name}',
                          style: textTheme.labelMedium,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: labelController.text.trim().isEmpty
                  ? null
                  : () async {
                      final tag = await settings.addCustomTag(
                        label: labelController.text,
                        emoji: emoji,
                        speciesId: speciesId,
                      );
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(tag != null);
                      }
                    },
              child: const Text('创建'),
            ),
          ],
        );
      },
    ),
  );

  labelController.dispose();

  if (created == true) {
    return true;
  }
  if (created == false && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('这个标签名已经有了，换一个吧')),
      );
  }
  return false;
}

const List<String> _emojiChoices = <String>[
  '🌱', '🌻', '🌷', '💜', '🌾', '🌸',
  '🍀', '☕', '🎧', '📚', '🏃', '🌙',
];

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.warmApricotSoft : AppColors.creamSoft,
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          border: Border.all(
            color: selected ? AppColors.warmApricot : Colors.transparent,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// 面板里用的一行设置项。与 `profile_page.dart` 里的私有实现分开，
/// 因为那个带页面内的导航语义，这个只承担「一行可点区域」。
class SoftTile extends StatelessWidget {
  const SoftTile({
    required this.emoji,
    required this.title,
    required this.onTap,
    super.key,
    this.trailing,
  });

  final String emoji;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.creamSoft,
          borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        ),
        child: Row(
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: textTheme.titleMedium)),
            if (trailing != null)
              Text(
                trailing!,
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.warmApricotDeep,
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
