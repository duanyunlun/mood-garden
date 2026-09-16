import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/mood_garden_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/mood_entry.dart';
import '../../domain/entities/mood_tag.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/soft_card.dart';
import 'widgets/garden_canvas.dart';
import 'widgets/nutrient_progress_bar.dart';

/// Tab1 花园首页（PRD 第 6 章信息架构 / 第 7 章核心机制）。
///
/// 页面构成严格对齐 PRD：
/// - 花园全景展示区（种子 / 发芽 / 开花的实时生长状态）
/// - 今日种下数量 / 养分值进度条
/// - 两个主入口按钮：种下开心事、点燃纸卷
class GardenHomePage extends StatelessWidget {
  const GardenHomePage({super.key});

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
                8,
                AppTheme.pagePadding,
                28,
              ),
              children: <Widget>[
                _Greeting(controller: controller),
                const SizedBox(height: 18),

                // 花园全景展示区
                GardenCanvas(flowers: garden.flowers),

                const SizedBox(height: 14),

                // 今日概览
                _TodaySummary(controller: controller),

                const SizedBox(height: 14),

                // 养分值进度条（PRD 7.3：常驻展示）
                SoftCard(
                  child: NutrientProgressBar(garden: garden),
                ),

                const SizedBox(height: 20),

                // 两个主入口按钮
                _PrimaryActions(
                  onPlantSeed: () => AppRouter.pushRecordHappy(context),
                  onIgniteScroll: () => AppRouter.pushRecordUnhappy(context),
                ),

                const SizedBox(height: 22),

                // 期待感文案：下一株即将开花的植物（PRD 7.1.2）
                _AnticipationHint(controller: controller),

                const SizedBox(height: 18),

                // 最近记录预览
                _RecentEntries(controller: controller),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 顶部问候与花园名。
class _Greeting extends StatelessWidget {
  const _Greeting({required this.controller});

  final MoodGardenController controller;

  static String _greetingOf(DateTime now) {
    final hour = now.hour;
    if (hour < 6) {
      return '夜深了';
    }
    if (hour < 11) {
      return '早上好';
    }
    if (hour < 14) {
      return '中午好';
    }
    if (hour < 18) {
      return '下午好';
    }
    return '晚上好';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final garden = controller.garden;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${_greetingOf(DateTime.now())}，今天也来看看花园吧',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Text(
              garden.theme.emoji,
              style: const TextStyle(fontSize: 26),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                garden.theme.name,
                style: textTheme.headlineMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          AppConstants.valueProposition,
          style: textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// 今日概览：今日种下数量 + 今日已转化的纸卷数。
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.controller});

  final MoodGardenController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryTile(
            emoji: '🌱',
            label: '今日种下',
            value: '${controller.todayPlantedCount}',
            unit: '件开心事',
            accent: AppColors.warmApricotDeep,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            emoji: '🕊️',
            label: '今日转化',
            value: '${controller.todayBurnedCount}',
            unit: '张纸卷',
            accent: AppColors.mistyRoseDeep,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  final String emoji;
  final String label;
  final String value;
  final String unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text(label, style: textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: value,
                  style: textTheme.headlineMedium?.copyWith(
                    color: accent,
                    fontSize: 24,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 两个主入口按钮（PRD Tab1）。
///
/// 视觉上刻意保持对等：开心事与不开心事是两条平等的路径，
/// 不应对负向情绪的表达做任何视觉降级（PRD 7.2.3 的价值观）。
class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.onPlantSeed,
    required this.onIgniteScroll,
  });

  final VoidCallback onPlantSeed;
  final VoidCallback onIgniteScroll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionCard(
            emoji: '🌻',
            title: '种下开心事',
            subtitle: '变成花园里的一朵花',
            background: AppColors.warmApricotTint,
            border: AppColors.warmApricotSoft,
            titleColor: AppColors.warmApricotDeep,
            onTap: onPlantSeed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            emoji: '📜',
            title: '点燃纸卷',
            subtitle: '写完就烧掉，变成养分',
            background: AppColors.mistyRoseTint,
            border: AppColors.mistyRoseSoft,
            titleColor: AppColors.mistyRoseDeep,
            onTap: onIgniteScroll,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.border,
    required this.titleColor,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color background;
  final Color border;
  final Color titleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SoftCard(
      color: background,
      border: BorderSide(color: border),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 10),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(color: titleColor),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// 期待感提示（PRD 7.1.2）。
class _AnticipationHint extends StatelessWidget {
  const _AnticipationHint({required this.controller});

  final MoodGardenController controller;

  @override
  Widget build(BuildContext context) {
    final next = controller.nextBlooming();
    if (next == null) {
      return const SizedBox.shrink();
    }

    final speciesName = next.flower.species?.name ?? '一株植物';
    final days = next.days;

    return SoftCard(
      color: AppColors.sageGreenTint,
      border: const BorderSide(color: AppColors.sageGreenSoft),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          const Text('🌿', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              days <= 0
                  ? '有一株$speciesName马上就要开花了'
                  : '再等 $days 天，有一株$speciesName就要开花了',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.sageGreenDeep,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 最近记录预览。
class _RecentEntries extends StatelessWidget {
  const _RecentEntries({required this.controller});

  final MoodGardenController controller;

  @override
  Widget build(BuildContext context) {
    final recent = controller.recentEntries(limit: 3);
    if (recent.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: '最近的记录',
          emoji: '🕰️',
          subtitle: '完整回顾可以去时光轴',
        ),
        const SizedBox(height: 12),
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: <Widget>[
              for (var i = 0; i < recent.length; i++) ...<Widget>[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                _RecentEntryTile(entry: recent[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentEntryTile extends StatelessWidget {
  const _RecentEntryTile({required this.entry});

  final MoodEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // sealed class 的穷尽 switch：新增记录类型时编译器会强制在此处处理。
    // 注意必须用 `HappyEntry e` 绑定变量才能访问子类字段——
    // 仅写 `HappyEntry()` 不会提升 entry 的静态类型。
    final (String emoji, String title, Color titleColor) = switch (entry) {
      HappyEntry e => (
          MoodTag.presetById(e.tagId)?.emoji ?? '🌱',
          e.text.isEmpty ? '（没有写字，但记下了这一刻）' : e.text,
          AppColors.inkPrimary,
        ),
      UnhappyEntry e => (
          e.isBurned ? '🕊️' : '📜',
          e.isBurned ? '已转化为养分' : '一张还没点燃的纸卷',
          e.isBurned ? AppColors.ash : AppColors.mistyRoseDeep,
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 19)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(color: titleColor),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormatter.entryTimestamp(entry.occurredAt),
                  style: textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
