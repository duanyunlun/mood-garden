import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/mood_garden_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/flower_species.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/soft_card.dart';

/// 花之图鉴的分区内容（原型 v5：图鉴并入「我的花瓣」页）。
///
/// 从原来的一级 Tab 页面里抽出来，是为了让「图鉴页」与「我的花瓣页」
/// 共用同一份渲染——否则两处各写一遍花种网格，迟早会漂移。
/// 这里只负责内容，页面标题与 Scaffold 由调用方决定。
class CodexSections extends StatelessWidget {
  const CodexSections({super.key, this.showHeading = true});

  /// 是否显示「已收集 N / M 种花」这一行。
  /// 花瓣页自己有汇总信息，因此那里传 false 避免重复。
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    return Consumer<MoodGardenController>(
      builder: (context, controller, _) {
        final now = DateTime.now();
        final garden = controller.garden;

        final common = FlowerSpecies.byRarity(SpeciesRarity.common);
        final rare = <FlowerSpecies>[
          ...FlowerSpecies.byRarity(SpeciesRarity.rare),
          ...FlowerSpecies.byRarity(SpeciesRarity.hidden),
        ];
        final seasonal = FlowerSpecies.byRarity(SpeciesRarity.seasonal);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (showHeading) ...<Widget>[
              Text(
                '已收集 ${garden.collectedSpeciesCountAt(now)} / '
                '${FlowerSpecies.catalog.length} 种花',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 18),
            ],

            // 隐藏款解锁进度（PRD 7.1.3）
            HiddenUnlockBanner(
              streakDays: garden.streakDays,
              unlocked: garden.hiddenSpeciesUnlocked,
              daysLeft: garden.daysToHiddenSpecies,
            ),
            const SizedBox(height: 22),

            const SectionHeader(
              title: '常见花种',
              emoji: '🌱',
              subtitle: '记录对应心情的开心事，就能种下它们',
            ),
            const SizedBox(height: 12),
            SpeciesGrid(species: common, controller: controller, now: now),
            const SizedBox(height: 22),

            const SectionHeader(
              title: '进化与隐藏款',
              emoji: '🌟',
              subtitle: '同类心情攒够数量，或连续记录达标后解锁',
            ),
            const SizedBox(height: 12),
            SpeciesGrid(species: rare, controller: controller, now: now),
            const SizedBox(height: 22),

            const SectionHeader(
              title: '季节限定',
              emoji: '🌸',
              subtitle: '只在特定月份可种，错过要再等一年',
            ),
            const SizedBox(height: 12),
            SpeciesGrid(species: seasonal, controller: controller, now: now),
          ],
        );
      },
    );
  }
}

/// 隐藏款解锁进度横幅（PRD 7.1.3）。
class HiddenUnlockBanner extends StatelessWidget {
  const HiddenUnlockBanner({
    super.key,
    required this.streakDays,
    required this.unlocked,
    required this.daysLeft,
  });

  final int streakDays;
  final bool unlocked;
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const target = AppConstants.hiddenSpeciesStreakDays;
    final progress = (streakDays / target).clamp(0.0, 1.0);

    return SoftCard(
      color: unlocked
          ? AppColors.warmApricotTint
          : AppColors.sageGreenTint,
      border: BorderSide(
        color: unlocked ? AppColors.warmApricotSoft : AppColors.sageGreenSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                unlocked ? '🌙' : '🔒',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  unlocked ? '月光花已解锁' : '再坚持 $daysLeft 天，会遇见月光花',
                  style: textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: <Widget>[
                Container(height: 8, color: Colors.white),
                FractionallySizedBox(
                  widthFactor: progress == 0 ? 0.001 : progress,
                  child: Container(
                    height: 8,
                    color: unlocked
                        ? AppColors.warmApricot
                        : AppColors.sageGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '连续记录 $streakDays / $target 天',
            style: textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// 花种网格。
class SpeciesGrid extends StatelessWidget {
  const SpeciesGrid({
    super.key,
    required this.species,
    required this.controller,
    required this.now,
  });

  final List<FlowerSpecies> species;
  final MoodGardenController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // 与「花园主题」选择器同理：用 Wrap 让卡片高度随内容自适应，
    // 避免固定宽高比 + Spacer 在窄屏 / 大字体下溢出。
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: species.map((item) {
            return SizedBox(
              width: itemWidth,
              child: SpeciesTile(
                species: item,
                bloomedCount:
                    controller.garden.bloomingCountOfSpecies(item.id, now),
                petalCount: controller.garden.petalsOfSpecies(item.id),
                now: now,
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

/// 单个花种卡片。
///
/// 未收集时灰显为剪影（PRD Tab3：未收集花种展示（灰显 / 剪影））。
class SpeciesTile extends StatelessWidget {
  const SpeciesTile({
    super.key,
    required this.species,
    required this.bloomedCount,
    required this.petalCount,
    required this.now,
  });

  final FlowerSpecies species;
  final int bloomedCount;
  final int petalCount;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final collected = bloomedCount > 0;

    // 季节限定花在非当季时不可种植（PRD 7.1.3）
    final inSeason = species.isPlantableInMonth(now.month);
    final seasonLocked = species.isSeasonal && !inSeason;
    final locked = !collected && (species.rarity == SpeciesRarity.hidden);

    return SoftCard(
      color: collected ? Colors.white : AppColors.creamSoft,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              // 未收集时用剪影效果
              Opacity(
                opacity: collected ? 1.0 : 0.35,
                child: Text(
                  species.emoji,
                  style: const TextStyle(fontSize: 30),
                ),
              ),
              const Spacer(),
              RarityBadge(rarity: species.rarity),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            species.name,
            style: textTheme.titleMedium?.copyWith(
              color: collected ? AppColors.inkPrimary : AppColors.inkTertiary,
            ),
          ),
          const SizedBox(height: 6),
          if (locked)
            Text('尚未解锁', style: textTheme.labelSmall)
          else if (seasonLocked)
            Text(
              '${species.seasonMonths.join('-')} 月可种',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.mistyRoseDeep,
              ),
            )
          else if (collected)
            Text(
              '已开 $bloomedCount 朵',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.warmApricotDeep,
              ),
            )
          else
            Text(
              '已攒 $petalCount / ${AppConstants.petalsPerBloom} 片花瓣',
              style: textTheme.labelSmall,
            ),
          const SizedBox(height: 12),
          // 收集进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: <Widget>[
                Container(height: 5, color: AppColors.creamDeep),
                FractionallySizedBox(
                  widthFactor: collected
                      ? 1.0
                      : (petalCount % AppConstants.petalsPerBloom) /
                          AppConstants.petalsPerBloom,
                  child: Container(
                    height: 5,
                    color: collected
                        ? AppColors.warmApricot
                        : AppColors.sageGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RarityBadge extends StatelessWidget {
  const RarityBadge({super.key, required this.rarity});

  final SpeciesRarity rarity;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (rarity) {
      SpeciesRarity.common => (AppColors.sageGreenSoft, AppColors.sageGreenDeep),
      SpeciesRarity.rare => (AppColors.warmApricotSoft, AppColors.warmApricotDeep),
      SpeciesRarity.hidden => (AppColors.creamDeep, AppColors.inkSecondary),
      SpeciesRarity.seasonal => (AppColors.mistyRoseSoft, AppColors.mistyRoseDeep),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        rarity.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontSize: 10,
            ),
      ),
    );
  }
}
